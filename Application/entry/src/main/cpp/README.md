sshnative (HarmonyOS N-API) — Real SSH via libssh + OpenSSL

Overview
- Provides real SSH connectivity for the ArkTS app via a native N-API module named `sshnative`.
- Implements: `connectPassword`, `connectKey`, `connectKey2`, `execCommandPassword`, `execCommandKey`, `openSessionPassword`, `openSessionKey2`, `termWrite`, `termRead`, `termClose`.
- Backed by `libssh` with OpenSSL as the crypto backend, exposing both one-off command execution and interactive PTY sessions.

Build Notes
- You must provide libssh and OpenSSL for your HarmonyOS target.
  - Set `LIBSSH_INCLUDE_DIR`/`LIBSSH_LIBRARY` and `OPENSSL_INCLUDE_DIR`/`OPENSSL_LIBS` in your build configuration (e.g., from `build-profile.json5`).
- Example CMake cache entries:
  - `-DLIBSSH_INCLUDE_DIR=/path/to/libssh/include`
  - `-DLIBSSH_LIBRARY=/path/to/libssh/lib/libssh.a`
  - `-DOPENSSL_INCLUDE_DIR=/path/to/openssl/include`
  - `-DOPENSSL_LIBS=/path/to/openssl/lib/libssl.a;/path/to/openssl/lib/libcrypto.a`

Module Name
- The module registers itself as `sshnative` (see `nm_modname`).
- ArkTS uses `requireNapi('sshnative')` — already wired in `Application/entry/src/main/ets/common/NativeSSH.ets`.

Session Lifecycle
- `openSession*` returns a `sessionId` used by `termWrite`, `termRead`, and `termClose`.
- `connect*` performs a real connect/auth handshake and immediately closes — used for quick “test connection success”.
- `execCommand*` runs a one-off command and returns stdout.

Known Requirements
- libssh must be compiled with OpenSSL support (the provided build script does this automatically).
- Network permissions for the app must be enabled in the HarmonyOS project configuration.

Troubleshooting
- If `requireNapi('sshnative')` fails, ensure the module is built and packaged into the HAP for the current ABI.
- If linking fails, verify the libssh and OpenSSL include/library paths provided to CMake.
