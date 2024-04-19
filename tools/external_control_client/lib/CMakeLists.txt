cmake_minimum_required(VERSION 3.0)

project(librenode_api)

file (GLOB SOURCES CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_LIST_DIR}/*.c
    )

add_library(renode_api STATIC ${SOURCES})

target_compile_options(renode_api
    PRIVATE
    -Wall
    -Werror
    -Wextra
    -fno-strict-aliasing
    )

include_directories(
    ${CMAKE_CURRENT_LIST_DIR}/../include
    )
