cmake_minimum_required(VERSION 3.8)

project(
    RenodeSystemCBridge,
    VERSION 0.1
    DESCRIPTION "SystemC module for interfacing with Renode"
    LANGUAGES CXX)

file(GLOB_RECURSE SOURCES_SOCKET_CPP lib/socket-cpp/*.cpp)
add_library(socket_cpp ${SOURCES_SOCKET_CPP})

set(SOURCES_RENODE_BRIDGE
    src/renode_bridge.cpp
)
add_library(renode_bridge ${SOURCES_RENODE_BRIDGE})
target_include_directories(renode_bridge PUBLIC
    include)
target_include_directories(renode_bridge PRIVATE
    lib
    ${INCLUDE_DIRS})

target_link_libraries(renode_bridge socket_cpp)
