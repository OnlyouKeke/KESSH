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
#include <hilog/log.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0xD15C
#define LOG_TAG "KesshNative"

static std::map<int, KesshSession*> sessions;
static int next_session_id = 1;
static std::mutex session_mutex;

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

napi_value OpenSession(napi_env env, napi_callback_info info) {
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

    std::string host = get_string_arg(env, args[0]);
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
    log_info("[C++ STEP 8] Using BLOCKING mode for socket");

    // 使用阻塞模式，不设置 O_NONBLOCK
    // Set socket timeout instead
    struct timeval timeout;
    timeout.tv_sec = 10;  // 10 seconds timeout
    timeout.tv_usec = 0;
    
    log_info("[C++ STEP 8.1] Setting socket send timeout...");
    if (setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout)) < 0) {
        log_error("[C++ STEP 8.2 ERROR] Failed to set send timeout: %s", strerror(errno));
    }
    
    log_info("[C++ STEP 8.3] Setting socket receive timeout...");
    if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) < 0) {
        log_error("[C++ STEP 8.4 ERROR] Failed to set receive timeout: %s", strerror(errno));
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
    log_info("[C++ STEP 12] Attempting to connect to %s:%d (BLOCKING mode with 10s timeout)...", host.c_str(), port);

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
        } else {
            // 其他错误，不重试
            log_error("[C++ STEP 13 ERROR] connect() failed: %s (errno=%d)", strerror(errno), errno);
            close(sock);
            napi_throw_error(env, nullptr, "Failed to connect");
            return nullptr;
        }
    } while (connect_result < 0 && errno == EINTR);

    log_info("[C++ STEP 14] TCP connection established successfully!");
    log_info("[C++ STEP 21] Initializing libssh2...");

    // Initialize libssh2
    int rc = libssh2_init(0);
    if (rc != 0) {
        log_error("[C++ STEP 22 ERROR] libssh2_init failed: rc=%d", rc);
        close(sock);
        napi_throw_error(env, nullptr, "Failed to initialize libssh2");
        return nullptr;
    }

    log_info("[C++ STEP 23] libssh2 initialized successfully");
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

    libssh2_exit();
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
            char buffer[4096];
            ssize_t n;
            int total_read = 0;
            
            // Non-blocking read
            while ((n = libssh2_channel_read(kessh_session->channel, buffer, sizeof(buffer))) > 0) {
                result_str.append(buffer, n);
                total_read += n;
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

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    log_info("Initializing kessh native module");
    
    napi_property_descriptor desc[] = {
        { "openSession", nullptr, OpenSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "closeSession", nullptr, CloseSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "write", nullptr, Write, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "read", nullptr, Read, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    
    log_info("Kessh native module initialized successfully");
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