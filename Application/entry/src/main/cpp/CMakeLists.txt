cmake_minimum_required(VERSION 3.4.1)
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
add_library(ssh2 SHARED IMPORTED)
set_target_properties(ssh2 PROPERTIES IMPORTED_LOCATION ${LIBSSH2_ROOT}/lib/libssh2.so)

# Import prebuilt wolfssl
add_library(wolfssl SHARED IMPORTED)
set_target_properties(wolfssl PROPERTIES IMPORTED_LOCATION ${WOLFSSL_ROOT}/lib/libwolfssl.so)

add_library(kessh SHARED kessh.cpp)

target_link_libraries(kessh PUBLIC libace_napi.z.so ssh2 wolfssl)