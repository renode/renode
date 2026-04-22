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

add_library(renode_bridge_native OBJECT src/renode_bridge_native.cpp)

set(EXPORT_DEF "")
if(WIN32 OR CYGWIN)
    set(EXPORT_DEF "__declspec(dllexport)")
endif()

# RENODE_BRIDGE_API definition will be used in `renode_imports.h`
target_compile_definitions(renode_bridge_native PUBLIC
    RENODE_BRIDGE_API=${EXPORT_DEF}
)

target_include_directories(renode_bridge_native PUBLIC include)
# The path of the `renode_imports.h` header differs depending on whether Renode
# is provided in source or package distribution. Cover both of these cases here
target_include_directories(renode_bridge_native PUBLIC
    ../../../Infrastructure/src/Emulator/Cores/renode/include
    ../IntegrationLibrary/src
)

target_link_libraries(renode_bridge_native systemc)
set_target_properties(renode_bridge_native PROPERTIES POSITION_INDEPENDENT_CODE ON)

if (MSVC)
    target_compile_options(renode_bridge PRIVATE /vmg)
    target_compile_options(renode_bridge_native PRIVATE /vmg /Zc:preprocessor)
endif()
