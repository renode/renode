cmake_minimum_required(VERSION 3.20)

project(
  RenodeSystemCNative,
  VERSION 0.1
  DESCRIPTION "SystemC module for interfacting with Renode"
  LANGUAGES CXX
)

add_library(renode_bridge_native src/renode_bridge_native.cpp)
target_include_directories(renode_bridge_native PUBLIC include)
target_link_libraries(renode_bridge_native systemc)

set_target_properties(renode_bridge_native PROPERTIES POSITION_INDEPENDENT_CODE ON)
