cmake_minimum_required(VERSION 3.12)
project(librenode_example C)

set(ni_root ${CMAKE_CURRENT_LIST_DIR}/..)

include(${ni_root}/cmake/renode.cmake)
link_libraries(renode::renode pthread)

add_executable(librenode_example monitor.c)
add_executable(uart_example uart.c)

set_target_properties(librenode_example PROPERTIES
    BUILD_RPATH_USE_ORIGIN TRUE
    INSTALL_RPATH "$ORIGIN"
)
