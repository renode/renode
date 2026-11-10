cmake_minimum_required(VERSION 3.12)
project(librenode_example C CXX)

set(ni_root ${CMAKE_CURRENT_LIST_DIR}/..)

include(${ni_root}/cmake/renode.cmake)
link_libraries(renode::renode pthread)

if(MINGW)
    # Windows loads an example host's C++ runtime DLLs from the first directory on PATH that has
    # them, and that copy can come from another toolchain and lack symbols the example host imports.
    string(APPEND CMAKE_EXE_LINKER_FLAGS " -static")
endif()

add_executable(librenode_example monitor.c)
add_executable(uart_example uart.c)
set(RENODE_API_TRANSPORT in_process)
add_subdirectory(${ni_root}/../external_control_client/lib ${CMAKE_CURRENT_BINARY_DIR}/renode_api)
add_executable(bus_handlers_host bus_handlers_host.cpp)
target_compile_features(bus_handlers_host PRIVATE cxx_std_17)
target_link_libraries(bus_handlers_host PRIVATE renode_api)
add_executable(gpio_host gpio_host.cpp)
target_compile_features(gpio_host PRIVATE cxx_std_17)
target_link_libraries(gpio_host PRIVATE renode_api)
add_executable(lockstep_device_host lockstep_device_host.cpp)
target_compile_features(lockstep_device_host PRIVATE cxx_std_17)
target_link_libraries(lockstep_device_host PRIVATE renode_api)
add_executable(lockstep_gpio_host lockstep_gpio_host.cpp)
target_compile_features(lockstep_gpio_host PRIVATE cxx_std_17)
target_link_libraries(lockstep_gpio_host PRIVATE renode_api)

set_target_properties(librenode_example PROPERTIES
    BUILD_RPATH_USE_ORIGIN TRUE
    INSTALL_RPATH "$ORIGIN"
)
