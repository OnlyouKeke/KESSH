# KESSH Native Dependencies Build

The project now relies on **OpenSSL** and **libssh** for SSH connectivity. Use the helper
script to fetch and compile the two libraries for HarmonyOS targets.

## Prerequisites

- HarmonyOS Native SDK (`OHOS_NDK_HOME` must point to the SDK root; the script
  will automatically search both `build/cmake/ohos.toolchain.cmake` and
  `native/build/cmake/ohos.toolchain.cmake`).
- `cmake`, `curl`, `perl`, `tar`, and optionally `ninja` for faster builds.

## Building OpenSSL and libssh

```bash
# From the repository root
export OHOS_NDK_HOME=/path/to/harmony/ndk
./scripts/build_third_party.sh
```

Artifacts are installed to `openssl-out/<abi>` and `libssh-out/<abi>`. Set `OUTPUT_ROOT`
to override the destination base directory.

Additional options:

- `--abi <abi>` – build for a specific ABI (default `arm64-v8a`).
- `--clean` – drop cached downloads and intermediate build directories.
- Override `OPENSSL_VERSION`, `LIBSSH_VERSION`, or `OHOS_API_LEVEL`
  through environment variables as needed.

See `docs/第三方库编译说明.md` for a Chinese walkthrough.
