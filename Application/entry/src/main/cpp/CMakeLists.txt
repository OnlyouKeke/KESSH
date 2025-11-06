cmake_minimum_required(VERSION 3.10)
project(sshnative)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# You must provide libssh2 for your target (e.g., prebuilt or fetched in your toolchain)
# Prefer per-ABI variables so one build can cover multiple ABIs:
#   LIBSSH2_INCLUDE_DIR_ARM64, LIBSSH2_LIBRARY_ARM64
#   LIBSSH2_INCLUDE_DIR_ARMV7, LIBSSH2_LIBRARY_ARMV7
#   LIBSSH2_INCLUDE_DIR_X64,   LIBSSH2_LIBRARY_X64 (if targeting x86_64)
# Fallback to single-ABI variables: LIBSSH2_INCLUDE_DIR, LIBSSH2_LIBRARY

set(_ARCH "")
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
  set(_ARCH "arm64-v8a")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
  set(_ARCH "armeabi-v7a")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
  set(_ARCH "x86_64")
endif()

set(_INC "")
set(_LIBS "")

if(DEFINED LIBSSH2_INCLUDE_DIR AND DEFINED LIBSSH2_LIBRARY)
  set(_INC  ${LIBSSH2_INCLUDE_DIR})
  set(_LIBS ${LIBSSH2_LIBRARY})
else()
  if(_ARCH STREQUAL "arm64-v8a")
    if(DEFINED LIBSSH2_INCLUDE_DIR_ARM64)
      set(_INC ${LIBSSH2_INCLUDE_DIR_ARM64})
    endif()
    if(DEFINED LIBSSH2_LIBRARY_ARM64)
      set(_LIBS ${LIBSSH2_LIBRARY_ARM64})
    endif()
  elseif(_ARCH STREQUAL "armeabi-v7a")
    if(DEFINED LIBSSH2_INCLUDE_DIR_ARMV7)
      set(_INC ${LIBSSH2_INCLUDE_DIR_ARMV7})
    endif()
    if(DEFINED LIBSSH2_LIBRARY_ARMV7)
      set(_LIBS ${LIBSSH2_LIBRARY_ARMV7})
    endif()
  elseif(_ARCH STREQUAL "x86_64")
    if(DEFINED LIBSSH2_INCLUDE_DIR_X64)
      set(_INC ${LIBSSH2_INCLUDE_DIR_X64})
    endif()
    if(DEFINED LIBSSH2_LIBRARY_X64)
      set(_LIBS ${LIBSSH2_LIBRARY_X64})
    endif()
  endif()
endif()

if(NOT _INC OR NOT _LIBS)
  message(FATAL_ERROR "libssh2 include/libs not configured for ${_ARCH}. Define LIBSSH2_INCLUDE_DIR/Library or per-ABI variants.")
endif()

include_directories(${_INC} ${CMAKE_CURRENT_SOURCE_DIR}/include)

add_library(sshnative SHARED
  src/sshnative.cpp
)

set(_SYSROOT_LIB_SUBDIR "")
if(CMAKE_SYSROOT)
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    set(_SYSROOT_LIB_SUBDIR "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-ohos")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
    set(_SYSROOT_LIB_SUBDIR "${CMAKE_SYSROOT}/usr/lib/arm-linux-ohos")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
    set(_SYSROOT_LIB_SUBDIR "${CMAKE_SYSROOT}/usr/lib/x86_64-linux-ohos")
  endif()
endif()

find_library(ACE_NAPI_LIB
  NAMES ace_napi.z
  HINTS
    ${_SYSROOT_LIB_SUBDIR}
    "${CMAKE_SYSROOT}/usr/lib"
)

if(NOT ACE_NAPI_LIB)
  message(FATAL_ERROR "ace_napi.z not found; ensure HarmonyOS NAPI runtime is installed in the sysroot.")
endif()

set(_EXTRA_SYS_LIBS dl pthread)

target_link_libraries(sshnative ${_LIBS} ${ACE_NAPI_LIB} ${_EXTRA_SYS_LIBS})

target_compile_definitions(sshnative PRIVATE NAPI_VERSION=8)

# HarmonyOS N-API modules are typically packaged as lib<name>.z.so
set_target_properties(sshnative PROPERTIES OUTPUT_NAME "sshnative.z")
