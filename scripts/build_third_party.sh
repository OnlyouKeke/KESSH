#!/usr/bin/env bash
set -euo pipefail

# Builds OpenSSL and libssh for HarmonyOS using the NDK toolchain.
#
# Environment variables:
#   OHOS_NDK_HOME (required) - path to the HarmonyOS Native SDK.
#   OHOS_API_LEVEL (optional) - target API level (default: 11).
#   ABI (optional) - target ABI (default: arm64-v8a).
#   OPENSSL_VERSION (optional) - version of OpenSSL to fetch (default: 3.2.1).
#   LIBSSH_VERSION (optional) - version of libssh to fetch (default: 0.10.6).
#   JOBS (optional) - parallel build job count (default: number of CPU cores).
#   OUTPUT_ROOT (optional) - base directory for installation results (default: repo root).
#
# Usage:
#   ./scripts/build_third_party.sh [--abi arm64-v8a] [--clean]
#
# Artifacts will be installed to:
#   <OUTPUT_ROOT>/openssl-out/<abi>
#   <OUTPUT_ROOT>/libssh-out/<abi>

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
  OPENSSL_VERSION    Optional. Defaults to 3.2.1
  LIBSSH_VERSION     Optional. Defaults to 0.10.6
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

TOOLCHAIN_CANDIDATES=(
  "${OHOS_NDK_HOME%/}/build/cmake/ohos.toolchain.cmake"
  "${OHOS_NDK_HOME%/}/native/build/cmake/ohos.toolchain.cmake"
)

TOOLCHAIN_FILE=""
for candidate in "${TOOLCHAIN_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TOOLCHAIN_FILE="$candidate"
    break
  fi
done

if [[ -z "$TOOLCHAIN_FILE" ]]; then
  echo "Error: could not locate HarmonyOS toolchain file. Checked:" >&2
  for candidate in "${TOOLCHAIN_CANDIDATES[@]}"; do
    echo "  - $candidate" >&2
  done
  exit 1
fi

SYSROOT_CANDIDATES=(
  "${OHOS_NDK_HOME%/}/native/sysroot"
  "${OHOS_NDK_HOME%/}/sysroot"
)

SYSROOT=""
for candidate in "${SYSROOT_CANDIDATES[@]}"; do
  if [[ -d "$candidate" ]]; then
    SYSROOT="$candidate"
    break
  fi
done

if [[ -z "$SYSROOT" ]]; then
  echo "Error: could not locate HarmonyOS sysroot. Checked:" >&2
  for candidate in "${SYSROOT_CANDIDATES[@]}"; do
    echo "  - $candidate" >&2
  done
  exit 1
fi

OHOS_API_LEVEL="${OHOS_API_LEVEL:-11}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.2.1}"
LIBSSH_VERSION="${LIBSSH_VERSION:-0.10.6}"

require_cmd cmake
require_cmd curl
require_cmd tar
require_cmd perl

# Determine default job count if not provided
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
OPENSSL_OUT="${OUTPUT_ROOT%/}/openssl-out/${ABI}"
LIBSSH_OUT="${OUTPUT_ROOT%/}/libssh-out/${ABI}"

if [[ "$CLEAN" == "true" ]]; then
  rm -rf "$SRC_DIR" "$BUILD_DIR" "$DOWNLOAD_DIR"
fi

mkdir -p "$SRC_DIR" "$BUILD_DIR" "$DOWNLOAD_DIR" "$OPENSSL_OUT" "$LIBSSH_OUT"

# Prefer Ninja when available
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
    OPENSSL_CONFIG="linux-generic64"
    ;;
  x86_64)
    TARGET_TRIPLE="x86_64-linux-ohos"
    OPENSSL_CONFIG="linux-x86_64"
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
NM_BIN="${LLVM_BIN}/llvm-nm"
STRIP_BIN="${LLVM_BIN}/llvm-strip"

for tool in "$CLANG_BIN" "$AR_BIN" "$RANLIB_BIN" "$NM_BIN" "$STRIP_BIN"; do
  if [[ ! -x "$tool" ]]; then
    echo "Error: required tool '$tool' not found" >&2
    exit 1
  fi
done

OPENSSL_ARCHIVE="$DOWNLOAD_DIR/openssl-${OPENSSL_VERSION}.tar.gz"
LIBSSH_ARCHIVE="$DOWNLOAD_DIR/libssh-${LIBSSH_VERSION}.tar.xz"

fetch_source "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" "$OPENSSL_ARCHIVE"
fetch_source "https://www.libssh.org/files/0.10/libssh-${LIBSSH_VERSION}.tar.xz" "$LIBSSH_ARCHIVE"

OPENSSL_SRC=$(extract_source "$OPENSSL_ARCHIVE" "$SRC_DIR")
LIBSSH_SRC=$(extract_source "$LIBSSH_ARCHIVE" "$SRC_DIR")

build_openssl() {
  local build_dir="${BUILD_DIR}/openssl-${ABI}"
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  pushd "$build_dir" >/dev/null

  local cc="${CLANG_BIN} --target=${TARGET_TRIPLE} --sysroot=${SYSROOT}"
  local cflags="-fPIC"
  local ldflags="--target=${TARGET_TRIPLE} --sysroot=${SYSROOT}"

  perl "${OPENSSL_SRC}/Configure" \
    ${OPENSSL_CONFIG} \
    no-shared \
    no-tests \
    --prefix="${OPENSSL_OUT}" \
    --openssldir="${OPENSSL_OUT}/ssl" \
    --libdir=lib \
    CC="${cc}" \
    AR="${AR_BIN}" \
    RANLIB="${RANLIB_BIN}" \
    NM="${NM_BIN}" \
    CFLAGS="${cflags}" \
    LDFLAGS="${ldflags}" >/dev/null

  make -j"${JOBS}" >/dev/null
  make install_sw >/dev/null

  popd >/dev/null
}

build_libssh() {
  local build_dir="${BUILD_DIR}/libssh-${ABI}"
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  pushd "$build_dir" >/dev/null

  cmake ${CMAKE_GENERATOR} \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    -DOHOS_ARCH="${ABI}" \
    -DOHOS_PLATFORM="${OHOS_API_LEVEL}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DWITH_EXAMPLES=OFF \
    -DWITH_TESTS=OFF \
    -DWITH_GSSAPI=OFF \
    -DOPENSSL_ROOT_DIR="${OPENSSL_OUT}" \
    -DOPENSSL_INCLUDE_DIR="${OPENSSL_OUT}/include" \
    -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_OUT}/lib/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="${OPENSSL_OUT}/lib/libssl.a" \
    -DCMAKE_INSTALL_PREFIX="${LIBSSH_OUT}" \
    "${LIBSSH_SRC}" >/dev/null

  cmake --build . --target install -- -j"${JOBS}" >/dev/null

  popd >/dev/null
}

build_openssl
build_libssh

echo "\nSuccess!"
echo "OpenSSL installed to: ${OPENSSL_OUT}"
echo "libssh installed to: ${LIBSSH_OUT}"
