// Real SSH implementation via libssh2 for HarmonyOS N-API
#include <napi/native_api.h>
#include <js_native_api.h>

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <cstring>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>

#include <libssh2.h>

struct SSHSession {
    int sock{-1};
    LIBSSH2_SESSION* session{nullptr};
    LIBSSH2_CHANNEL* channel{nullptr};
};

static std::once_flag g_lib_init_once;
static std::atomic<int> g_next_id{1};
static std::mutex g_mutex;
static std::map<int, SSHSession*> g_sessions;

static void ensure_lib_init()
{
    std::call_once(g_lib_init_once, [](){ libssh2_init(0); });
}

static int connect_tcp(const std::string& host, int port)
{
    struct addrinfo hints{}; memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;

    char portStr[16]; snprintf(portStr, sizeof(portStr), "%d", port);
    struct addrinfo* res = nullptr;
    int rc = getaddrinfo(host.c_str(), portStr, &hints, &res);
    if (rc != 0) return -1;

    int sock = -1;
    for (struct addrinfo* p = res; p != nullptr; p = p->ai_next) {
        sock = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (sock < 0) continue;
        if (::connect(sock, p->ai_addr, p->ai_addrlen) == 0) {
            break;
        }
        close(sock);
        sock = -1;
    }
    freeaddrinfo(res);
    return sock;
}

static bool do_handshake_and_auth(LIBSSH2_SESSION* session, int sock,
                                  const std::string& username,
                                  const std::string* password,
                                  const std::string* privKey,
                                  const std::string* pubKey,
                                  const std::string* passphrase)
{
    // Handshake
    while (true) {
        int rc = libssh2_session_handshake(session, sock);
        if (rc == 0) break;
        if (rc != LIBSSH2_ERROR_EAGAIN) return false;
    }

    // Auth
    if (password) {
        while (true) {
            int rc = libssh2_userauth_password(session, username.c_str(), password->c_str());
            if (rc == 0) break;
            if (rc != LIBSSH2_ERROR_EAGAIN) return false;
        }
        return true;
    }

    // Key auth
    if (privKey) {
        // If public key provided, try in-memory API, else fall back to private-only API
#ifdef LIBSSH2_USERAUTH_PUBLICKEY_FROMMEMORY
        if (pubKey) {
            while (true) {
                int rc = libssh2_userauth_publickey_frommemory(
                    session,
                    username.c_str(), static_cast<size_t>(username.size()),
                    pubKey->c_str(), static_cast<size_t>(pubKey->size()),
                    privKey->c_str(), static_cast<size_t>(privKey->size()),
                    passphrase ? passphrase->c_str() : nullptr
                );
                if (rc == 0) break;
                if (rc != LIBSSH2_ERROR_EAGAIN) return false;
            }
            return true;
        }
#endif
        while (true) {
            int rc = libssh2_userauth_publickey_frommemory(
                session,
                username.c_str(), static_cast<size_t>(username.size()),
                nullptr, 0,
                privKey->c_str(), static_cast<size_t>(privKey->size()),
                passphrase ? passphrase->c_str() : nullptr
            );
            if (rc == 0) break;
            if (rc != LIBSSH2_ERROR_EAGAIN) return false;
        }
        return true;
    }

    return false;
}

static SSHSession* open_shell_session(const std::string& host, int port,
                                      const std::string& username,
                                      const std::string* password,
                                      const std::string* privKey,
                                      const std::string* pubKey,
                                      const std::string* passphrase)
{
    ensure_lib_init();
    int sock = connect_tcp(host, port);
    if (sock < 0) return nullptr;

    LIBSSH2_SESSION* session = libssh2_session_init();
    if (!session) { close(sock); return nullptr; }
    libssh2_session_set_blocking(session, 0);

    if (!do_handshake_and_auth(session, sock, username, password, privKey, pubKey, passphrase)) {
        libssh2_session_disconnect(session, "auth failed");
        libssh2_session_free(session);
        close(sock);
        return nullptr;
    }

    LIBSSH2_CHANNEL* channel = nullptr;
    // Open a session channel
    while (true) {
        channel = libssh2_channel_open_session(session);
        if (channel) break;
        int err = libssh2_session_last_errno(session);
        if (err != LIBSSH2_ERROR_EAGAIN) {
            libssh2_session_disconnect(session, "channel open failed");
            libssh2_session_free(session);
            close(sock);
            return nullptr;
        }
    }
    // Request PTY
    while (true) {
        int rc = libssh2_channel_request_pty(channel, "xterm");
        if (rc == 0) break;
        if (rc != LIBSSH2_ERROR_EAGAIN) {
            libssh2_channel_free(channel);
            libssh2_session_free(session);
            close(sock);
            return nullptr;
        }
    }
    // Start shell
    while (true) {
        int rc = libssh2_channel_shell(channel);
        if (rc == 0) break;
        if (rc != LIBSSH2_ERROR_EAGAIN) {
            libssh2_channel_free(channel);
            libssh2_session_free(session);
            close(sock);
            return nullptr;
        }
    }

    SSHSession* s = new SSHSession();
    s->sock = sock;
    s->session = session;
    s->channel = channel;
    return s;
}

static bool test_connect(const std::string& host, int port,
                         const std::string& username,
                         const std::string* password,
                         const std::string* privKey,
                         const std::string* pubKey,
                         const std::string* passphrase)
{
    ensure_lib_init();
    int sock = connect_tcp(host, port);
    if (sock < 0) return false;
    LIBSSH2_SESSION* session = libssh2_session_init();
    if (!session) { close(sock); return false; }
    libssh2_session_set_blocking(session, 0);

    bool ok = do_handshake_and_auth(session, sock, username, password, privKey, pubKey, passphrase);
    libssh2_session_disconnect(session, "done");
    libssh2_session_free(session);
    close(sock);
    return ok;
}

// N-API helpers
static std::string get_string(napi_env env, napi_value v)
{
    size_t len = 0;
    napi_get_value_string_utf8(env, v, nullptr, 0, &len);
    std::string out; out.resize(len);
    size_t written = 0;
    napi_get_value_string_utf8(env, v, out.data(), len + 1, &written);
    out.resize(written);
    return out;
}

static napi_value boolean_of(napi_env env, bool b){ napi_value v; napi_get_boolean(env, b, &v); return v; }
static napi_value number_of(napi_env env, int32_t n){ napi_value v; napi_create_int32(env, n, &v); return v; }
static napi_value string_of(napi_env env, const std::string& s){ napi_value v; napi_create_string_utf8(env, s.c_str(), s.size(), &v); return v; }

static napi_value ConnectPassword(napi_env env, napi_callback_info info)
{
    size_t argc = 4; napi_value argv[4]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 3) return boolean_of(env, false);
    std::string host = get_string(env, argv[0]);
    int32_t port; napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string pass = argc >= 4 ? get_string(env, argv[3]) : std::string();
    bool ok = test_connect(host, port, user, &pass, nullptr, nullptr, nullptr);
    return boolean_of(env, ok);
}

static napi_value ConnectKey(napi_env env, napi_callback_info info)
{
    size_t argc = 5; napi_value argv[5]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 4) return boolean_of(env, false);
    std::string host = get_string(env, argv[0]);
    int32_t port; napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string passphrase = argc >= 5 ? get_string(env, argv[4]) : std::string();
    bool ok = test_connect(host, port, user, nullptr, &priv, nullptr, &passphrase);
    return boolean_of(env, ok);
}

static napi_value ConnectKey2(napi_env env, napi_callback_info info)
{
    size_t argc = 6; napi_value argv[6]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 5) return boolean_of(env, false);
    std::string host = get_string(env, argv[0]);
    int32_t port; napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string pub = get_string(env, argv[4]);
    std::string passphrase = argc >= 6 ? get_string(env, argv[5]) : std::string();
    bool ok = test_connect(host, port, user, nullptr, &priv, &pub, &passphrase);
    return boolean_of(env, ok);
}

static napi_value ExecCommandPassword(napi_env env, napi_callback_info info)
{
    // host, port, user, pass, command
    size_t argc = 5; napi_value argv[5]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 5) return string_of(env, "");
    std::string host = get_string(env, argv[0]);
    int32_t port; napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string pass = get_string(env, argv[3]);
    std::string cmd = get_string(env, argv[4]);

    ensure_lib_init();
    int sock = connect_tcp(host, port);
    if (sock < 0) return string_of(env, "");
    LIBSSH2_SESSION* session = libssh2_session_init();
    if (!session) { close(sock); return string_of(env, ""); }
    libssh2_session_set_blocking(session, 0);
    std::string out;
    if (do_handshake_and_auth(session, sock, user, &pass, nullptr, nullptr, nullptr)) {
        LIBSSH2_CHANNEL* channel = nullptr;
        while (true) {
            channel = libssh2_channel_open_session(session);
            if (channel) break;
            int err = libssh2_session_last_errno(session);
            if (err != LIBSSH2_ERROR_EAGAIN) { channel = nullptr; break; }
        }
        if (channel) {
            while (true) {
                int rc = libssh2_channel_exec(channel, cmd.c_str());
                if (rc == 0) break;
                if (rc != LIBSSH2_ERROR_EAGAIN) { libssh2_channel_free(channel); channel=nullptr; break; }
            }
            if (channel) {
                char buf[4096];
                for (;;) {
                    ssize_t n = libssh2_channel_read(channel, buf, sizeof(buf));
                    if (n == LIBSSH2_ERROR_EAGAIN) continue;
                    if (n <= 0) break;
                    out.append(buf, buf + n);
                }
                libssh2_channel_close(channel);
                libssh2_channel_free(channel);
            }
        }
    }
    libssh2_session_disconnect(session, "done");
    libssh2_session_free(session);
    close(sock);
    return string_of(env, out);
}

static napi_value ExecCommandKey(napi_env env, napi_callback_info info)
{
    // host, port, user, priv, pub, passphrase, command
    size_t argc = 7; napi_value argv[7]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 6) return string_of(env, "");
    std::string host = get_string(env, argv[0]);
    int32_t port; napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string pub = get_string(env, argv[4]);
    std::string passphrase = get_string(env, argv[5]);
    std::string cmd = argc >= 7 ? get_string(env, argv[6]) : std::string();

    ensure_lib_init();
    int sock = connect_tcp(host, port);
    if (sock < 0) return string_of(env, "");
    LIBSSH2_SESSION* session = libssh2_session_init();
    if (!session) { close(sock); return string_of(env, ""); }
    libssh2_session_set_blocking(session, 0);
    std::string out;
    if (do_handshake_and_auth(session, sock, user, nullptr, &priv, &pub, &passphrase)) {
        LIBSSH2_CHANNEL* channel = nullptr;
        while (true) {
            channel = libssh2_channel_open_session(session);
            if (channel) break;
            int err = libssh2_session_last_errno(session);
            if (err != LIBSSH2_ERROR_EAGAIN) { channel = nullptr; break; }
        }
        if (channel) {
            while (true) {
                int rc = libssh2_channel_exec(channel, cmd.c_str());
                if (rc == 0) break;
                if (rc != LIBSSH2_ERROR_EAGAIN) { libssh2_channel_free(channel); channel=nullptr; break; }
            }
            if (channel) {
                char buf[4096];
                for (;;) {
                    ssize_t n = libssh2_channel_read(channel, buf, sizeof(buf));
                    if (n == LIBSSH2_ERROR_EAGAIN) continue;
                    if (n <= 0) break;
                    out.append(buf, buf + n);
                }
                libssh2_channel_close(channel);
                libssh2_channel_free(channel);
            }
        }
    }
    libssh2_session_disconnect(session, "done");
    libssh2_session_free(session);
    close(sock);
    return string_of(env, out);
}

static napi_value OpenSessionPassword(napi_env env, napi_callback_info info)
{
    size_t argc = 4; napi_value argv[4]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 4) return number_of(env, -1);
    std::string host = get_string(env, argv[0]);
    int32_t port; napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string pass = get_string(env, argv[3]);
    SSHSession* s = open_shell_session(host, port, user, &pass, nullptr, nullptr, nullptr);
    if (!s) return number_of(env, -1);
    int id = g_next_id++;
    std::lock_guard<std::mutex> lk(g_mutex);
    g_sessions[id] = s;
    return number_of(env, id);
}

static napi_value OpenSessionKey2(napi_env env, napi_callback_info info)
{
    size_t argc = 6; napi_value argv[6]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 5) return number_of(env, -1);
    std::string host = get_string(env, argv[0]);
    int32_t port; napi_get_value_int32(env, argv[1], &port);
    std::string user = get_string(env, argv[2]);
    std::string priv = get_string(env, argv[3]);
    std::string pub = get_string(env, argv[4]);
    std::string passphrase = argc >= 6 ? get_string(env, argv[5]) : std::string();
    SSHSession* s = open_shell_session(host, port, user, nullptr, &priv, &pub, &passphrase);
    if (!s) return number_of(env, -1);
    int id = g_next_id++;
    std::lock_guard<std::mutex> lk(g_mutex);
    g_sessions[id] = s;
    return number_of(env, id);
}

static napi_value TermWrite(napi_env env, napi_callback_info info)
{
    size_t argc = 2; napi_value argv[2]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 2) return boolean_of(env, false);
    int32_t id; napi_get_value_int32(env, argv[0], &id);
    std::string data = get_string(env, argv[1]);
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it = g_sessions.find(id);
    if (it == g_sessions.end()) return boolean_of(env, false);
    SSHSession* s = it->second;
    ssize_t n = libssh2_channel_write(s->channel, data.c_str(), data.size());
    return boolean_of(env, n >= 0);
}

static napi_value TermRead(napi_env env, napi_callback_info info)
{
    size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) return string_of(env, "");
    int32_t id; napi_get_value_int32(env, argv[0], &id);
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it = g_sessions.find(id);
    if (it == g_sessions.end()) return string_of(env, "");
    SSHSession* s = it->second;
    char buf[4096];
    std::string out;
    for (;;) {
        ssize_t n = libssh2_channel_read(s->channel, buf, sizeof(buf));
        if (n == LIBSSH2_ERROR_EAGAIN) break;
        if (n <= 0) break;
        out.append(buf, buf + n);
        if (n < (ssize_t)sizeof(buf)) break;
    }
    return string_of(env, out);
}

static napi_value TermClose(napi_env env, napi_callback_info info)
{
    size_t argc = 1; napi_value argv[1]; napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 1) return nullptr;
    int32_t id; napi_get_value_int32(env, argv[0], &id);
    SSHSession* s = nullptr;
    {
        std::lock_guard<std::mutex> lk(g_mutex);
        auto it = g_sessions.find(id);
        if (it != g_sessions.end()) { s = it->second; g_sessions.erase(it); }
    }
    if (s) {
        if (s->channel) {
            libssh2_channel_close(s->channel);
            libssh2_channel_free(s->channel);
        }
        if (s->session) {
            libssh2_session_disconnect(s->session, "bye");
            libssh2_session_free(s->session);
        }
        if (s->sock >= 0) close(s->sock);
        delete s;
    }
    return nullptr;
}

static void define_function(napi_env env, napi_value exports, const char* name, napi_callback cb)
{
    napi_value fn; napi_create_function(env, name, NAPI_AUTO_LENGTH, cb, nullptr, &fn);
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
    return exports;
}

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
