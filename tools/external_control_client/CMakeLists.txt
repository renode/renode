cmake_minimum_required(VERSION 3.0)

project(renode_api_client)

set(APP_COMPILE_FLAGS
    -Wall
    -Werror
    -Wextra
    CACHE STRING "Compile flags for the Renode API client application")

set(APP_NAME renode_api_client CACHE STRING "Name of the Renode API client application")
set(APP_SOURCES_DIR "" CACHE PATH "Path to the directory with Renode API client application sources")

if(NOT APP_NAME)
    message(FATAL_ERROR "Missing APP_NAME; use ccmake, cmake-gui or -D switch to set it")
endif()

if(NOT APP_SOURCES_DIR)
    message(FATAL_ERROR "Missing APP_SOURCES_DIR; use ccmake, cmake-gui or -D switch to set it")
endif()

set(LIB_DIR ${CMAKE_CURRENT_LIST_DIR}/lib)
include(${LIB_DIR}/CMakeLists.txt)
include(${APP_SOURCES_DIR}/CMakeLists.txt OPTIONAL)

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS ${APP_SOURCES_DIR}/*.c)
add_executable(${APP_NAME} ${SOURCES})

target_compile_options(${APP_NAME} PRIVATE ${APP_COMPILE_FLAGS})

target_link_libraries(${APP_NAME} PRIVATE renode_api)
