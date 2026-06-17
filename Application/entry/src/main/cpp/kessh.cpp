#include "kessh.h"
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/ip_icmp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>
#include <string>
#include <map>
#include <mutex>
#include <cstring>
#include <cstdarg>
#include <cstdio>
#include <cctype>
#include <vector>
#include <cerrno>
#include <hilog/log.h>
#include <chrono>
#include <sstream>
#include <iomanip>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0xD15C
#define LOG_TAG "KesshNative"

static std::map<int, KesshSession*> sessions;
static int next_session_id = 1;
static std::mutex session_mutex;
static bool libssh2_initialized = false;
static std::mutex init_mutex;
static int keepalive_interval_seconds = 30;
static int keepalive_max_attempts = 3;
static std::mutex keepalive_config_mutex;

// Helper function for logging
void log_info(const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "%{public}s", buffer);
}

void log_error(const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "%{public}s", buffer);
}

// Helper to get string argument
static std::string get_string_arg(napi_env env, napi_value value) {
    size_t len = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &len);
    std::vector<char> buffer(len + 1, '\0');
    napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &len);
    return std::string(buffer.data(), len);
}

static bool is_valid_host(const std::string &host)
{
    if (host.empty()) {
        return false;
    }
    for (char c : host) {
        unsigned char ch = static_cast<unsigned char>(c);
        if (!(std::isalnum(ch) || c == '.' || c == '-' || c == ':' )) {
            return false;
        }
    }
    return true;
}

static bool shell_quote_arg(const std::string &value, std::string &quoted, std::string &error)
{
    quoted.clear();
    for (char c : value) {
        if (c == '\0' || c == '\r' || c == '\n') {
            error = "Remote path contains invalid control characters";
            return false;
        }
    }

    quoted = "'";
    for (char c : value) {
        if (c == '\'') {
            quoted += "'\\''";
        } else {
            quoted += c;
        }
    }
    quoted += "'";
    return true;
}

static bool ensure_libssh2_initialized(std::string &error)
{
    std::lock_guard<std::mutex> lock(init_mutex);
    if (libssh2_initialized) {
        return true;
    }

    log_info("[LIBSSH2 INIT] Calling libssh2_init(0)");
    int rc = libssh2_init(0);
    if (rc != 0) {
        error = "Failed to initialize libssh2";
        log_error("[LIBSSH2 INIT ERROR] libssh2_init failed: rc=%d", rc);
        return false;
    }
    libssh2_initialized = true;
    log_info("[LIBSSH2 INIT SUCCESS] libssh2 initialized");
    return true;
}

static std::string last_session_error(LIBSSH2_SESSION *session, const char *fallback)
{
    if (!session) {
        return fallback;
    }
    char *errmsg = nullptr;
    int errlen = 0;
    libssh2_session_last_error(session, &errmsg, &errlen, 0);
    if (errmsg && errlen > 0) {
        return std::string(errmsg, errlen);
    }
    return fallback;
}

static bool set_socket_timeouts(int sock, int timeout_seconds)
{
    struct timeval timeout;
    timeout.tv_sec = timeout_seconds;
    timeout.tv_usec = 0;

    bool ok = true;
    if (setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) < 0) {
        log_error("Failed to set socket send timeout: %s", strerror(errno));
        ok = false;
    }
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0) {
        log_error("Failed to set socket receive timeout: %s", strerror(errno));
        ok = false;
    }
    return ok;
}

static int connect_tcp_socket(const std::string &host, int32_t port, std::string &error)
{
    if (!is_valid_host(host)) {
        error = "Invalid host";
        return -1;
    }
    if (port < 1 || port > 65535) {
        error = "Invalid port";
        return -1;
    }

    struct addrinfo hints = {};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_ADDRCONFIG;

    struct addrinfo *addr_result = nullptr;
    std::string port_string = std::to_string(port);
    int addr_status = getaddrinfo(host.c_str(), port_string.c_str(), &hints, &addr_result);
    if (addr_status != 0) {
        error = std::string("Address resolution failed: ") + gai_strerror(addr_status);
        log_error("[OPEN ERROR] DNS resolution failed for %s:%d: %s", host.c_str(), port, gai_strerror(addr_status));
        return -1;
    }

    int last_error = 0;
    for (struct addrinfo *ai = addr_result; ai != nullptr; ai = ai->ai_next) {
        int sock = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (sock < 0) {
            last_error = errno;
            log_error("[OPEN ERROR] Failed to create socket: %s", strerror(errno));
            continue;
        }

        set_socket_timeouts(sock, 10);

        int connect_result = -1;
        int retry_count = 0;
        const int max_retries = 3;
        do {
            connect_result = connect(sock, ai->ai_addr, ai->ai_addrlen);
            if (connect_result == 0 || errno == EISCONN) {
                freeaddrinfo(addr_result);
                return sock;
            }
            if (errno == EINTR) {
                retry_count++;
                continue;
            }
            break;
        } while (retry_count < max_retries);

        last_error = errno;
        log_error("[OPEN ERROR] connect failed for %s:%d: %s", host.c_str(), port, strerror(errno));
        close(sock);
    }

    if (addr_result != nullptr) {
        freeaddrinfo(addr_result);
    }
    if (last_error == 0) {
        error = "Failed to connect";
    } else if (last_error == EINPROGRESS || last_error == ETIMEDOUT) {
        error = "Connection timeout: unable to reach server";
    } else {
        error = std::string("Failed to connect: ") + strerror(last_error);
    }
    return -1;
}

static void cleanup_open_failure(LIBSSH2_SESSION *session, LIBSSH2_CHANNEL *channel, int sock, const char *reason)
{
    if (channel) {
        libssh2_channel_free(channel);
    }
    if (session) {
        if (reason) {
            libssh2_session_disconnect(session, reason);
        }
        libssh2_session_free(session);
    }
    if (sock >= 0) {
        close(sock);
    }
}

static int open_session_internal(const std::string &host, int32_t port, const std::string &user, const std::string &pass, std::string &error)
{
    log_info("Opening SSH session host:%s port:%d user:%s", host.c_str(), port, user.c_str());

    if (host.empty()) {
        error = "Host cannot be empty";
        return -1;
    }
    if (user.empty()) {
        error = "Username cannot be empty";
        return -1;
    }

    int sock = connect_tcp_socket(host, port, error);
    if (sock < 0) {
        return -1;
    }

    if (!ensure_libssh2_initialized(error)) {
        close(sock);
        return -1;
    }

    LIBSSH2_SESSION *session = libssh2_session_init();
    if (!session) {
        error = "Failed to create libssh2 session";
        close(sock);
        return -1;
    }

    libssh2_session_set_timeout(session, 5000);

    if (libssh2_session_handshake(session, sock)) {
        error = last_session_error(session, "SSH handshake failed");
        log_error("SSH handshake failed: %s", error.c_str());
        cleanup_open_failure(session, nullptr, sock, nullptr);
        return -1;
    }

    int configured_keepalive = 0;
    {
        std::lock_guard<std::mutex> keepalive_lock(keepalive_config_mutex);
        configured_keepalive = keepalive_interval_seconds;
    }
    libssh2_keepalive_config(session, 1, configured_keepalive > 0 ? configured_keepalive : 0);

    if (libssh2_userauth_password(session, user.c_str(), pass.c_str())) {
        error = last_session_error(session, "Authentication failed");
        log_error("SSH authentication failed: %s", error.c_str());
        cleanup_open_failure(session, nullptr, sock, "Authentication failed");
        return -1;
    }

    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(session);
    if (!channel) {
        error = last_session_error(session, "Failed to open channel");
        log_error("Failed to open SSH channel: %s", error.c_str());
        cleanup_open_failure(session, nullptr, sock, "Failed to open channel");
        return -1;
    }

    if (libssh2_channel_request_pty(channel, "vt100")) {
        error = last_session_error(session, "Failed to request PTY");
        log_error("Failed to request PTY: %s", error.c_str());
        cleanup_open_failure(session, channel, sock, "Failed to request PTY");
        return -1;
    }

    if (libssh2_channel_shell(channel)) {
        error = last_session_error(session, "Failed to start shell");
        log_error("Failed to start shell: %s", error.c_str());
        cleanup_open_failure(session, channel, sock, "Failed to start shell");
        return -1;
    }

    KesshSession* kessh_session = new KesshSession{session, channel, sock, 0};

    std::lock_guard<std::mutex> lock(session_mutex);
    int session_id = next_session_id++;
    sessions[session_id] = kessh_session;

    log_info("SSH session created with ID: %d", session_id);
    return session_id;
}

struct OpenSessionAsyncData {
    napi_async_work work;
    napi_deferred deferred;
    std::string host;
    int32_t port;
    std::string user;
    std::string pass;
    std::string error;
    int32_t session_id;
};

static bool parse_open_session_args(napi_env env, napi_callback_info info, std::string &host, int32_t &port, std::string &user, std::string &pass)
{
    size_t argc = 4;
    napi_value args[4];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (status != napi_ok || argc != 4) {
        napi_throw_error(env, nullptr, "Invalid arguments");
        return false;
    }
    if (args[0] == nullptr || args[1] == nullptr || args[2] == nullptr || args[3] == nullptr) {
        napi_throw_error(env, nullptr, "Null argument detected");
        return false;
    }

    host = get_string_arg(env, args[0]);
    napi_get_value_int32(env, args[1], &port);
    user = get_string_arg(env, args[2]);
    pass = get_string_arg(env, args[3]);
    return true;
}

napi_value OpenSession(napi_env env, napi_callback_info info) {
    std::string host;
    std::string user;
    std::string pass;
    int32_t port = 0;
    if (!parse_open_session_args(env, info, host, port, user, pass)) {
        return nullptr;
    }

    std::string error;
    int32_t session_id = open_session_internal(host, port, user, pass, error);
    if (session_id <= 0) {
        napi_throw_error(env, nullptr, error.empty() ? "Failed to open SSH session" : error.c_str());
        return nullptr;
    }

    napi_value return_value;
    napi_create_int32(env, session_id, &return_value);
    return return_value;
}

static void ExecuteOpenSessionAsync(napi_env env, void *data)
{
    OpenSessionAsyncData *async_data = static_cast<OpenSessionAsyncData*>(data);
    async_data->session_id = open_session_internal(
        async_data->host,
        async_data->port,
        async_data->user,
        async_data->pass,
        async_data->error
    );
}

static void CompleteOpenSessionAsync(napi_env env, napi_status status, void *data)
{
    OpenSessionAsyncData *async_data = static_cast<OpenSessionAsyncData*>(data);
    napi_value result;
    if (status != napi_ok) {
        napi_create_int32(env, -1, &result);
    } else {
        napi_create_int32(env, async_data->session_id, &result);
    }
    if (async_data->session_id <= 0 && !async_data->error.empty()) {
        log_error("OpenSessionAsync failed: %s", async_data->error.c_str());
    }
    napi_resolve_deferred(env, async_data->deferred, result);
    napi_delete_async_work(env, async_data->work);
    delete async_data;
}

napi_value OpenSessionAsync(napi_env env, napi_callback_info info)
{
    std::string host;
    std::string user;
    std::string pass;
    int32_t port = 0;
    if (!parse_open_session_args(env, info, host, port, user, pass)) {
        return nullptr;
    }

    napi_value promise;
    napi_deferred deferred;
    napi_create_promise(env, &deferred, &promise);

    OpenSessionAsyncData *async_data = new OpenSessionAsyncData{
        nullptr,
        deferred,
        host,
        port,
        user,
        pass,
        "",
        -1
    };

    napi_value resource_name;
    napi_create_string_utf8(env, "OpenSessionAsync", NAPI_AUTO_LENGTH, &resource_name);
    napi_status work_status = napi_create_async_work(
        env,
        nullptr,
        resource_name,
        ExecuteOpenSessionAsync,
        CompleteOpenSessionAsync,
        async_data,
        &async_data->work
    );
    if (work_status != napi_ok) {
        napi_value result;
        napi_create_int32(env, -1, &result);
        napi_resolve_deferred(env, deferred, result);
        delete async_data;
        return promise;
    }

    work_status = napi_queue_async_work(env, async_data->work);
    if (work_status != napi_ok) {
        napi_delete_async_work(env, async_data->work);
        napi_value result;
        napi_create_int32(env, -1, &result);
        napi_resolve_deferred(env, deferred, result);
        delete async_data;
    }
    return promise;
}

napi_value CloseSession(napi_env env, napi_callback_info info) {
    log_info("CloseSession called");
    
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);

    log_info("Closing session ID: %d", session_id);

    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    if (it != sessions.end()) {
        KesshSession* kessh_session = it->second;
        
        if (kessh_session->channel) {
            libssh2_channel_free(kessh_session->channel);
        }
        if (kessh_session->session) {
            libssh2_session_disconnect(kessh_session->session, "Normal Shutdown");
            libssh2_session_free(kessh_session->session);
        }
        if (kessh_session->sock >= 0) {
            close(kessh_session->sock);
        }
        
        delete kessh_session;
        sessions.erase(it);
        log_info("Session %d closed successfully", session_id);
    } else {
        log_error("Session %d not found", session_id);
    }

    // Do not call libssh2_exit() here as it's global cleanup
    // Only call it when the entire application is shutting down
    return nullptr;
}

napi_value SetKeepaliveConfig(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t interval = keepalive_interval_seconds;
    int32_t attempts = keepalive_max_attempts;

    if (argc >= 1) {
        napi_get_value_int32(env, args[0], &interval);
    }
    if (argc >= 2) {
        napi_get_value_int32(env, args[1], &attempts);
    }

    if (interval < 0) interval = 0;
    if (attempts < 0) attempts = 0;

    {
        std::lock_guard<std::mutex> lock(keepalive_config_mutex);
        keepalive_interval_seconds = interval;
        keepalive_max_attempts = attempts;
    }

    log_info("Keepalive config updated: interval=%d attempts=%d", interval, attempts);
    return nullptr;
}

napi_value SendKeepalive(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t session_id = 0;
    napi_get_value_int32(env, args[0], &session_id);

    bool success = false;
    {
        std::lock_guard<std::mutex> lock(session_mutex);
        auto it = sessions.find(session_id);
        if (it != sessions.end()) {
            KesshSession* kessh_session = it->second;
            if (kessh_session && kessh_session->session) {
                int seconds_to_next = 0;
                int rc = libssh2_keepalive_send(kessh_session->session, &seconds_to_next);
                if (rc == 0) {
                    kessh_session->keepaliveFailures = 0;
                    success = true;
                    log_info("Keepalive success: session=%d next=%d", session_id, seconds_to_next);
                } else {
                    kessh_session->keepaliveFailures += 1;
                    log_error("Keepalive failed: session=%d rc=%d failures=%d", session_id, rc, kessh_session->keepaliveFailures);
                    if (keepalive_max_attempts > 0 && kessh_session->keepaliveFailures >= keepalive_max_attempts) {
                        log_error("Keepalive threshold reached for session %d", session_id);
                    }
                }
            }
        } else {
            log_error("Session %d not found for keepalive", session_id);
        }
    }

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

napi_value Write(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);
    std::string data = get_string_arg(env, args[1]);

    log_info("Writing %zu bytes to session %d", data.length(), session_id);

    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    if (it != sessions.end()) {
        KesshSession* kessh_session = it->second;
        if (kessh_session->channel) {
            ssize_t written = libssh2_channel_write(kessh_session->channel, data.c_str(), data.length());
            if (written >= 0) {
                log_info("Successfully wrote %zd bytes to session %d", written, session_id);
            } else {
                log_error("Failed to write to session %d", session_id);
            }
        }
    } else {
        log_error("Session %d not found for write", session_id);
    }

    return nullptr;
}

napi_value Read(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);

    std::string result_str;
    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    if (it != sessions.end()) {
        KesshSession* kessh_session = it->second;
        if (kessh_session->channel) {
            // 设置为非阻塞模式
            libssh2_channel_set_blocking(kessh_session->channel, 0);
            
            char buffer[4096];
            ssize_t n;
            int total_read = 0;
            
            // 非阻塞读取,读取所有可用数据
            while (true) {
                n = libssh2_channel_read(kessh_session->channel, buffer, sizeof(buffer));
                
                if (n > 0) {
                    // 成功读取数据
                    result_str.append(buffer, n);
                    total_read += n;
                } else if (n == 0) {
                    // EOF - channel关闭
                    break;
                } else if (n == LIBSSH2_ERROR_EAGAIN) {
                    // 没有更多数据可读
                    break;
                } else {
                    // 其他错误
                    log_error("Read error from session %d: %zd", session_id, n);
                    break;
                }
            }
            
            if (total_read > 0) {
                log_info("Read %d bytes from session %d", total_read, session_id);
            }
        }
    } else {
        log_error("Session %d not found for read", session_id);
    }

    napi_value result;
    napi_create_string_utf8(env, result_str.c_str(), result_str.length(), &result);
    return result;
}

// 添加一个简单的测试函数，不依赖任何第三方库
napi_value TestNative(napi_env env, napi_callback_info info) {
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[TEST] TestNative function called successfully!");
    log_info("[TEST] TestNative function called successfully!");
    
    napi_value result;
    napi_create_int32(env, 12345, &result);
    return result;
}

// 执行SSH命令并返回结果
napi_value ExecuteCommand(napi_env env, napi_callback_info info) {
    log_info("ExecuteCommand called");
    
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc != 2) {
        napi_throw_error(env, nullptr, "Invalid arguments count");
        return nullptr;
    }

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);
    std::string command = get_string_arg(env, args[1]);

    log_info("Executing command on session %d: %s", session_id, command.c_str());

    std::string result_str;
    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    
    if (it == sessions.end()) {
        log_error("Session %d not found", session_id);
        napi_throw_error(env, nullptr, "Session not found");
        return nullptr;
    }

    KesshSession* kessh_session = it->second;
    if (!kessh_session->session) {
        log_error("Invalid session object");
        napi_throw_error(env, nullptr, "Invalid session");
        return nullptr;
    }

    // 打开exec channel
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(kessh_session->session);
    if (!channel) {
        char *errmsg;
        int errlen;
        libssh2_session_last_error(kessh_session->session, &errmsg, &errlen, 0);
        log_error("Failed to open exec channel: %.*s", errlen, errmsg);
        napi_throw_error(env, nullptr, "Failed to open channel");
        return nullptr;
    }

    log_info("Exec channel opened, executing command...");

    // 执行命令
    if (libssh2_channel_exec(channel, command.c_str())) {
        char *errmsg;
        int errlen;
        libssh2_session_last_error(kessh_session->session, &errmsg, &errlen, 0);
        log_error("Failed to execute command: %.*s", errlen, errmsg);
        libssh2_channel_free(channel);
        napi_throw_error(env, nullptr, "Failed to execute command");
        return nullptr;
    }

    // 读取命令输出
    char buffer[4096];
    ssize_t n;
    int total_read = 0;

    while (true) {
        n = libssh2_channel_read(channel, buffer, sizeof(buffer));
        
        if (n > 0) {
            result_str.append(buffer, n);
            total_read += n;
        } else if (n == 0) {
            // EOF
            break;
        } else if (n == LIBSSH2_ERROR_EAGAIN) {
            // 需要等待
            usleep(10000); // 10ms
            continue;
        } else {
            log_error("Read error: %zd", n);
            break;
        }
    }

    // 读取stderr
    while (true) {
        n = libssh2_channel_read_stderr(channel, buffer, sizeof(buffer));
        
        if (n > 0) {
            result_str.append(buffer, n);
            total_read += n;
        } else if (n == 0 || n == LIBSSH2_ERROR_EAGAIN) {
            break;
        } else {
            break;
        }
    }

    log_info("Command executed, read %d bytes", total_read);

    // 关闭并释放channel
    libssh2_channel_close(channel);
    libssh2_channel_free(channel);

    napi_value result;
    napi_create_string_utf8(env, result_str.c_str(), result_str.length(), &result);
    return result;
}

// 下载文件（读取远程文件内容）
napi_value DownloadFile(napi_env env, napi_callback_info info) {
    log_info("DownloadFile called");
    
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc != 2) {
        napi_throw_error(env, nullptr, "Invalid arguments count");
        return nullptr;
    }

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);
    std::string remote_path = get_string_arg(env, args[1]);

    log_info("Downloading file from session %d: %s", session_id, remote_path.c_str());

    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    
    if (it == sessions.end()) {
        log_error("Session %d not found", session_id);
        napi_throw_error(env, nullptr, "Session not found");
        return nullptr;
    }

    KesshSession* kessh_session = it->second;

    std::string quoted_path;
    std::string quote_error;
    if (!shell_quote_arg(remote_path, quoted_path, quote_error)) {
        napi_throw_error(env, nullptr, quote_error.c_str());
        return nullptr;
    }

    // 使用cat命令读取文件
    std::string command = "cat -- " + quoted_path + " 2>&1";
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(kessh_session->session);
    
    if (!channel) {
        napi_throw_error(env, nullptr, "Failed to open channel");
        return nullptr;
    }

    if (libssh2_channel_exec(channel, command.c_str())) {
        libssh2_channel_free(channel);
        napi_throw_error(env, nullptr, "Failed to execute cat command");
        return nullptr;
    }

    // 读取文件内容
    std::string file_content;
    char buffer[8192];
    ssize_t n;

    while (true) {
        n = libssh2_channel_read(channel, buffer, sizeof(buffer));
        
        if (n > 0) {
            file_content.append(buffer, n);
        } else if (n == 0) {
            break;
        } else if (n == LIBSSH2_ERROR_EAGAIN) {
            usleep(10000);
            continue;
        } else {
            break;
        }
    }

    libssh2_channel_close(channel);
    libssh2_channel_free(channel);

    log_info("Downloaded %zu bytes from %s", file_content.length(), remote_path.c_str());

    napi_value result;
    napi_create_string_utf8(env, file_content.c_str(), file_content.length(), &result);
    return result;
}

// 上传文件（写入远程文件）
napi_value UploadFile(napi_env env, napi_callback_info info) {
    log_info("UploadFile called");
    
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc != 3) {
        napi_throw_error(env, nullptr, "Invalid arguments count");
        return nullptr;
    }

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);
    std::string remote_path = get_string_arg(env, args[1]);
    std::string content = get_string_arg(env, args[2]);

    log_info("Uploading %zu bytes to session %d: %s", content.length(), session_id, remote_path.c_str());

    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    
    if (it == sessions.end()) {
        log_error("Session %d not found", session_id);
        napi_throw_error(env, nullptr, "Session not found");
        return nullptr;
    }

    KesshSession* kessh_session = it->second;

    std::string quoted_path;
    std::string quote_error;
    if (!shell_quote_arg(remote_path, quoted_path, quote_error)) {
        napi_throw_error(env, nullptr, quote_error.c_str());
        return nullptr;
    }

    // 使用cat命令写入文件
    std::string command = "cat > " + quoted_path;

    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(kessh_session->session);
    
    if (!channel) {
        napi_throw_error(env, nullptr, "Failed to open channel");
        return nullptr;
    }

    if (libssh2_channel_exec(channel, command.c_str())) {
        libssh2_channel_free(channel);
        napi_throw_error(env, nullptr, "Failed to execute cat command");
        return nullptr;
    }

    // 写入文件内容
    size_t total_written = 0;
    while (total_written < content.length()) {
        ssize_t written = libssh2_channel_write(channel, 
            content.c_str() + total_written, 
            content.length() - total_written);
        
        if (written > 0) {
            total_written += written;
        } else if (written == LIBSSH2_ERROR_EAGAIN) {
            usleep(10000);
            continue;
        } else {
            log_error("Write error: %zd", written);
            libssh2_channel_free(channel);
            napi_throw_error(env, nullptr, "Failed to write file content");
            return nullptr;
        }
    }

    // 发送EOF并关闭
    libssh2_channel_send_eof(channel);
    libssh2_channel_close(channel);
    libssh2_channel_free(channel);

    log_info("Uploaded %zu bytes to %s", total_written, remote_path.c_str());

    napi_value result;
    napi_create_int32(env, total_written, &result);
    return result;
}

// ICMP Ping 实现 - 使用 TCP 连接模拟 ping
napi_value PingHost(napi_env env, napi_callback_info info)
{
    log_info("[PING STEP 1] PingHost function called");
    size_t argc = 2;
    napi_value args[2];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok || argc < 1) {
        log_error("[PING ERROR] Invalid arguments");
        napi_throw_error(env, nullptr, "PingHost: invalid arguments");
        return nullptr;
    }

    std::string host = get_string_arg(env, args[0]);
    if (!is_valid_host(host)) {
        log_error("[PING ERROR] Invalid host: %s", host.c_str());
        napi_throw_error(env, nullptr, "PingHost: invalid host");
        return nullptr;
    }

    int32_t count = 4;
    if (argc >= 2) {
        napi_get_value_int32(env, args[1], &count);
    }
    if (count <= 0) count = 4;
    if (count > 10) count = 10;

    log_info("[PING STEP 2] Pinging %s, count: %d", host.c_str(), count);

    std::ostringstream result_stream;
    result_stream << "PING " << host << "\n";

    // 解析地址
    struct addrinfo hints = {};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_ADDRCONFIG;

    struct addrinfo *addr_result = nullptr;
    int addr_status = getaddrinfo(host.c_str(), "80", &hints, &addr_result);
    if (addr_status != 0) {
        log_error("[PING ERROR] DNS resolution failed: %s", gai_strerror(addr_status));
        result_stream << "DNS 解析失败: " << gai_strerror(addr_status) << "\n";
        std::string output = result_stream.str();
        napi_value return_value;
        napi_create_string_utf8(env, output.c_str(), output.length(), &return_value);
        return return_value;
    }

    int success = 0;
    int failed = 0;
    double total_time = 0.0;
    double min_time = 999999.0;
    double max_time = 0.0;

    for (int i = 0; i < count; i++) {
        log_info("[PING STEP 3.%d] Attempt %d/%d", i, i+1, count);
        
        int sock = socket(addr_result->ai_family, SOCK_STREAM, 0);
        if (sock < 0) {
            log_error("[PING ERROR %d] Failed to create socket", i);
            result_stream << "错误: 无法创建 socket\n";
            failed++;
            continue;
        }

        // 设置超时
        struct timeval timeout;
        timeout.tv_sec = 2;
        timeout.tv_usec = 0;
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

        auto start = std::chrono::steady_clock::now();
        int conn_result = connect(sock, addr_result->ai_addr, addr_result->ai_addrlen);
        auto end = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration<double, std::milli>(end - start).count();

        if (conn_result == 0 || errno == EISCONN) {
            success++;
            total_time += duration;
            if (duration < min_time) min_time = duration;
            if (duration > max_time) max_time = duration;
            
            result_stream << std::fixed << std::setprecision(2)
                         << "Reply from " << host << ": time=" << duration << "ms\n";
            log_info("[PING SUCCESS %d] time=%.2fms", i, duration);
        } else {
            failed++;
            result_stream << "Request timeout\n";
            log_error("[PING FAILED %d] %s", i, strerror(errno));
        }

        close(sock);
        
        if (i < count - 1) {
            usleep(200000); // 200ms 间隔
        }
    }

    freeaddrinfo(addr_result);

    // 统计信息
    result_stream << "\n--- " << host << " ping 统计 ---\n";
    result_stream << count << " 个数据包已发送, " 
                  << success << " 个已接收, "
                  << failed << " 个丢失 ("
                  << std::fixed << std::setprecision(1)
                  << (failed * 100.0 / count) << "% 丢包率)\n";
    
    if (success > 0) {
        double avg_time = total_time / success;
        result_stream << "往返时间(ms): 最小 = " << std::setprecision(2) << min_time
                      << ", 最大 = " << max_time
                      << ", 平均 = " << avg_time << "\n";
    }

    std::string output = result_stream.str();
    log_info("[PING COMPLETE] Success: %d, Failed: %d", success, failed);
    
    napi_value return_value;
    napi_create_string_utf8(env, output.c_str(), output.length(), &return_value);
    return return_value;
}

// 端口测试实现 - 使用阻塞 socket + 超时
napi_value TestPort(napi_env env, napi_callback_info info)
{
    log_info("[PORT STEP 1] TestPort function called");
    size_t argc = 3;
    napi_value args[3];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok || argc < 2) {
        log_error("[PORT ERROR] Invalid arguments");
        napi_throw_error(env, nullptr, "TestPort: invalid arguments");
        return nullptr;
    }

    std::string host = get_string_arg(env, args[0]);
    if (!is_valid_host(host)) {
        log_error("[PORT ERROR] Invalid host: %s", host.c_str());
        napi_throw_error(env, nullptr, "TestPort: invalid host");
        return nullptr;
    }

    int32_t port;
    napi_get_value_int32(env, args[1], &port);
    if (port <= 0 || port > 65535) {
        log_error("[PORT ERROR] Invalid port: %d", port);
        napi_throw_error(env, nullptr, "TestPort: invalid port");
        return nullptr;
    }

    int32_t timeout_ms = 3000;
    if (argc >= 3) {
        napi_get_value_int32(env, args[2], &timeout_ms);
    }
    if (timeout_ms < 1000) timeout_ms = 1000;
    if (timeout_ms > 15000) timeout_ms = 15000;

    log_info("[PORT STEP 2] Testing %s:%d, timeout: %dms", host.c_str(), port, timeout_ms);

    struct addrinfo hints = {};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_ADDRCONFIG;

    struct addrinfo *addr_result = nullptr;
    std::string port_string = std::to_string(port);
    int addr_status = getaddrinfo(host.c_str(), port_string.c_str(), &hints, &addr_result);
    if (addr_status != 0) {
        log_error("[PORT ERROR] DNS resolution failed: %s", gai_strerror(addr_status));
        std::string message = std::string("解析地址失败: ") + gai_strerror(addr_status);
        napi_value fallback_value;
        napi_create_string_utf8(env, message.c_str(), message.length(), &fallback_value);
        return fallback_value;
    }

    bool connected = false;
    int error_code = 0;
    auto start = std::chrono::steady_clock::now();

    for (struct addrinfo *ai = addr_result; ai != nullptr && !connected; ai = ai->ai_next) {
        log_info("[PORT STEP 3] Trying address family %d", ai->ai_family);
        
        int sock = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (sock < 0) {
            error_code = errno;
            log_error("[PORT ERROR] Failed to create socket: %s", strerror(errno));
            continue;
        }

        // 设置阻塞模式 + 超时
        struct timeval timeout;
        timeout.tv_sec = timeout_ms / 1000;
        timeout.tv_usec = (timeout_ms % 1000) * 1000;
        
        if (setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) < 0) {
            log_error("[PORT ERROR] Failed to set send timeout");
        }
        if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0) {
            log_error("[PORT ERROR] Failed to set recv timeout");
        }

        log_info("[PORT STEP 4] Connecting...");
        int conn_result = connect(sock, ai->ai_addr, ai->ai_addrlen);
        
        if (conn_result == 0 || errno == EISCONN) {
            connected = true;
            log_info("[PORT SUCCESS] Connected successfully");
        } else {
            error_code = errno;
            log_error("[PORT FAILED] Connection failed: %s", strerror(errno));
        }

        close(sock);
    }

    if (addr_result != nullptr) {
        freeaddrinfo(addr_result);
    }

    auto end = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

    std::string message;
    if (connected) {
        message = "端口开放，响应时间 " + std::to_string(duration) + " ms";
        log_info("[PORT COMPLETE] Port is open, time: %ldms", duration);
    } else {
        if (error_code == 0) {
            error_code = ECONNREFUSED;
        }
        message = std::string("端口不可用: ") + strerror(error_code);
        log_error("[PORT COMPLETE] Port unavailable: %s", strerror(error_code));
    }

    napi_value return_value;
    napi_create_string_utf8(env, message.c_str(), message.length(), &return_value);
    return return_value;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[MODULE INIT START] Initializing kessh native module");
    log_info("[MODULE INIT START] Initializing kessh native module");
    
    // DO NOT initialize libssh2 here - it may crash
    // Initialize it lazily on first use instead
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[MODULE INIT] Skipping libssh2 initialization, will init on first use");
    
    napi_property_descriptor desc[] = {
        { "openSession", nullptr, OpenSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "openSessionAsync", nullptr, OpenSessionAsync, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "closeSession", nullptr, CloseSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setKeepaliveConfig", nullptr, SetKeepaliveConfig, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "sendKeepalive", nullptr, SendKeepalive, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "write", nullptr, Write, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "read", nullptr, Read, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "executeCommand", nullptr, ExecuteCommand, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "downloadFile", nullptr, DownloadFile, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "uploadFile", nullptr, UploadFile, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "testNative", nullptr, TestNative, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "pingHost", nullptr, PingHost, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "testPort", nullptr, TestPort, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[MODULE INIT] Defining properties...");
    napi_status status = napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    
    if (status != napi_ok) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "[MODULE INIT ERROR] Failed to define properties: %d", status);
        return nullptr;
    }
    
    log_info("[MODULE INIT SUCCESS] Kessh native module initialized successfully");
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[MODULE INIT SUCCESS] Kessh native module initialized successfully");
    return exports;
}
EXTERN_C_END

static napi_module kessh_module = {
    .nm_version =1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "kessh",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterModule(void)
{
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "Registering kessh module");
    napi_module_register(&kessh_module);
}
