#ifndef KESSH_H
#define KESSH_H

#include "napi/native_api.h"
#include <libssh2.h>

// Represents an active SSH session
struct KesshSession {
    LIBSSH2_SESSION *session;
    LIBSSH2_CHANNEL *channel;
    int sock;
};

// Session management
napi_value OpenSession(napi_env env, napi_callback_info info);
napi_value CloseSession(napi_env env, napi_callback_info info);

// I/O operations
napi_value Write(napi_env env, napi_callback_info info);
napi_value Read(napi_env env, napi_callback_info info);

// Test function
napi_value TestNative(napi_env env, napi_callback_info info);

// Network utility helpers
napi_value PingHost(napi_env env, napi_callback_info info);
napi_value TraceRoute(napi_env env, napi_callback_info info);
napi_value TestPort(napi_env env, napi_callback_info info);

#endif // KESSH_H
