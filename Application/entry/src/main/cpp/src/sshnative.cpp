#include <napi/native_api.h>
#include <js_native_api.h>

#include <libssh2.h>

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <algorithm>

#include <cerrno>
#include <cstring>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
using socket_t = SOCKET;
#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
using socket_t = int;
#endif

namespace {

struct SSHSession {
    LIBSSH2_SESSION* session{nullptr};
    LIBSSH2_CHANNEL* channel{nullptr};
    socket_t sock{-1};
};

static std::atomic<int> g_next_id{1};
static std::mutex g_mutex;
static std::map<int, SSHSession*> g_sessions;

static std::mutex g_init_mutex;
static bool g_libssh2_ready = false;

#ifdef _WIN32
static void close_socket(socket_t sock)
{
    if (sock != INVALID_SOCKET) {
        closesocket(sock);
    }
}
#else
static void close_socket(socket_t sock)
{
    if (sock >= 0) {
        close(sock);
    }
}
#endif

static bool ensure_lib_init()
{
    std::lock_guard<std::mutex> lock(g_init_mutex);
    if (g_libssh2_ready) {
        return true;
    }
#ifdef _WIN32
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) {
        return false;
    }
#endif
    if (libssh2_init(0) != 0) {
        return false;
    }
    g_libssh2_ready = true;
    return true;
}

static socket_t connect_socket(const std::string& host, int port)
{
    struct addrinfo hints;
    std::memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    std::string port_str = std::to_string(port);
    struct addrinfo* res = nullptr;
    if (getaddrinfo(host.c_str(), port_str.c_str(), &hints, &res) != 0) {
        return static_cast<socket_t>(-1);
    }

    socket_t sock = static_cast<socket_t>(-1);
    for (struct addrinfo* p = res; p; p = p->ai_next) {
        socket_t s = static_cast<socket_t>(::socket(p->ai_family, p->ai_socktype, p->ai_protocol));
#ifdef _WIN32
        if (s == INVALID_SOCKET) {
            continue;
        }
#else
        if (s < 0) {
            continue;
        }
#endif
        if (::connect(s, p->ai_addr, static_cast<int>(p->ai_addrlen)) == 0) {
            sock = s;
            break;
        }
        close_socket(s);
    }

    freeaddrinfo(res);
    return sock;
}

static void destroy_session(SSHSession* session)
{
    if (!session) {
        return;
    }

    if (session->channel) {
        libssh2_channel_send_eof(session->channel);
        libssh2_channel_close(session->channel);
        libssh2_channel_free(session->channel);
        session->channel = nullptr;
    }

    if (session->session) {
        libssh2_session_disconnect(session->session, "Normal shutdown");
        libssh2_session_free(session->session);
        session->session = nullptr;
    }

    if (session->sock != static_cast<socket_t>(-1)) {
        close_socket(session->sock);
        session->sock = static_cast<socket_t>(-1);
    }

    delete session;
}

static bool authenticate(LIBSSH2_SESSION* session,
                         const std::string& user,
                         const std::string* password,
                         const std::string* privKey,
                         const std::string* pubKey,
                         const std::string* passphrase)
{
    if (password && !password->empty()) {
        int rc = libssh2_userauth_password(session, user.c_str(), password->c_str());
        return rc == 0;
    }

    if (privKey) {
        const char* pub_ptr = nullptr;
        size_t pub_len = 0;
        if (pubKey && !pubKey->empty()) {
            pub_ptr = pubKey->c_str();
            pub_len = pubKey->size();
        }
        const char* pass = (passphrase && !passphrase->empty()) ? passphrase->c_str() : nullptr;
        int rc = libssh2_userauth_publickey_frommemory(session,
                                                       user.c_str(),
                                                       user.size(),
                                                       pub_ptr,
                                                       pub_len,
                                                       privKey->c_str(),
                                                       privKey->size(),
                                                       pass);
        return rc == 0;
    }

    return false;
}

static bool create_authenticated_session(const std::string& host,
                                         int port,
                                         const std::string& user,
                                         const std::string* password,
                                         const std::string* privKey,
                                         const std::string* pubKey,
                                         const std::string* passphrase,
                                         LIBSSH2_SESSION** out_session,
                                         socket_t* out_sock)
{
    if (!ensure_lib_init()) {
        return false;
    }

    socket_t sock = connect_socket(host, port);
#ifdef _WIN32
    if (sock == INVALID_SOCKET) {
        return false;
    }
#else
    if (sock < 0) {
        return false;
    }
#endif

    LIBSSH2_SESSION* session = libssh2_session_init();
    if (!session) {
        close_socket(sock);
        return false;
    }

    libssh2_session_set_blocking(session, 1);

    if (libssh2_session_handshake(session, sock) != 0) {
        libssh2_session_free(session);
        close_socket(sock);
        return false;
    }

    if (!authenticate(session, user, password, privKey, pubKey, passphrase)) {
        libssh2_session_disconnect(session, "Authentication failed");
        libssh2_session_free(session);
        close_socket(sock);
        return false;
    }

    *out_session = session;
    *out_sock = sock;
    return true;
}

static SSHSession* open_shell_session(const std::string& host,
                                      int port,
                                      const std::string& user,
                                      const std::string* password,
                                      const std::string* privKey,
                                      const std::string* pubKey,
                                      const std::string* passphrase)
{
    LIBSSH2_SESSION* session = nullptr;
    socket_t sock = static_cast<socket_t>(-1);
    if (!create_authenticated_session(host, port, user, password, privKey, pubKey, passphrase,
                                      &session, &sock)) {
        return nullptr;
    }

    LIBSSH2_CHANNEL* channel = libssh2_channel_open_session(session);
    if (!channel) {
        libssh2_session_disconnect(session, "Failed to open channel");
        libssh2_session_free(session);
        close_socket(sock);
        return nullptr;
    }

    if (libssh2_channel_request_pty(channel, "xterm") != 0) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        libssh2_session_disconnect(session, "Failed to request PTY");
        libssh2_session_free(session);
        close_socket(sock);
        return nullptr;
    }

    if (libssh2_channel_shell(channel) != 0) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        libssh2_session_disconnect(session, "Failed to start shell");
        libssh2_session_free(session);
        close_socket(sock);
        return nullptr;
    }

    libssh2_session_set_blocking(session, 0);
    libssh2_channel_set_blocking(channel, 0);

    SSHSession* s = new SSHSession();
    s->session = session;
    s->channel = channel;
    s->sock = sock;
    return s;
}

static bool test_connect(const std::string& host,
                         int port,
                         const std::string& user,
                         const std::string* password,
                         const std::string* privKey,
                         const std::string* pubKey,
                         const std::string* passphrase)
{
    LIBSSH2_SESSION* session = nullptr;
    socket_t sock = static_cast<socket_t>(-1);
    if (!create_authenticated_session(host, port, user, password, privKey, pubKey, passphrase,
                                      &session, &sock)) {
        return false;
    }

    libssh2_session_disconnect(session, "Test complete");
    libssh2_session_free(session);
    close_socket(sock);
    return true;
}

static std::string execute_command(const std::string& host,
                                   int port,
                                   const std::string& user,
                                   const std::string* password,
                                   const std::string* privKey,
                                   const std::string* pubKey,
                                   const std::string* passphrase,
                                   const std::string& command)
{
    LIBSSH2_SESSION* session = nullptr;
    socket_t sock = static_cast<socket_t>(-1);
    std::string output;

    if (!create_authenticated_session(host, port, user, password, privKey, pubKey, passphrase,
                                      &session, &sock)) {
        return output;
    }

    LIBSSH2_CHANNEL* channel = libssh2_channel_open_session(session);
    if (!channel) {
        libssh2_session_disconnect(session, "Failed to open channel");
        libssh2_session_free(session);
        close_socket(sock);
        return output;
    }

    if (libssh2_channel_exec(channel, command.c_str()) != 0) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        libssh2_session_disconnect(session, "Failed to exec command");
        libssh2_session_free(session);
        close_socket(sock);
        return output;
    }

    char buffer[4096];
    while (true) {
        ssize_t rc = libssh2_channel_read(channel, buffer, sizeof(buffer));
        if (rc > 0) {
            output.append(buffer, buffer + rc);
        } else if (rc == LIBSSH2_ERROR_EAGAIN) {
            // Wait briefly for more data
            LIBSSH2_POLLFD pfd;
            std::memset(&pfd, 0, sizeof(pfd));
            pfd.type = LIBSSH2_POLLFD_CHANNEL;
            pfd.fd.channel = channel;
            pfd.events = LIBSSH2_POLLFD_POLLIN;
            libssh2_poll(&pfd, 1, 100);
        } else {
            break;
        }
    }

    libssh2_channel_send_eof(channel);
    libssh2_channel_close(channel);
    libssh2_channel_free(channel);
    libssh2_session_disconnect(session, "Command complete");
    libssh2_session_free(session);
    close_socket(sock);

    return output;
}

static std::string get_string(napi_env env, napi_value v)
{
    size_t len = 0;
    napi_get_value_string_utf8(env, v, nullptr, 0, &len);
    std::string out;
    out.resize(len);
    size_t written = 0;
    napi_get_value_string_utf8(env, v, out.data(), len + 1, &written);
    out.resize(written);
    return out;
}

static napi_value boolean_of(napi_env env, bool b)
{
    napi_value v;
    napi_get_boolean(env, b, &v);
    return v;
}

static napi_value number_of(napi_env env, int32_t n)
{
    napi_value v;
    napi_create_int32(env, n, &v);
    return v;
}

static napi_value string_of(napi_env env, const std::string& s)
{
    napi_value v;
    napi_create_string_utf8(env, s.c_str(), s.size(), &v);
    return v;
}

static napi_value ConnectPassword(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value argv[4];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 3) {
        return boolean_of(env, false);
    }

    std::string host = get_string(env, argv[0]);
    int32_t port;
    napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string pass = argc >= 4 ? get_string(env, argv[3]) : std::string();

    bool ok = test_connect(host, port, user, &pass, nullptr, nullptr, nullptr);
    return boolean_of(env, ok);
}

static napi_value ConnectKey(napi_env env, napi_callback_info info)
{
    size_t argc = 5;
    napi_value argv[5];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 4) {
        return boolean_of(env, false);
    }

    std::string host = get_string(env, argv[0]);
    int32_t port;
    napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string passphrase = argc >= 5 ? get_string(env, argv[4]) : std::string();

    bool ok = test_connect(host, port, user, nullptr, &priv, nullptr, &passphrase);
    return boolean_of(env, ok);
}

static napi_value ConnectKey2(napi_env env, napi_callback_info info)
{
    size_t argc = 6;
    napi_value argv[6];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 5) {
        return boolean_of(env, false);
    }

    std::string host = get_string(env, argv[0]);
    int32_t port;
    napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string pub = get_string(env, argv[4]);
    std::string passphrase = argc >= 6 ? get_string(env, argv[5]) : std::string();

    bool ok = test_connect(host, port, user, nullptr, &priv, &pub, &passphrase);
    return boolean_of(env, ok);
}

static napi_value ExecCommandPassword(napi_env env, napi_callback_info info)
{
    size_t argc = 5;
    napi_value argv[5];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 5) {
        return string_of(env, "");
    }

    std::string host = get_string(env, argv[0]);
    int32_t port;
    napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string pass = get_string(env, argv[3]);
    std::string cmd = get_string(env, argv[4]);

    std::string out = execute_command(host, port, user, &pass, nullptr, nullptr, nullptr, cmd);
    return string_of(env, out);
}

static napi_value ExecCommandKey(napi_env env, napi_callback_info info)
{
    size_t argc = 7;
    napi_value argv[7];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 6) {
        return string_of(env, "");
    }

    std::string host = get_string(env, argv[0]);
    int32_t port;
    napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string pub = get_string(env, argv[4]);
    std::string passphrase = get_string(env, argv[5]);
    std::string cmd = argc >= 7 ? get_string(env, argv[6]) : std::string();

    std::string out = execute_command(host, port, user, nullptr, &priv, &pub, &passphrase, cmd);
    return string_of(env, out);
}

static napi_value OpenSessionPassword(napi_env env, napi_callback_info info)
{
    size_t argc = 4;
    napi_value argv[4];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 4) {
        return number_of(env, -1);
    }

    std::string host = get_string(env, argv[0]);
    int32_t port;
    napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string pass = get_string(env, argv[3]);

    SSHSession* s = open_shell_session(host, port, user, &pass, nullptr, nullptr, nullptr);
    if (!s) {
        return number_of(env, -1);
    }

    int id = g_next_id++;
    std::lock_guard<std::mutex> lk(g_mutex);
    g_sessions[id] = s;
    return number_of(env, id);
}

static napi_value OpenSessionKey2(napi_env env, napi_callback_info info)
{
    size_t argc = 6;
    napi_value argv[6];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 5) {
        return number_of(env, -1);
    }

    std::string host = get_string(env, argv[0]);
    int32_t port;
    napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string pub = get_string(env, argv[4]);
    std::string passphrase = argc >= 6 ? get_string(env, argv[5]) : std::string();

    SSHSession* s = open_shell_session(host, port, user, nullptr, &priv, &pub, &passphrase);
    if (!s) {
        return number_of(env, -1);
    }

    int id = g_next_id++;
    std::lock_guard<std::mutex> lk(g_mutex);
    g_sessions[id] = s;
    return number_of(env, id);
}

static napi_value TermWrite(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 2) {
        return boolean_of(env, false);
    }

    int32_t id;
    napi_get_value_int32(env, argv[0], &id);
    std::string data = get_string(env, argv[1]);

    std::lock_guard<std::mutex> lk(g_mutex);
    auto it = g_sessions.find(id);
    if (it == g_sessions.end() || !it->second->channel) {
        return boolean_of(env, false);
    }

    LIBSSH2_CHANNEL* channel = it->second->channel;
    size_t offset = 0;
    while (offset < data.size()) {
        ssize_t rc = libssh2_channel_write(channel,
                                           data.data() + offset,
                                           data.size() - offset);
        if (rc == LIBSSH2_ERROR_EAGAIN) {
            LIBSSH2_POLLFD pfd;
            std::memset(&pfd, 0, sizeof(pfd));
            pfd.type = LIBSSH2_POLLFD_CHANNEL;
            pfd.fd.channel = channel;
            pfd.events = LIBSSH2_POLLFD_POLLOUT;
            libssh2_poll(&pfd, 1, 100);
            continue;
        }
        if (rc < 0) {
            return boolean_of(env, false);
        }
        offset += static_cast<size_t>(rc);
    }

    return boolean_of(env, true);
}

static napi_value TermRead(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) {
        return string_of(env, "");
    }

    int32_t id;
    napi_get_value_int32(env, argv[0], &id);

    std::lock_guard<std::mutex> lk(g_mutex);
    auto it = g_sessions.find(id);
    if (it == g_sessions.end() || !it->second->channel) {
        return string_of(env, "");
    }

    LIBSSH2_CHANNEL* channel = it->second->channel;
    std::string out;

    while (libssh2_poll_channel_read(channel, 0) > 0) {
        std::vector<char> buffer(4096);
        ssize_t rc = libssh2_channel_read(channel, buffer.data(), buffer.size());
        if (rc > 0) {
            out.append(buffer.data(), static_cast<size_t>(rc));
            if (rc < static_cast<ssize_t>(buffer.size())) {
                break;
            }
        } else if (rc == LIBSSH2_ERROR_EAGAIN) {
            break;
        } else {
            break;
        }
    }

    return string_of(env, out);
}

static napi_value TermClose(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) {
        return nullptr;
    }

    int32_t id;
    napi_get_value_int32(env, argv[0], &id);

    SSHSession* session = nullptr;
    {
        std::lock_guard<std::mutex> lk(g_mutex);
        auto it = g_sessions.find(id);
        if (it != g_sessions.end()) {
            session = it->second;
            g_sessions.erase(it);
        }
    }

    destroy_session(session);
    return nullptr;
}

static napi_value GetVersion(napi_env env, napi_callback_info info)
{
    if (!ensure_lib_init()) {
        return string_of(env, "");
    }
    const char* ver = libssh2_version(0);
    if (!ver) {
        return string_of(env, "");
    }
    return string_of(env, ver);
}

static void define_function(napi_env env, napi_value exports, const char* name, napi_callback cb)
{
    napi_value fn;
    napi_create_function(env, name, NAPI_AUTO_LENGTH, cb, nullptr, &fn);
    napi_set_named_property(env, exports, name, fn);
}

static napi_value Init(napi_env env, napi_value exports)
{
    define_function(env, exports, "connectPassword", ConnectPassword);
    define_function(env, exports, "connectKey", ConnectKey);
    define_function(env, exports, "connectKey2", ConnectKey2);
    define_function(env, exports, "execCommandPassword", ExecCommandPassword);
    define_function(env, exports, "execCommandKey", ExecCommandKey);
    define_function(env, exports, "openSessionPassword", OpenSessionPassword);
    define_function(env, exports, "openSessionKey2", OpenSessionKey2);
    define_function(env, exports, "termWrite", TermWrite);
    define_function(env, exports, "termRead", TermRead);
    define_function(env, exports, "termClose", TermClose);
    define_function(env, exports, "getVersion", GetVersion);
    return exports;
}

} // namespace

extern "C" __attribute__((constructor)) void RegisterSshNative()
{
    static napi_module g_module = {
        .nm_version = 1,
        .nm_flags = 0,
        .nm_filename = nullptr,
        .nm_register_func = Init,
        .nm_modname = (char*)"sshnative",
        .nm_priv = nullptr,
        .reserved = { 0 }
    };
    napi_module_register(&g_module);
}
