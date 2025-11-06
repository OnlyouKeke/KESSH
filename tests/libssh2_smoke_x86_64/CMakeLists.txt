cmake_minimum_required(VERSION 3.10)
project(libssh2_smoke C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_executable(libssh2_smoke test_libssh2.c)

include_directories(E:/KESSH/libssh2-out/x86_64/include)

target_link_libraries(libssh2_smoke PRIVATE
  E:/KESSH/libssh2-out/x86_64/lib/libssh2.a
  E:/KESSH/wolfssl-out/x86_64/lib/libwolfssl.a
  dl
  pthread
)
