sshnative (HarmonyOS N-API) – Real SSH via libssh2 + wolfSSL

Overview
- Provides real SSH connectivity for the ArkTS app via a native N-API module named `sshnative`.
- Implements: `connectPassword`, `connectKey`, `connectKey2`, `execCommandPassword`, `execCommandKey`, `openSessionPassword`, `openSessionKey2`, `termWrite`, `termRead`, `termClose`.
- Backed by `libssh2` with wolfSSL as the crypto backend, supporting both一次性命令执行和交互式 PTY 会话。

Build Notes
- 需要为目标 ABI 准备 `libssh2` 与 `wolfSSL` 静态库及头文件，并在构建参数中显式指定。
  - 通过 `build-profile.json5` 里的 `LIBSSH2_INCLUDE_DIR_*`/`LIBSSH2_LIBRARY_*` 传入 `libssh2` 头文件与库路径；其中 `LIBSSH2_LIBRARY_*` 需要同时列出 `libssh2.a` 与依赖的 `libwolfssl.a`。
- 示例 CMake 缓存参数：
  - `-DLIBSSH2_INCLUDE_DIR=/path/to/libssh2/include`
  - `-DLIBSSH2_LIBRARY=/path/to/libssh2/lib/libssh2.a;/path/to/wolfssl/lib/libwolfssl.a`

Module Name
- 模块以 `sshnative` 名称注册（参见 `nm_modname`）。
- ArkTS 侧通过 `requireNapi('sshnative')` 使用，入口见 `Application/entry/src/main/ets/common/NativeSSH.ets`。

Session Lifecycle
- `openSession*` 返回一个 `sessionId`，供 `termWrite`、`termRead`、`termClose` 使用。
- `connect*` 仅进行连接与认证验证，成功后立即断开，可用于快速连通性检查。
- `execCommand*` 执行一次性命令并返回标准输出。

Known Requirements
- `libssh2` 必须在构建时启用 wolfSSL（或兼容的 OpenSSL 接口）支持。
- 应用需在 HarmonyOS 工程配置中开启网络权限。

Troubleshooting
- `requireNapi('sshnative')` 失败：确认模块已针对当前 ABI 构建并打包进 HAP。
- 链接失败：检查 `libssh2` 与 `wolfSSL` 的头文件/库路径是否正确传递给 CMake。
