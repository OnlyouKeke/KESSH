'''#include "kessh.h"
#include <winsock2.h>
#include <ws2tcpip.h>
#include <fcntl.h>
#include <string>
#include <map>
#include <mutex>

#pragma comment(lib, "ws2_32.lib")

static std::map<int, KesshSession*> sessions;
static int next_session_id = 1;
static std::mutex session_mutex;

// Helper to get string argument
static std::string get_string_arg(napi_env env, napi_value value) {
    size_t len;
    napi_get_value_string_utf8(env, value, nullptr, 0, &len);
    std::string str(len, 0);
    napi_get_value_string_utf8(env, value, &str[0], len + 1, &len);
    return str;
}

napi_value OpenSession(napi_env env, napi_callback_info info) {
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        napi_throw_error(env, nullptr, "WSAStartup failed");
        return nullptr;
    }

    size_t argc = 4;
    napi_value args[4];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    std::string host = get_string_arg(env, args[0]);
    int32_t port;
    napi_get_value_int32(env, args[1], &port);
    std::string user = get_string_arg(env, args[2]);
    std::string pass = get_string_arg(env, args[3]);

    SOCKET sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons(port);
    inet_pton(AF_INET, host.c_str(), &sin.sin_addr);

    if (connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != 0) {
        napi_throw_error(env, nullptr, "Failed to connect");
        return nullptr;
    }

    LIBSSH2_SESSION *session = libssh2_session_init();
    if (!session) {
        napi_throw_error(env, nullptr, "Failed to initialize libssh2 session");
        return nullptr;
    }

    if (libssh2_session_handshake(session, sock)) {
        napi_throw_error(env, nullptr, "Failed to handshake");
        return nullptr;
    }

    if (libssh2_userauth_password(session, user.c_str(), pass.c_str())) {
        napi_throw_error(env, nullptr, "Authentication failed");
        return nullptr;
    }

    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(session);
    if (!channel) {
        napi_throw_error(env, nullptr, "Failed to open channel");
        return nullptr;
    }

    if (libssh2_channel_request_pty(channel, "vanilla")) {
        napi_throw_error(env, nullptr, "Failed to request PTY");
        return nullptr;
    }

    if (libssh2_channel_shell(channel)) {
        napi_throw_error(env, nullptr, "Failed to open shell");
        return nullptr;
    }

    KesshSession* kessh_session = new KesshSession{session, channel, sock};
    
    std::lock_guard<std::mutex> lock(session_mutex);
    int session_id = next_session_id++;
    sessions[session_id] = kessh_session;

    napi_value result;
    napi_create_int32(env, session_id, &result);
    return result;
}

napi_value CloseSession(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);

    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    if (it != sessions.end()) {
        KesshSession* kessh_session = it->second;
        libssh2_channel_free(kessh_session->channel);
        libssh2_session_disconnect(kessh_session->session, "Normal Shutdown");
        libssh2_session_free(kessh_session->session);
        closesocket(kessh_session->sock);
        delete kessh_session;
        sessions.erase(it);
    }

    WSACleanup();
    return nullptr;
}

napi_value Write(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t session_id;
    napi_get_value_int32(env, args[0], &session_id);
    std::string data = get_string_arg(env, args[1]);

    std::lock_guard<std::mutex> lock(session_mutex);
    auto it = sessions.find(session_id);
    if (it != sessions.end()) {
        KesshSession* kessh_session = it->second;
        libssh2_channel_write(kessh_session->channel, data.c_str(), data.length());
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
        char buffer[1024];
        ssize_t n;
        while ((n = libssh2_channel_read(kessh_session->channel, buffer, sizeof(buffer))) > 0) {
            result_str.append(buffer, n);
        }
    }

    napi_value result;
    napi_create_string_utf8(env, result_str.c_str(), result_str.length(), &result);
    return result;
}


EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "openSession", nullptr, OpenSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "closeSession", nullptr, CloseSession, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "write", nullptr, Write, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "read", nullptr, Read, nullptr, nullptr, nullptr, napi_default, nullptr }
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
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
    napi_module_register(&kessh_module);
}
''