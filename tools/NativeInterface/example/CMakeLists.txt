cmake_minimum_required(VERSION 3.12)
project(librenode_example C)

set(ni_root ${CMAKE_CURRENT_LIST_DIR}/..)

include(${ni_root}/cmake/renode.cmake)

add_executable(librenode_example main.c)
target_link_libraries(librenode_example PRIVATE renode::renode pthread)

set_target_properties(librenode_example PROPERTIES
    BUILD_RPATH_USE_ORIGIN TRUE
    INSTALL_RPATH "$ORIGIN"
)
