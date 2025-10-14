// HarmonyOS N-API SSH bridge implemented with libssh and OpenSSL
#include <napi/native_api.h>
#include <js_native_api.h>

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <algorithm>

#include <libssh/libssh.h>
#include <libssh/callbacks.h>

struct SSHSession {
    ssh_session session{nullptr};
    ssh_channel channel{nullptr};
};

static std::atomic<int> g_next_id{1};
static std::mutex g_mutex;
static std::map<int, SSHSession*> g_sessions;

static ssh_session create_session(const std::string& host, int port, const std::string& user)
{
    ssh_session session = ssh_new();
    if (!session) {
        return nullptr;
    }
    ssh_options_set(session, SSH_OPTIONS_HOST, host.c_str());
    ssh_options_set(session, SSH_OPTIONS_PORT, &port);
    ssh_options_set(session, SSH_OPTIONS_USER, user.c_str());
    int strict = SSH_STRICTHOSTKEYCHECK_NO;
    ssh_options_set(session, SSH_OPTIONS_STRICTHOSTKEYCHECK, &strict);
    ssh_set_blocking(session, 1);
    return session;
}

static bool authenticate(ssh_session session, const std::string& user,
                         const std::string* password,
                         const std::string* privKey,
                         const std::string* passphrase)
{
    if (ssh_connect(session) != SSH_OK) {
        return false;
    }

    if (password) {
        if (ssh_userauth_password(session, user.c_str(), password->c_str()) == SSH_OK) {
            return true;
        }
        return false;
    }

    if (privKey) {
        ssh_key key = nullptr;
        int rc = ssh_pki_import_privkey_mem(privKey->c_str(), privKey->size(),
                                            passphrase ? passphrase->c_str() : nullptr,
                                            nullptr, nullptr, &key);
        if (rc != SSH_OK) {
            return false;
        }
        rc = ssh_userauth_publickey(session, user.c_str(), key);
        ssh_key_free(key);
        return rc == SSH_OK;
    }

    return false;
}

static void destroy_session(ssh_session session)
{
    if (!session) {
        return;
    }
    ssh_disconnect(session);
    ssh_free(session);
}

static SSHSession* open_shell_session(const std::string& host, int port,
                                      const std::string& user,
                                      const std::string* password,
                                      const std::string* privKey,
                                      const std::string* passphrase)
{
    ssh_session session = create_session(host, port, user);
    if (!session) {
        return nullptr;
    }

    if (!authenticate(session, user, password, privKey, passphrase)) {
        destroy_session(session);
        return nullptr;
    }

    ssh_channel channel = ssh_channel_new(session);
    if (!channel) {
        destroy_session(session);
        return nullptr;
    }

    if (ssh_channel_open_session(channel) != SSH_OK) {
        ssh_channel_free(channel);
        destroy_session(session);
        return nullptr;
    }

    if (ssh_channel_request_pty(channel) != SSH_OK) {
        ssh_channel_close(channel);
        ssh_channel_free(channel);
        destroy_session(session);
        return nullptr;
    }

    if (ssh_channel_request_shell(channel) != SSH_OK) {
        ssh_channel_close(channel);
        ssh_channel_free(channel);
        destroy_session(session);
        return nullptr;
    }

    SSHSession* s = new SSHSession();
    s->session = session;
    s->channel = channel;
    return s;
}

static bool test_connect(const std::string& host, int port,
                         const std::string& user,
                         const std::string* password,
                         const std::string* privKey,
                         const std::string* passphrase)
{
    ssh_session session = create_session(host, port, user);
    if (!session) {
        return false;
    }
    bool ok = authenticate(session, user, password, privKey, passphrase);
    destroy_session(session);
    return ok;
}

static std::string execute_command(const std::string& host, int port,
                                   const std::string& user,
                                   const std::string* password,
                                   const std::string* privKey,
                                   const std::string* passphrase,
                                   const std::string& command)
{
    ssh_session session = create_session(host, port, user);
    if (!session) {
        return std::string();
    }

    std::string output;
    if (!authenticate(session, user, password, privKey, passphrase)) {
        destroy_session(session);
        return output;
    }

    ssh_channel channel = ssh_channel_new(session);
    if (!channel) {
        destroy_session(session);
        return output;
    }

    if (ssh_channel_open_session(channel) != SSH_OK) {
        ssh_channel_free(channel);
        destroy_session(session);
        return output;
    }

    if (ssh_channel_request_exec(channel, command.c_str()) != SSH_OK) {
        ssh_channel_close(channel);
        ssh_channel_free(channel);
        destroy_session(session);
        return output;
    }

    char buffer[4096];
    for (;;) {
        int rc = ssh_channel_read_timeout(channel, buffer, sizeof(buffer), 0, 500);
        if (rc == SSH_AGAIN) {
            continue;
        }
        if (rc <= 0) {
            break;
        }
        output.append(buffer, buffer + rc);
    }

    ssh_channel_send_eof(channel);
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    destroy_session(session);
    return output;
}

// N-API helpers
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

    bool ok = test_connect(host, port, user, &pass, nullptr, nullptr);
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

    bool ok = test_connect(host, port, user, nullptr, &priv, &passphrase);
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
    // Public key parameter retained for API compatibility but unused with libssh memory import.
    (void)pub;
    bool ok = test_connect(host, port, user, nullptr, &priv, &passphrase);
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

    std::string out = execute_command(host, port, user, &pass, nullptr, nullptr, cmd);
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

    (void)pub;
    std::string out = execute_command(host, port, user, nullptr, &priv, &passphrase, cmd);
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

    SSHSession* s = open_shell_session(host, port, user, &pass, nullptr, nullptr);
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

    (void)pub;
    SSHSession* s = open_shell_session(host, port, user, nullptr, &priv, &passphrase);
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

    ssh_channel channel = it->second->channel;
    int written = ssh_channel_write(channel, data.c_str(), data.size());
    return boolean_of(env, written >= 0);
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

    ssh_channel channel = it->second->channel;
    std::string out;

    while (ssh_channel_is_open(channel) && !ssh_channel_is_eof(channel)) {
        int available = ssh_channel_poll_timeout(channel, 0, 0);
        if (available <= 0) {
            break;
        }
        int to_read = std::min(available, 4096);
        std::vector<char> buffer(static_cast<size_t>(to_read));
        int rc = ssh_channel_read(channel, buffer.data(), buffer.size(), 0);
        if (rc <= 0) {
            break;
        }
        out.append(buffer.data(), rc);
        if (rc < to_read) {
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

    if (session) {
        if (session->channel) {
            ssh_channel_send_eof(session->channel);
            ssh_channel_close(session->channel);
            ssh_channel_free(session->channel);
        }
        destroy_session(session->session);
        delete session;
    }

    return nullptr;
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
