cmake_minimum_required(VERSION 3.18.4)

project(
    RenodeSystemCBridge,
    VERSION 0.1
    DESCRIPTION "SystemC module for interfacing with Renode"
    LANGUAGES CXX)

include(GenerateExportHeader)

file(GLOB_RECURSE SOURCES_SOCKET_CPP lib/socket-cpp/*.cpp)
add_library(socket_cpp ${SOURCES_SOCKET_CPP})

add_library(renode_bridge src/renode_bridge.cpp)
target_include_directories(renode_bridge PUBLIC include)
target_include_directories(renode_bridge PRIVATE lib)
target_link_libraries(renode_bridge socket_cpp systemc)

add_library(renode_bridge_native OBJECT src/renode_bridge_native.cpp)

set_target_properties(renode_bridge_native PROPERTIES DEFINE_SYMBOL RBN_ALWAYS_EXPORT)
target_compile_definitions(renode_bridge_native PUBLIC RBN_ALWAYS_EXPORT)
    generate_export_header(renode_bridge_native
    EXPORT_FILE_NAME export/renode_bridge_native_export.h
    EXPORT_MACRO_NAME RENODE_BRIDGE_API
)

target_include_directories(renode_bridge_native PUBLIC include "${CMAKE_CURRENT_BINARY_DIR}/export")

# The path of the `renode_imports.h` header differs depending on whether Renode
# is provided in source or package distribution. Cover both of these cases here
target_include_directories(renode_bridge_native PUBLIC ../../../Infrastructure/src/Emulator/Cores/renode/include)
target_include_directories(renode_bridge_native PUBLIC ../IntegrationLibrary/src)

target_link_libraries(renode_bridge_native systemc)
set_target_properties(renode_bridge_native PROPERTIES POSITION_INDEPENDENT_CODE ON)

if (MSVC)
    target_compile_options(renode_bridge PRIVATE /vmg)
    target_compile_options(renode_bridge_native PRIVATE /vmg /Zc:preprocessor)
endif()
