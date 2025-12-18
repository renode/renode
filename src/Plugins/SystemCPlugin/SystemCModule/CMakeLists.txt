cmake_minimum_required(VERSION 3.18.4)

project(
    RenodeSystemCBridge,
    VERSION 0.1
    DESCRIPTION "SystemC module for interfacing with Renode"
    LANGUAGES CXX)

file(GLOB_RECURSE SOURCES_SOCKET_CPP lib/socket-cpp/*.cpp)
add_library(socket_cpp ${SOURCES_SOCKET_CPP})

add_library(renode_bridge src/renode_bridge.cpp)
target_include_directories(renode_bridge PUBLIC include)
target_include_directories(renode_bridge PRIVATE lib)
target_link_libraries(renode_bridge socket_cpp systemc)

add_library(renode_bridge_native src/renode_bridge_native.cpp)
target_include_directories(renode_bridge_native PUBLIC include)
target_link_libraries(renode_bridge_native systemc)
set_target_properties(renode_bridge_native PROPERTIES POSITION_INDEPENDENT_CODE ON)

if (MSVC)
    target_compile_options(renode_bridge PRIVATE /vmg)
    target_compile_options(renode_bridge_native PRIVATE /vmg)
endif()
