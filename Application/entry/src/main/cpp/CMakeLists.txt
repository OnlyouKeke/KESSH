cmake_minimum_required(VERSION 3.5.0)
project(kessh)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH})

# Native dependency roots default to repository-local outputs created by scripts/build_third_party.sh.
# Override LIBSSH2_ROOT or WOLFSSL_ROOT from externalNativeOptions.arguments when using another output root.
set(KESSH_REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../..")
if(NOT DEFINED LIBSSH2_ROOT OR "${LIBSSH2_ROOT}" STREQUAL "")
    set(LIBSSH2_ROOT "${KESSH_REPO_ROOT}/libssh2-out/${CMAKE_OHOS_ARCH_ABI}")
endif()
if(NOT DEFINED WOLFSSL_ROOT OR "${WOLFSSL_ROOT}" STREQUAL "")
    set(WOLFSSL_ROOT "${KESSH_REPO_ROOT}/wolfssl-out/${CMAKE_OHOS_ARCH_ABI}")
endif()

get_filename_component(LIBSSH2_ROOT "${LIBSSH2_ROOT}" ABSOLUTE)
get_filename_component(WOLFSSL_ROOT "${WOLFSSL_ROOT}" ABSOLUTE)

set(LIBSSH2_LIBRARY "${LIBSSH2_ROOT}/lib/libssh2.a")
set(WOLFSSL_LIBRARY "${WOLFSSL_ROOT}/lib/libwolfssl.a")

# Add include directories
include_directories("${LIBSSH2_ROOT}/include")
include_directories("${WOLFSSL_ROOT}/include")

# Import prebuilt libssh2
if(EXISTS "${LIBSSH2_LIBRARY}")
    add_library(ssh2 STATIC IMPORTED)
    set_target_properties(ssh2 PROPERTIES IMPORTED_LOCATION "${LIBSSH2_LIBRARY}")
    message(STATUS "Found libssh2 static library: ${LIBSSH2_LIBRARY}")
else()
    message(FATAL_ERROR "libssh2 library not found at ${LIBSSH2_LIBRARY}. Run scripts/build_third_party.sh --abi ${CMAKE_OHOS_ARCH_ABI}, or pass -DLIBSSH2_ROOT=<path> when using a custom OUTPUT_ROOT.")
endif()

# Import prebuilt wolfssl
if(EXISTS "${WOLFSSL_LIBRARY}")
    add_library(wolfssl STATIC IMPORTED)
    set_target_properties(wolfssl PROPERTIES IMPORTED_LOCATION "${WOLFSSL_LIBRARY}")
    message(STATUS "Found wolfssl static library: ${WOLFSSL_LIBRARY}")
else()
    message(FATAL_ERROR "wolfssl library not found at ${WOLFSSL_LIBRARY}. Run scripts/build_third_party.sh --abi ${CMAKE_OHOS_ARCH_ABI}, or pass -DWOLFSSL_ROOT=<path> when using a custom OUTPUT_ROOT.")
endif()

add_library(kessh SHARED kessh.cpp)

# Link libraries - IMPORTANT: Order matters!
# wolfssl must come AFTER ssh2 because ssh2 depends on it
target_link_libraries(kessh PUBLIC 
    libace_napi.z.so
    libhilog_ndk.z.so
    ssh2
    wolfssl
    -Wl,--whole-archive
    -Wl,--no-whole-archive
)