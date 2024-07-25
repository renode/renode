cmake_minimum_required(VERSION 3.0)

option(LOG_PERF "Logging performance data instead of elapsed virtual time" OFF)

if (LOG_PERF)
	add_compile_definitions(LOG_PERF)
endif()
