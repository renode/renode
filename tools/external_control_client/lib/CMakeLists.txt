cmake_minimum_required(VERSION 3.10)

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
set_property(TARGET renode_api PROPERTY POSITION_INDEPENDENT_CODE ON)

find_package(Threads REQUIRED)
target_link_libraries(renode_api PRIVATE Threads::Threads)

target_include_directories(
    renode_api
    PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../include
    )

include(${CMAKE_CURRENT_LIST_DIR}/RenodeAPISanitizers.cmake)
renode_api_add_sanitizers_flags(renode_api)
