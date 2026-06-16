# KESSH

KESSH is a HarmonyOS Stage application for SSH-related workflows. The repository contains the HarmonyOS app, cloud-side code, native dependency build scripts, documentation, and local test utilities.

## Repository layout

- `Application/` — HarmonyOS Stage main project. Open this directory in DevEco Studio.
- `Application/entry/` — main HAP module, including ArkTS UI code and the C++ NAPI module.
- `Application/cloud_objects/` — HAR module for cloud object interfaces.
- `CloudProgram/` — cloud-side Node/TypeScript project.
- `scripts/` — engineering scripts. `build_third_party.sh` builds native SSH dependencies.
- `docs/` — build and engineering documentation.
- `tests/` — local WebSocket and native smoke-test utilities.

Generated output, dependency installs, logs, signing materials, and local build caches should stay out of version control. Recreate them from the scripts and lock files when needed.

## Native dependencies

The app's native SSH module depends on **wolfSSL** and **libssh2**. Build them with the helper script from the repository root:

```bash
export OHOS_NDK_HOME=/path/to/harmony/ndk
./scripts/build_third_party.sh --abi arm64-v8a
./scripts/build_third_party.sh --abi x86_64
```

The script installs artifacts to these default locations:

- `wolfssl-out/<abi>/include`
- `wolfssl-out/<abi>/lib/libwolfssl.a`
- `libssh2-out/<abi>/include`
- `libssh2-out/<abi>/lib/libssh2.a`

`Application/entry/src/main/cpp/CMakeLists.txt` uses those repository-local outputs by default. If you set `OUTPUT_ROOT` when running the script, pass matching CMake variables through `externalNativeOptions.arguments`, for example:

```text
-DWOLFSSL_ROOT=/absolute/path/wolfssl-out/arm64-v8a -DLIBSSH2_ROOT=/absolute/path/libssh2-out/arm64-v8a
```

Additional script options:

- `--abi <abi>` — build a specific ABI. The app currently builds `arm64-v8a` and `x86_64`.
- `--clean` — remove cached source archives and intermediate native build directories before rebuilding.
- `WOLFSSL_VERSION`, `LIBSSH2_VERSION`, `OHOS_API_LEVEL`, `OUTPUT_ROOT`, and `JOBS` can be overridden through environment variables.

See `docs/第三方库编译说明.md` for the Chinese walkthrough and troubleshooting notes.

## HarmonyOS app build

From `Application/`:

```bash
ohpm install
hvigor assembleHap
```

If your local Hvigor task names differ, use DevEco Studio's build panel or list available Hvigor tasks and run the equivalent entry HAP build. Before building the native module, make sure `wolfssl-out/<abi>` and `libssh2-out/<abi>` exist for every ABI in `Application/entry/build-profile.json5`.

Signing materials such as `.p12`, `.p7b`, `.cer`, `.csr`, `.keystore`, and `.jks` files are local secrets and should not be committed. Configure signing locally in DevEco Studio or through a private build environment.

## CloudProgram

From `CloudProgram/`:

```bash
npm ci
```

`node_modules/` and generated cloud build output are local artifacts. Keep `package.json` and lock files in version control so dependencies can be restored consistently.

## WebSocket test utilities

This project includes WebSocket implementations for local testing:

- `tests/websocket_ssh_server.js` — WebSocket proxy server that bridges WebSocket connections to SSH servers.
- `Application/entry/src/main/ets/common/WebSocketSSHClient.ets` — HarmonyOS WebSocket SSH client.
- `Application/entry/src/main/ets/pages/WebSocketSSHTestPage.ets` — test terminal interface.
- `Application/entry/src/main/ets/common/WebSocketClient.ets` — general WebSocket client wrapper.
- `Application/entry/src/main/ets/pages/WebSocketTestPage.ets` — WebSocket test page.
- `tests/websocket_server.js` — simple echo WebSocket server.

To run the SSH proxy test server:

```bash
cd tests
npm install
node websocket_ssh_server.js
```

Then open the WebSocket SSH test page in the HarmonyOS app and connect to the proxy URL shown by the server.
