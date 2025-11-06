#!/usr/bin/env bash
set -euo pipefail

# Builds wolfSSL and libssh2 for HarmonyOS using the NDK toolchain.
#
# Environment variables:
#   OHOS_NDK_HOME (required)  - path to the HarmonyOS Native SDK.
#   OHOS_API_LEVEL (optional) - target API level (default: 11).
#   ABI (optional)            - target ABI (default: arm64-v8a).
#   WOLFSSL_VERSION (optional)  - wolfSSL tag to fetch (default: 5.7.0-stable).
#   LIBSSH2_VERSION (optional)  - libssh2 version to fetch (default: 1.11.1).
#   JOBS (optional)             - parallel build job count (default: number of CPU cores).
#   OUTPUT_ROOT (optional)      - installation base directory (default: repo root).
#
# Usage:
#   ./scripts/build_third_party.sh [--abi arm64-v8a] [--clean]
#
# Artifacts will be installed to:
#   <OUTPUT_ROOT>/wolfssl-out/<abi>
#   <OUTPUT_ROOT>/libssh2-out/<abi>

usage() {
  cat <<'USAGE'
Usage: build_third_party.sh [options]

Options:
  --abi <abi>        Target ABI (default: arm64-v8a)
  --clean            Remove cached sources and build directories before starting
  -h, --help         Show this help message

Environment:
  OHOS_NDK_HOME      Required. HarmonyOS Native SDK root containing build/cmake/ohos.toolchain.cmake
  OHOS_API_LEVEL     Optional. Target API level (default: 11)
  WOLFSSL_VERSION    Optional. Defaults to 5.7.0-stable
  LIBSSH2_VERSION    Optional. Defaults to 1.11.1
  JOBS               Optional. Parallel build job count (defaults to number of cores)
  OUTPUT_ROOT        Optional. Output prefix (defaults to repository root)
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' not found" >&2
    exit 1
  fi
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

ABI="${ABI:-arm64-v8a}"
CLEAN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --abi)
      if [[ $# -lt 2 ]]; then
        echo "Error: --abi requires an argument" >&2
        exit 1
      fi
      ABI="$2"
      shift 2
      ;;
    --clean)
      CLEAN="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${OHOS_NDK_HOME:-}" ]]; then
  echo "Error: OHOS_NDK_HOME is not set" >&2
  exit 1
fi

TOOLCHAIN_FILE="${OHOS_NDK_HOME%/}/build/cmake/ohos.toolchain.cmake"
if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
  echo "Error: could not find HarmonyOS toolchain file at '$TOOLCHAIN_FILE'" >&2
  exit 1
fi

SYSROOT="${OHOS_NDK_HOME%/}/native/sysroot"
if [[ ! -d "$SYSROOT" ]]; then
  echo "Error: could not find HarmonyOS sysroot at '$SYSROOT'" >&2
  exit 1
fi

OHOS_API_LEVEL="${OHOS_API_LEVEL:-11}"
WOLFSSL_VERSION="${WOLFSSL_VERSION:-5.7.0-stable}"
LIBSSH2_VERSION="${LIBSSH2_VERSION:-1.11.1}"

require_cmd cmake
require_cmd curl
require_cmd tar

detect_jobs() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif [[ "$(uname -s 2>/dev/null)" == "Darwin" ]] && command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu
  else
    echo 4
  fi
}

JOBS="${JOBS:-$(detect_jobs)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$REPO_ROOT}"

THIRD_PARTY_DIR="${REPO_ROOT}/third_party"
SRC_DIR="${THIRD_PARTY_DIR}/src"
BUILD_DIR="${THIRD_PARTY_DIR}/build"
DOWNLOAD_DIR="${THIRD_PARTY_DIR}/downloads"
WOLFSSL_OUT="${OUTPUT_ROOT%/}/wolfssl-out/${ABI}"
LIBSSH2_OUT="${OUTPUT_ROOT%/}/libssh2-out/${ABI}"

if [[ "$CLEAN" == "true" ]]; then
  rm -rf "$SRC_DIR" "$BUILD_DIR" "$DOWNLOAD_DIR"
fi

mkdir -p "$SRC_DIR" "$BUILD_DIR" "$DOWNLOAD_DIR" "$WOLFSSL_OUT" "$LIBSSH2_OUT"

CMAKE_GENERATOR=""
if command -v ninja >/dev/null 2>&1; then
  CMAKE_GENERATOR="-G Ninja"
fi

fetch_source() {
  local url="$1"
  local archive_path="$2"

  if [[ -f "$archive_path" ]]; then
    echo "Using cached archive $(basename "$archive_path")"
    return
  fi

  echo "Downloading $(basename "$archive_path")"
  curl -L "$url" -o "$archive_path"
}

extract_source() {
  local archive_path="$1"
  local destination="$2"

  local root_dir
  root_dir=$(tar -tf "$archive_path" | head -1 | cut -f1 -d"/")
  local src_path="$destination/$root_dir"

  if [[ ! -d "$src_path" ]]; then
    echo "Extracting $(basename "$archive_path")"
    tar -xf "$archive_path" -C "$destination"
  fi

  echo "$src_path"
}

case "$ABI" in
  arm64-v8a)
    TARGET_TRIPLE="aarch64-linux-ohos"
    CMAKE_PROCESSOR="aarch64"
    ;;
  armeabi-v7a)
    TARGET_TRIPLE="armv7-unknown-linux-ohos"
    CMAKE_PROCESSOR="armv7"
    ;;
  x86_64)
    TARGET_TRIPLE="x86_64-linux-ohos"
    CMAKE_PROCESSOR="x86_64"
    ;;
  *)
    echo "Error: unsupported ABI '$ABI'" >&2
    exit 1
    ;;
esac

LLVM_BIN="${OHOS_NDK_HOME%/}/native/llvm/bin"
CLANG_BIN="${LLVM_BIN}/clang"
AR_BIN="${LLVM_BIN}/llvm-ar"
RANLIB_BIN="${LLVM_BIN}/llvm-ranlib"

for tool in "$CLANG_BIN" "$AR_BIN" "$RANLIB_BIN"; do
  if [[ ! -x "$tool" ]]; then
    echo "Error: required tool '$tool' not found" >&2
    exit 1
  fi
done

WOLFSSL_ARCHIVE="$DOWNLOAD_DIR/wolfssl-${WOLFSSL_VERSION}.tar.gz"
LIBSSH2_ARCHIVE="$DOWNLOAD_DIR/libssh2-${LIBSSH2_VERSION}.tar.gz"

fetch_source "https://github.com/wolfSSL/wolfssl/archive/refs/tags/v${WOLFSSL_VERSION}.tar.gz" "$WOLFSSL_ARCHIVE"
fetch_source "https://www.libssh2.org/download/libssh2-${LIBSSH2_VERSION}.tar.gz" "$LIBSSH2_ARCHIVE"

WOLFSSL_SRC=$(extract_source "$WOLFSSL_ARCHIVE" "$SRC_DIR")
LIBSSH2_SRC=$(extract_source "$LIBSSH2_ARCHIVE" "$SRC_DIR")

cmake_common_args=(
  $CMAKE_GENERATOR
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_C_COMPILER="$CLANG_BIN"
  -DCMAKE_ASM_COMPILER="$CLANG_BIN"
  -DCMAKE_AR="$AR_BIN"
  -DCMAKE_RANLIB="$RANLIB_BIN"
  -DCMAKE_SYSROOT="$SYSROOT"
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
  -DCMAKE_SYSTEM_NAME=OhOS
  -DCMAKE_SYSTEM_PROCESSOR="$CMAKE_PROCESSOR"
  "-DCMAKE_C_FLAGS=--target=${TARGET_TRIPLE} -fPIC"
  "-DCMAKE_EXE_LINKER_FLAGS=--target=${TARGET_TRIPLE}"
)

build_wolfssl() {
  local build_dir="${BUILD_DIR}/wolfssl-${ABI}"
  rm -rf "$build_dir"
  cmake "${cmake_common_args[@]}" \
    -DWOLFSSL_EXAMPLES=OFF \
    -DWOLFSSL_TESTS=OFF \
    -DWOLFSSL_CRYPT_TESTS=OFF \
    -DWOLFSSL_OPENSSLEXTRA=ON \
    -DWOLFSSL_OPENSSLALL=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX="$WOLFSSL_OUT" \
    -S "$WOLFSSL_SRC" \
    -B "$build_dir"

  cmake --build "$build_dir" --target install -- -j"$JOBS"
}

build_libssh2() {
  local build_dir="${BUILD_DIR}/libssh2-${ABI}"
  rm -rf "$build_dir"
  cmake "${cmake_common_args[@]}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTING=OFF \
    -DCRYPTO_BACKEND=wolfSSL \
    -DWOLFSSL_INCLUDE_DIR="$WOLFSSL_OUT/include" \
    -DWOLFSSL_LIBRARY="$WOLFSSL_OUT/lib/libwolfssl.a" \
    -DCMAKE_INSTALL_PREFIX="$LIBSSH2_OUT" \
    -S "$LIBSSH2_SRC" \
    -B "$build_dir"

  cmake --build "$build_dir" --target install -- -j"$JOBS"
}

build_wolfssl
build_libssh2

echo
echo "Success!"
echo "wolfSSL installed to: ${WOLFSSL_OUT}"
echo "libssh2 installed to: ${LIBSSH2_OUT}"
