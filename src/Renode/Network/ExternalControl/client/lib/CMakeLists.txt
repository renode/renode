cmake_minimum_required(VERSION 3.0)

project(librenode_api)

file (GLOB SOURCES
    ${CMAKE_CURRENT_LIST_DIR}/*.c
    )

add_library(renode_api STATIC ${SOURCES})

target_compile_options(renode_api
    PRIVATE
    -Wall
    -Werror
    -Wextra
    )

include_directories(
    ${CMAKE_CURRENT_LIST_DIR}/../include
    )
