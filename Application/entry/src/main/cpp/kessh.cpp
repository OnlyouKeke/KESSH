#include "kessh.h"
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
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
#include <hilog/log.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0xD15C
#define LOG_TAG "KesshNative"

static std::map<int, KesshSession*> sessions;
static int next_session_id = 1;
static std::mutex session_mutex;
static bool libssh2_initialized = false;
static std::mutex init_mutex;

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
    size_t len;
    napi_get_value_string_utf8(env, value, nullptr, 0, &len);
    std::string str(len, 0);
    napi_get_value_string_utf8(env, value, &str[0], len + 1, &len);
    return str;
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

struct CommandCandidate {
    std::string binary;      // Binary path used for availability checks
    std::string invocation;  // Actual command string that should be executed
};

static bool is_command_available(const CommandCandidate &candidate)
{
    if (candidate.binary.empty()) {
        // Cannot verify availability, assume it can be resolved from PATH
        return true;
    }
    return access(candidate.binary.c_str(), X_OK) == 0;
}

static std::string select_command(const std::vector<CommandCandidate> &candidates, const std::string &args)
{
    for (const auto &candidate : candidates) {
        if (is_command_available(candidate)) {
            return candidate.invocation + " " + args;
        }
    }
    return "";
}

static std::string run_shell_command(const std::string &command)
{
    std::string output;
    FILE *pipe = popen(command.c_str(), "r");
    if (!pipe) {
        output = "无法执行命令: " + command + "\n";
        output += "请确认设备支持相关工具";
        return output;
    }
    char buffer[512];
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        output += buffer;
    }
    int status = pclose(pipe);
    output += "\n(退出状态: " + std::to_string(status) + ")";
    return output;
}

napi_value OpenSession(napi_env env, napi_callback_info info) {
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[C++ ENTRY] OpenSession function entered");
    log_info("[C++ STEP 1] OpenSession called");
    
    size_t argc = 4;
    napi_value args[4];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    if (status != napi_ok || argc != 4) {
        log_error("[C++ STEP 2 ERROR] Invalid arguments count: %zu, status: %d", argc, status);
        napi_throw_error(env, nullptr, "Invalid arguments");
        return nullptr;
    }
    
    log_info("[C++ STEP 3] Parsing arguments...");

    // Add null checks for safety
    if (args[0] == nullptr || args[1] == nullptr || args[2] == nullptr || args[3] == nullptr) {
        log_error("[C++ STEP 3.5 ERROR] One or more arguments are null");
        napi_throw_error(env, nullptr, "Null argument detected");
        return nullptr;
    }

    std::string host = get_string_arg(env, args[0]);
    if (host.empty()) {
        log_error("[C++ STEP 3.6 ERROR] Host is empty");
        napi_throw_error(env, nullptr, "Host cannot be empty");
        return nullptr;
    }
    int32_t port;
    napi_get_value_int32(env, args[1], &port);
    std::string user = get_string_arg(env, args[2]);
    std::string pass = get_string_arg(env, args[3]);

    log_info("[C++ STEP 4] Arguments parsed - host:%s port:%d user:%s", host.c_str(), port, user.c_str());
    log_info("[C++ STEP 5] Creating socket...");

    // Create socket
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        log_error("[C++ STEP 6 ERROR] Failed to create socket: %s", strerror(errno));
        napi_throw_error(env, nullptr, "Failed to create socket");
        return nullptr;
    }

    log_info("[C++ STEP 7] Socket created: fd=%d", sock);
    log_info("[C++ STEP 8] Ensuring BLOCKING mode for socket");

    // 显式确保socket是阻塞模式
    int flags = fcntl(sock, F_GETFL, 0);
    if (flags < 0) {
        log_error("[C++ STEP 8.1 ERROR] Failed to get socket flags: %s", strerror(errno));
        close(sock);
        napi_throw_error(env, nullptr, "Failed to get socket flags");
        return nullptr;
    }
    
    log_info("[C++ STEP 8.1] Current socket flags: 0x%x (O_NONBLOCK=%s)", flags, (flags & O_NONBLOCK) ? "YES" : "NO");
    
    // 清除 O_NONBLOCK 标志，确保阻塞模式
    if (flags & O_NONBLOCK) {
        log_info("[C++ STEP 8.2] Socket is non-blocking, setting to blocking mode...");
        flags &= ~O_NONBLOCK;
        if (fcntl(sock, F_SETFL, flags) < 0) {
            log_error("[C++ STEP 8.3 ERROR] Failed to set socket to blocking mode: %s", strerror(errno));
            close(sock);
            napi_throw_error(env, nullptr, "Failed to set socket to blocking mode");
            return nullptr;
        }
        log_info("[C++ STEP 8.4] Socket set to BLOCKING mode successfully");
    } else {
        log_info("[C++ STEP 8.2] Socket is already in BLOCKING mode");
    }

    // Set socket timeout for blocking operations
    struct timeval timeout;
    timeout.tv_sec = 30;  // 30 seconds timeout for connect
    timeout.tv_usec = 0;
    
    log_info("[C++ STEP 8.5] Setting socket send timeout...");
    if (setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) < 0) {
        log_error("[C++ STEP 8.6 ERROR] Failed to set send timeout: %s", strerror(errno));
    }
    
    log_info("[C++ STEP 8.7] Setting socket receive timeout...");
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0) {
        log_error("[C++ STEP 8.8 ERROR] Failed to set receive timeout: %s", strerror(errno));
    }

    log_info("[C++ STEP 9] Preparing sockaddr...");

    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    
    if (inet_pton(AF_INET, host.c_str(), &server_addr.sin_addr) <= 0) {
        log_error("[C++ STEP 10 ERROR] Invalid address: %s", host.c_str());
        close(sock);
        napi_throw_error(env, nullptr, "Invalid address");
        return nullptr;
    }

    log_info("[C++ STEP 11] Address parsed successfully");
    log_info("[C++ STEP 12] Attempting to connect to %s:%d (BLOCKING mode with 30s timeout)...", host.c_str(), port);

    // 阻塞模式连接，socket 已设置超时
    // 重试机制：如果被信号中断（EINTR），则重试
    int connect_result;
    int retry_count = 0;
    const int MAX_RETRIES = 3;
    
    do {
        connect_result = connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr));
        
        if (connect_result == 0) {
            // 连接成功
            break;
        }
        
        if (errno == EINTR) {
            // 被信号中断，重试
            retry_count++;
            log_info("[C++ STEP 12.%d] connect() interrupted (EINTR), retrying... (%d/%d)", 
                retry_count, retry_count, MAX_RETRIES);
            
            if (retry_count >= MAX_RETRIES) {
                log_error("[C++ STEP 13 ERROR] connect() failed after %d retries: %s (errno=%d)", 
                    MAX_RETRIES, strerror(errno), errno);
                close(sock);
                napi_throw_error(env, nullptr, "Failed to connect: too many interruptions");
                return nullptr;
            }
            // 继续重试
            continue;
        } else if (errno == EINPROGRESS || errno == ETIMEDOUT) {
            // 在设置了超时的阻塞模式下,connect()可能返回EINPROGRESS表示超时
            // 这是因为SO_SNDTIMEO导致的,并非真正的非阻塞模式问题
            log_error("[C++ STEP 13 ERROR] connect() timeout: %s (errno=%d)", strerror(errno), errno);
            log_error("[C++ STEP 13.1 ERROR] Unable to reach %s:%d within timeout period", host.c_str(), port);
            log_error("[C++ STEP 13.2 ERROR] Please check: 1) Network connectivity 2) Firewall rules 3) Server availability");
            close(sock);
            napi_throw_error(env, nullptr, "Connection timeout: unable to reach server");
            return nullptr;
        } else {
            // 其他错误，不重试
            log_error("[C++ STEP 13 ERROR] connect() failed: %s (errno=%d)", strerror(errno), errno);
            close(sock);
            napi_throw_error(env, nullptr, "Failed to connect");
            return nullptr;
        }
    } while (connect_result < 0 && errno == EINTR);

    log_info("[C++ STEP 14] TCP connection established successfully!");
    log_info("[C++ STEP 21] Initializing libssh2 (lazy init)...");
    
    // Initialize libssh2 lazily on first use
    {
        std::lock_guard<std::mutex> lock(init_mutex);
        if (!libssh2_initialized) {
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[LIBSSH2 INIT] First time init");
            log_info("[C++ STEP 22] Calling libssh2_init(0)...");
            
            int rc = libssh2_init(0);
            if (rc != 0) {
                OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "[LIBSSH2 INIT ERROR] libssh2_init failed: rc=%d", rc);
                log_error("[C++ STEP 23 ERROR] libssh2_init failed: rc=%d", rc);
                close(sock);
                napi_throw_error(env, nullptr, "Failed to initialize libssh2");
                return nullptr;
            }
            libssh2_initialized = true;
            OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "[LIBSSH2 INIT SUCCESS] libssh2 initialized");
            log_info("[C++ STEP 23] libssh2 initialized successfully (first time)");
        } else {
            log_info("[C++ STEP 23] libssh2 already initialized, skipping");
        }
    }
    
    log_info("[C++ STEP 24] Creating libssh2 session...");

    LIBSSH2_SESSION *session = libssh2_session_init();
    if (!session) {
        log_error("[C++ STEP 25 ERROR] libssh2_session_init failed");
        close(sock);
        libssh2_exit();
        napi_throw_error(env, nullptr, "Failed to create libssh2 session");
        return nullptr;
    }

    log_info("[C++ STEP 26] libssh2 session created");
    log_info("[C++ STEP 27] Setting session timeout...");

    // Set timeout
    libssh2_session_set_timeout(session, 10000); // 10 seconds

    log_info("[C++ STEP 28] Starting SSH handshake...");

    if (libssh2_session_handshake(session, sock)) {
        char *errmsg;
        int errlen;
        libssh2_session_last_error(session, &errmsg, &errlen, 0);
        log_error("[C++ STEP 29 ERROR] SSH handshake failed: %.*s", errlen, errmsg);
        libssh2_session_free(session);
        close(sock);
        libssh2_exit();
        napi_throw_error(env, nullptr, "SSH handshake failed");
        return nullptr;
    }

    log_info("[C++ STEP 30] SSH handshake successful");
    log_info("[C++ STEP 31] Authenticating with password...");

    // Authenticate
    if (libssh2_userauth_password(session, user.c_str(), pass.c_str())) {
        char *errmsg;
        int errlen;
        libssh2_session_last_error(session, &errmsg, &errlen, 0);
        log_error("[C++ STEP 32 ERROR] SSH authentication failed: %.*s", errlen, errmsg);
        libssh2_session_disconnect(session, "Authentication failed");
        libssh2_session_free(session);
        close(sock);
        libssh2_exit();
        napi_throw_error(env, nullptr, "Authentication failed");
        return nullptr;
    }

    log_info("[C++ STEP 33] SSH authentication successful for user %s", user.c_str());
    log_info("[C++ STEP 34] Opening SSH channel...");

    // Open channel
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(session);
    if (!channel) {
        char *errmsg;
        int errlen;
        libssh2_session_last_error(session, &errmsg, &errlen, 0);
        log_error("[C++ STEP 35 ERROR] Failed to open SSH channel: %.*s", errlen, errmsg);
        libssh2_session_disconnect(session, "Failed to open channel");
        libssh2_session_free(session);
        close(sock);
        libssh2_exit();
        napi_throw_error(env, nullptr, "Failed to open channel");
        return nullptr;
    }

    log_info("[C++ STEP 36] SSH channel opened");
    log_info("[C++ STEP 37] Requesting PTY...");

    // Request PTY
    if (libssh2_channel_request_pty(channel, "vt100")) {
        char *errmsg;
        int errlen;
        libssh2_session_last_error(session, &errmsg, &errlen, 0);
        log_error("[C++ STEP 38 ERROR] Failed to request PTY: %.*s", errlen, errmsg);
        libssh2_channel_free(channel);
        libssh2_session_disconnect(session, "Failed to request PTY");
        libssh2_session_free(session);
        close(sock);
        libssh2_exit();
        napi_throw_error(env, nullptr, "Failed to request PTY");
        return nullptr;
    }

    log_info("[C++ STEP 39] PTY requested successfully");
    log_info("[C++ STEP 40] Starting shell...");

    // Start shell
    if (libssh2_channel_shell(channel)) {
        char *errmsg;
        int errlen;
        libssh2_session_last_error(session, &errmsg, &errlen, 0);
        log_error("[C++ STEP 41 ERROR] Failed to start shell: %.*s", errlen, errmsg);
        libssh2_channel_free(channel);
        libssh2_session_disconnect(session, "Failed to start shell");
        libssh2_session_free(session);
        close(sock);
        libssh2_exit();
        napi_throw_error(env, nullptr, "Failed to start shell");
        return nullptr;
    }

    log_info("[C++ STEP 42] SSH shell started successfully");
    log_info("[C++ STEP 43] Creating session object...");

    // Create session object
    KesshSession* kessh_session = new KesshSession{session, channel, sock};
    
    std::lock_guard<std::mutex> lock(session_mutex);
    int session_id = next_session_id++;
    sessions[session_id] = kessh_session;

    log_info("[C++ STEP 44] SSH session created with ID: %d", session_id);
    log_info("[C++ STEP 45] Preparing return value...");

    napi_value return_value;
    napi_create_int32(env, session_id, &return_value);
    
    log_info("[C++ STEP 46] OpenSession completed successfully, returning %d", session_id);
    return return_value;
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
    
    // 使用cat命令读取文件
    std::string command = "cat \"" + remote_path + "\" 2>&1";
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
    
    // 使用临时文件和base64编码传输
    // 先创建临时文件，然后写入内容
    std::string temp_file = "/tmp/kessh_upload_" + std::to_string(time(nullptr));
    std::string command = "cat > \"" + remote_path + "\"";
    
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

napi_value PingHost(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok || argc < 1) {
        napi_throw_error(env, nullptr, "PingHost: invalid arguments");
        return nullptr;
    }

    std::string host = get_string_arg(env, args[0]);
    if (!is_valid_host(host)) {
        napi_throw_error(env, nullptr, "PingHost: invalid host");
        return nullptr;
    }

    int32_t count = 4;
    if (argc >= 2) {
        napi_get_value_int32(env, args[1], &count);
    }
    if (count <= 0) {
        count = 4;
    }
    if (count > 10) {
        count = 10;
    }

    std::string args = "-c " + std::to_string(count) + " " + host + " 2>&1";
    std::vector<CommandCandidate> candidates = {
        {"/system/bin/ping", "/system/bin/ping"},
        {"/system/bin/toybox", "/system/bin/toybox ping"},
        {"", "toybox ping"},
        {"", "ping"}
    };

    std::string command = select_command(candidates, args);
    if (command.empty()) {
        std::string message = "未找到可用的 ping 命令，请确认系统是否包含 ping/toybox";
        napi_value fallback_value;
        napi_create_string_utf8(env, message.c_str(), message.length(), &fallback_value);
        return fallback_value;
    }

    std::string result = run_shell_command(command);

    napi_value return_value;
    napi_create_string_utf8(env, result.c_str(), result.length(), &return_value);
    return return_value;
}

napi_value TraceRoute(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2];
    napi_status status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (status != napi_ok || argc < 1) {
        napi_throw_error(env, nullptr, "TraceRoute: invalid arguments");
        return nullptr;
    }

    std::string host = get_string_arg(env, args[0]);
    if (!is_valid_host(host)) {
        napi_throw_error(env, nullptr, "TraceRoute: invalid host");
        return nullptr;
    }

    int32_t max_hops = 20;
    if (argc >= 2) {
        napi_get_value_int32(env, args[1], &max_hops);
    }
    if (max_hops <= 0) {
        max_hops = 20;
    }
    if (max_hops > 64) {
        max_hops = 64;
    }

    std::vector<CommandCandidate> traceroute_candidates = {
        {"/system/bin/traceroute", "/system/bin/traceroute"},
        {"/system/bin/toybox", "/system/bin/toybox traceroute"},
        {"", "toybox traceroute"},
        {"", "traceroute"}
    };
    std::vector<CommandCandidate> tracepath_candidates = {
        {"/system/bin/tracepath", "/system/bin/tracepath"},
        {"/system/bin/toybox", "/system/bin/toybox tracepath"},
        {"", "toybox tracepath"},
        {"", "tracepath"}
    };

    std::string args = host + " 2>&1";
    std::string command = select_command(traceroute_candidates, "-m " + std::to_string(max_hops) + " " + args);
    if (command.empty()) {
        command = select_command(tracepath_candidates, args);
    }

    if (command.empty()) {
        std::string message = "未找到 traceroute/tracepath 命令，请确认系统是否包含对应网络诊断工具";
        napi_value fallback_value;
        napi_create_string_utf8(env, message.c_str(), message.length(), &fallback_value);
        return fallback_value;
    }

    std::string result = run_shell_command(command);

    napi_value return_value;
    napi_create_string_utf8(env, result.c_str(), result.length(), &return_value);
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
        { "closeSession", nullptr, CloseSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "write", nullptr, Write, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "read", nullptr, Read, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "executeCommand", nullptr, ExecuteCommand, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "downloadFile", nullptr, DownloadFile, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "uploadFile", nullptr, UploadFile, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "testNative", nullptr, TestNative, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "pingHost", nullptr, PingHost, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "traceRoute", nullptr, TraceRoute, nullptr, nullptr, nullptr, napi_default, nullptr }
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