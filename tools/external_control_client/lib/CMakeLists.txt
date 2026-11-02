cmake_minimum_required(VERSION 3.10)

project(librenode_api)

# socket: connects to a Renode server over TCP
# in_process: connects to the Renode instance that runs in the same program through librenode
if(NOT DEFINED RENODE_API_TRANSPORT)
    set(RENODE_API_TRANSPORT socket)
endif()

if(RENODE_API_TRANSPORT STREQUAL "socket")
    set(transport_source connection.c)
elseif(RENODE_API_TRANSPORT STREQUAL "in_process")
    set(transport_source connection_in_process.c)
else()
    message(FATAL_ERROR "Unknown RENODE_API_TRANSPORT '${RENODE_API_TRANSPORT}', expected 'socket' or 'in_process'")
endif()

set(renode_api_sources
    ${CMAKE_CURRENT_LIST_DIR}/renode_api.c
    ${CMAKE_CURRENT_LIST_DIR}/${transport_source}
    )

# Builds a shared library that overrides the time functions of a process it is preloaded into
option(RENODE_API_TIME_OVERRIDE "Override time functions with Renode's virtual time" OFF)
if(RENODE_API_TIME_OVERRIDE)
    if(NOT RENODE_API_TRANSPORT STREQUAL "socket")
        message(FATAL_ERROR "RENODE_API_TIME_OVERRIDE requires the 'socket' transport")
    endif()
    # A sanitized library aborts when preloaded into a program that isn't sanitized itself
    if(RENODE_API_SANITIZERS)
        message(FATAL_ERROR "RENODE_API_TIME_OVERRIDE can't be used with RENODE_API_SANITIZERS")
    endif()
    set(RENODE_API_SANITIZERS OFF)
    add_library(renode_api SHARED ${renode_api_sources} ${CMAKE_CURRENT_LIST_DIR}/time_override.c)
else()
    add_library(renode_api STATIC ${renode_api_sources})
endif()

target_compile_options(renode_api
    PRIVATE
    -Wall
    -Werror
    -Wextra
    -fno-strict-aliasing
    )
set_property(TARGET renode_api PROPERTY POSITION_INDEPENDENT_CODE ON)

find_package(Threads REQUIRED)
target_link_libraries(renode_api PRIVATE Threads::Threads)

if(RENODE_API_TRANSPORT STREQUAL "in_process")
    if(NOT TARGET renode::renode)
        include(${CMAKE_CURRENT_LIST_DIR}/../../NativeInterface/cmake/renode.cmake)
    endif()
    target_compile_definitions(renode_api PRIVATE RENODE_API_TRANSPORT_IN_PROCESS)
    target_link_libraries(renode_api PUBLIC renode::renode)
endif()

target_include_directories(
    renode_api
    PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../include
    )

include(${CMAKE_CURRENT_LIST_DIR}/RenodeAPISanitizers.cmake)
renode_api_add_sanitizers_flags(renode_api)
