# Copyright (C) The libssh2 project and its contributors.
# SPDX-License-Identifier: BSD-3-Clause

include(CMakeFindDependencyMacro)
list(PREPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})

if("wolfSSL" STREQUAL "OpenSSL")
  find_dependency(OpenSSL)
elseif("wolfSSL" STREQUAL "wolfSSL")
  find_dependency(WolfSSL)
elseif("wolfSSL" STREQUAL "Libgcrypt")
  find_dependency(Libgcrypt)
elseif("wolfSSL" STREQUAL "mbedTLS")
  find_dependency(MbedTLS)
endif()

if(FALSE)
  find_dependency(ZLIB)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/libssh2-targets.cmake")

# Alias for either shared or static library
if(NOT TARGET libssh2::libssh2)
  add_library(libssh2::libssh2 ALIAS libssh2::libssh2_static)
endif()

# Compatibility alias
if(NOT TARGET Libssh2::libssh2)
  add_library(Libssh2::libssh2 ALIAS libssh2::libssh2_static)
endif()
