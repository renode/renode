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

set(SANITIZERS "address,pointer-compare,pointer-subtract,undefined")
if(NOT APPLE)
    set(SANITIZERS "${SANITIZERS},leak")
endif()
set(COMPILER_FLAGS_SANITIZERS -fsanitize=${SANITIZERS} -fno-sanitize-recover=all)

# If RENODE_API_SANITIZERS is explicitly set, use its value.
# Otherwise, default to enabling it in debug config only.
if (DEFINED RENODE_API_SANITIZERS)
    if(RENODE_API_SANITIZERS)
        target_compile_options(renode_api
            PRIVATE
            ${COMPILER_FLAGS_SANITIZERS}
        )
        target_link_libraries(renode_api PRIVATE -fsanitize=${SANITIZERS})
        message(STATUS "Sanitizers enabled: ${SANITIZERS}")
    else()
        message(STATUS "Sanitizers disabled")
    endif()
else()
    message(STATUS "Sanitizers for debug builds: ${SANITIZERS}")
    target_compile_options(renode_api
        PRIVATE
        $<$<CONFIG:Debug>:${COMPILER_FLAGS_SANITIZERS}>
    )

    target_link_libraries(renode_api
        PRIVATE
        $<$<CONFIG:Debug>:-fsanitize=${SANITIZERS}>
    )
endif()
