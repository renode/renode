function(renode_api_add_sanitizers_flags target)
    set(SANITIZERS "address,pointer-compare,pointer-subtract,undefined")
    if(NOT APPLE)
        set(SANITIZERS "${SANITIZERS},leak")
    endif()
    set(COMPILER_FLAGS_SANITIZERS -fsanitize=${SANITIZERS} -fno-sanitize-recover=all)

    # If RENODE_API_SANITIZERS is explicitly set, use its value.
    # Otherwise, default to enabling it in debug config only.
    if (DEFINED RENODE_API_SANITIZERS)
        if(RENODE_API_SANITIZERS)
            target_compile_options(${target}
                PRIVATE
                ${COMPILER_FLAGS_SANITIZERS}
            )
            target_link_libraries(${target} PRIVATE -fsanitize=${SANITIZERS})
            message(STATUS "Sanitizers enabled: ${SANITIZERS}")
        else()
            message(STATUS "Sanitizers disabled")
        endif()
    else()
        message(STATUS "Sanitizers for debug builds: ${SANITIZERS}")
        target_compile_options(${target}
            PRIVATE
            $<$<CONFIG:Debug>:${COMPILER_FLAGS_SANITIZERS}>
        )

        target_link_libraries(${target}
            PRIVATE
            $<$<CONFIG:Debug>:-fsanitize=${SANITIZERS}>
        )
    endif()
endfunction()
