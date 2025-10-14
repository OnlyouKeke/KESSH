// Minimal SSH N-API bridge for HarmonyOS using libssh
#pragma once

#include <napi/native_api.h>
#include <js_native_api.h>

#ifdef __cplusplus
extern "C" {
#endif

napi_value SSH_Init(napi_env env, napi_value exports);

#ifdef __cplusplus
}
#endif
