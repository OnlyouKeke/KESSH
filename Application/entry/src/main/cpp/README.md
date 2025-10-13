sshnative (HarmonyOS N-API) — Real SSH via libssh2

Overview
- Provides real SSH connectivity for the ArkTS app via a native N-API module named `sshnative`.
- Implements: `connectPassword`, `connectKey`, `connectKey2`, `execCommandPassword`, `execCommandKey`, `openSessionPassword`, `openSessionKey2`, `termWrite`, `termRead`, `termClose`.
- Backed by `libssh2` with a PTY shell channel for interactive terminal.

Build Notes
- You must provide libssh2 for your HarmonyOS target.
  - Set `LIBSSH2_INCLUDE_DIR` and `LIBSSH2_LIBRARY` in your build configuration (e.g., from `build-profile.json5` toolchain settings or CMake toolchain file).
- Example CMake cache entries:
  - `-DLIBSSH2_INCLUDE_DIR=/path/to/libssh2/include`
  - `-DLIBSSH2_LIBRARY=/path/to/libssh2/lib/libssh2.a` (or `.so`)

Module Name
- The module registers itself as `sshnative` (see `nm_modname`).
- ArkTS uses `requireNapi('sshnative')` — already wired in `Application/entry/src/main/ets/common/NativeSSH.ets`.

Session Lifecycle
- `openSession*` returns a `sessionId` used by `termWrite`, `termRead`, and `termClose`.
- `connect*` performs a real connect/auth handshake and immediately closes — used for quick “test connection success”.
- `execCommand*` runs a one-off command and returns stdout.

Known Requirements
- libssh2 built with suitable crypto backend (OpenSSL, mbedTLS, etc.). Link its dependencies as needed.
- Network permissions for the app must be enabled in the HarmonyOS project configuration.

Troubleshooting
- If `requireNapi('sshnative')` fails, ensure the module is built and packaged into the HAP for the current ABI.
- If linking fails, verify `LIBSSH2_INCLUDE_DIR` and `LIBSSH2_LIBRARY` paths for your SDK/NDK environment.

