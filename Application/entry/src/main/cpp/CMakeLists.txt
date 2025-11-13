cmake_minimum_required(VERSION 3.5.0)
project(kessh)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH})

# Set paths to prebuilt libraries
set(LIBSSH2_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../libssh2-out/${CMAKE_OHOS_ARCH_ABI}")
set(WOLFSSL_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../wolfssl-out/${CMAKE_OHOS_ARCH_ABI}")

# Add include directories
include_directories(${LIBSSH2_ROOT}/include)
include_directories(${WOLFSSL_ROOT}/include)

# Import prebuilt libssh2
if(EXISTS "${LIBSSH2_ROOT}/lib/libssh2.a")
    add_library(ssh2 STATIC IMPORTED)
    set_target_properties(ssh2 PROPERTIES IMPORTED_LOCATION ${LIBSSH2_ROOT}/lib/libssh2.a)
    message(STATUS "Found libssh2 static library")
else()
    message(FATAL_ERROR "libssh2 library not found at ${LIBSSH2_ROOT}/lib/libssh2.a")
endif()

# Import prebuilt wolfssl
if(EXISTS "${WOLFSSL_ROOT}/lib/libwolfssl.a")
    add_library(wolfssl STATIC IMPORTED)
    set_target_properties(wolfssl PROPERTIES IMPORTED_LOCATION ${WOLFSSL_ROOT}/lib/libwolfssl.a)
    message(STATUS "Found wolfssl static library")
else()
    message(FATAL_ERROR "wolfssl library not found at ${WOLFSSL_ROOT}/lib/libwolfssl.a")
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