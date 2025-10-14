cmake_minimum_required(VERSION 3.10)
project(sshnative)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

function(normalize_path OUTPUT INPUT)
  if(INPUT)
    file(TO_CMAKE_PATH "${INPUT}" _tmp)
    set(${OUTPUT} "${_tmp}" PARENT_SCOPE)
  else()
    set(${OUTPUT} "" PARENT_SCOPE)
  endif()
endfunction()

set(_ARCH "")
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
  set(_ARCH "arm64-v8a")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
  set(_ARCH "x86_64")
endif()

set(_LIBSSH_INC "")
set(_LIBSSH_LIB "")
set(_OPENSSL_INC "")
set(_OPENSSL_LIBS "")

if(DEFINED LIBSSH_INCLUDE_DIR AND DEFINED LIBSSH_LIBRARY)
  normalize_path(_LIBSSH_INC "${LIBSSH_INCLUDE_DIR}")
  set(_LIBSSH_LIB "${LIBSSH_LIBRARY}")
else()
  if(_ARCH STREQUAL "arm64-v8a")
    normalize_path(_LIBSSH_INC "${LIBSSH_INCLUDE_DIR_ARM64}")
    set(_LIBSSH_LIB "${LIBSSH_LIBRARY_ARM64}")
  elseif(_ARCH STREQUAL "x86_64")
    normalize_path(_LIBSSH_INC "${LIBSSH_INCLUDE_DIR_X64}")
    set(_LIBSSH_LIB "${LIBSSH_LIBRARY_X64}")
  endif()
endif()

if(NOT _LIBSSH_INC OR NOT _LIBSSH_LIB)
  message(FATAL_ERROR "libssh include/library paths not configured for ${_ARCH}. Define LIBSSH_INCLUDE_DIR/LIBSSH_LIBRARY or per-ABI variants.")
endif()

if(DEFINED OPENSSL_INCLUDE_DIR AND DEFINED OPENSSL_LIBS)
  normalize_path(_OPENSSL_INC "${OPENSSL_INCLUDE_DIR}")
  set(_OPENSSL_LIBS "${OPENSSL_LIBS}")
else()
  if(_ARCH STREQUAL "arm64-v8a")
    normalize_path(_OPENSSL_INC "${OPENSSL_INCLUDE_DIR_ARM64}")
    set(_OPENSSL_LIBS "${OPENSSL_LIBS_ARM64}")
  elseif(_ARCH STREQUAL "x86_64")
    normalize_path(_OPENSSL_INC "${OPENSSL_INCLUDE_DIR_X64}")
    set(_OPENSSL_LIBS "${OPENSSL_LIBS_X64}")
  endif()
endif()

if(NOT _OPENSSL_INC OR NOT _OPENSSL_LIBS)
  message(FATAL_ERROR "OpenSSL include/library paths not configured for ${_ARCH}. Define OPENSSL_INCLUDE_DIR/OPENSSL_LIBS or per-ABI variants.")
endif()

include_directories(${_LIBSSH_INC} ${_OPENSSL_INC} ${CMAKE_CURRENT_SOURCE_DIR}/include)

add_library(sshnative SHARED
  src/sshnative.cpp
)

# Link against libssh and the provided OpenSSL libraries
separate_arguments(_OPENSSL_LIBS)
target_link_libraries(sshnative ${_LIBSSH_LIB} ${_OPENSSL_LIBS})

target_compile_definitions(sshnative PRIVATE NAPI_VERSION=8)

# HarmonyOS N-API modules are typically packaged as lib<name>.z.so
set_target_properties(sshnative PROPERTIES OUTPUT_NAME "sshnative.z")
