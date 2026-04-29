# Input variables:
#  USER_RENODE_DIR - absolute path to the Renode package or Renode source root
#  RENODE_CFG      - build configuration of librenode (defaults to Release)
#  RENODE_RID      - RID of platform of librenode (defaults to target machine's RID)
#
# Environment variables:
#  RENODE_ROOT     - fallback for renode_root if USER_RENODE_DIR is not set
#
# Supported file layouts:
#  Package:          <renode_root>/bin/platform-lib/<RID>/librenode.so                (extracted package)
#  Portable package: <renode_root>/platform-lib/<RID>/librenode.so
#  Source tree:      <renode_root>/output/bin/<CFG>/platform-lib/<RID>/librenode.so   (after ./build.sh --shared)

if(DEFINED USER_RENODE_DIR)
    set(renode_root "${USER_RENODE_DIR}")
elseif(DEFINED ENV{RENODE_ROOT})
    set(renode_root "$ENV{RENODE_ROOT}")
else()
    set(_renode_root_candidate "${CMAKE_CURRENT_LIST_DIR}/../../..")
    get_filename_component(_renode_root_candidate "${_renode_root_candidate}" ABSOLUTE)
    set(_renode_root_marker "${_renode_root_candidate}/.renode-root")
    if(EXISTS "${_renode_root_marker}")
        file(READ "${_renode_root_marker}" _renode_root_marker_content)
        string(STRIP "${_renode_root_marker_content}" _renode_root_marker_content)
        if(_renode_root_marker_content STREQUAL "5344ec2a-1539-4017-9ae5-a27c279bd454")
            set(renode_root "${_renode_root_candidate}")
        endif()
    endif()
    unset(_renode_root_candidate)
    unset(_renode_root_marker)
    unset(_renode_root_marker_content)
endif()

if(NOT DEFINED renode_root)
    message(FATAL_ERROR "Please set the CMake's USER_RENODE_DIR variable to an absolute path to "
        "the Renode package or source directory.\nPass the "
        "'-DUSER_RENODE_DIR=<ABSOLUTE_PATH>' switch if you configure with the 'cmake' command. "
        "Optionally, consider using 'ccmake' or 'cmake-gui' which makes it easier.")
endif()

# The root can be defined but not exist (for example if the user made a typo while manually specifying it)
if(NOT EXISTS "${renode_root}")
    message(FATAL_ERROR "Path doesn't exist: ${renode_root}!")
endif()

if(NOT DEFINED RENODE_CFG)
    set(RENODE_CFG Release)
endif()

if(NOT DEFINED RENODE_RID)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(RENODE_RID "linux")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        set(RENODE_RID "osx")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
        set(RENODE_RID "win")
    else()
        message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
    endif()

    if(NOT DEFINED ARCH)
        if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "(AMD64|amd64|86)")
            set (ARCH "x64" CACHE STRING "Host architecture")
        elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "(aarch64|arm64)")
            set (ARCH "arm64" CACHE STRING "Host architecture")
        # Has to come last to not match arm macs arm64, while still matching a cpu like armv7l
        elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "(arm)")
            set (ARCH "arm" CACHE STRING "Host architecture")
        else()
            message(FATAL_ERROR "CMAKE_SYSTEM_PROCESSOR '${CMAKE_SYSTEM_PROCESSOR}' doesn't seem to be supported. Supported host architectures are: 'arm', 'i386', 'aarch64/arm64'. Please set 'HOST_ARCH' manually.")
        endif()
    endif()

    set(RENODE_RID "${RENODE_RID}-${ARCH}")
endif()

set(renode_platformlib_suffix "platform-lib/${RENODE_RID}")

# Search package layouts (installed package bin/, portable root) then source tree layout (output/bin/<CFG>/)
find_library(LIBRENODE_LIBRARY
    NAMES renode
    PATHS
        "${renode_root}/bin/${renode_platformlib_suffix}"
        "${renode_root}/${renode_platformlib_suffix}"
        "${renode_root}/output/bin/${RENODE_CFG}/${renode_platformlib_suffix}"
    NO_DEFAULT_PATH
)

if(LIBRENODE_LIBRARY)
    get_filename_component(librenode_dir "${LIBRENODE_LIBRARY}" DIRECTORY)
endif()

find_path(LIBRENODE_INCLUDE_DIR
    NAMES librenode.h
    PATHS "${librenode_dir}"
    NO_DEFAULT_PATH
)

if(NOT LIBRENODE_LIBRARY OR NOT LIBRENODE_INCLUDE_DIR)
    message(FATAL_ERROR "librenode not found in ${renode_root}.\n"
        "Build Renode with the --shared flag first: ./build.sh --shared")
endif()

message(STATUS "Found librenode: ${LIBRENODE_LIBRARY}")

if(NOT TARGET renode::renode)
    enable_language(CXX)
    add_library(renode::renode SHARED IMPORTED)
    set_target_properties(renode::renode PROPERTIES
        IMPORTED_LOCATION "${LIBRENODE_LIBRARY}"
        IMPORTED_NO_SONAME TRUE  # don't link with the absolute library path, just -lrenode
        INTERFACE_INCLUDE_DIRECTORIES "${LIBRENODE_INCLUDE_DIR}"
        INTERFACE_LINK_DIRECTORIES "${librenode_dir}"
        INTERFACE_LINK_LIBRARIES "${CMAKE_CXX_IMPLICIT_LINK_LIBRARIES}"  # link stdc++ / c++
    )
endif()

if(NOT TARGET renode)
    add_library(renode ALIAS renode::renode)
endif()

unset(renode_root)
unset(librenode_dir)
