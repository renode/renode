//
// Copyright (c) 2010-2025 Silicon Labs
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//

#include <time.h>
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <errno.h>
#ifndef _WIN32
#include <sys/time.h>
#endif
#ifdef __APPLE__
#include <AvailabilityMacros.h>
#endif
#ifdef _WIN32
#include <windows.h>
#include <winsock2.h>  // For struct timeval
#endif
#include "renode_api.h"

// Feature detection for clock_gettime availability
#if defined(_WIN32)
#define HAS_CLOCK_GETTIME 0  // Windows doesn't have clock_gettime natively
#define HAS_GETTIMEOFDAY 0   // Windows doesn't have gettimeofday natively
#elif defined(__APPLE__)
#if MAC_OS_X_VERSION_MIN_REQUIRED >= 101200
#define HAS_CLOCK_GETTIME 1
#else
#define HAS_CLOCK_GETTIME 0
#endif
#define HAS_GETTIMEOFDAY 1
#elif defined(__linux__)
#define HAS_CLOCK_GETTIME 1
#define HAS_GETTIMEOFDAY 1
#else
#define HAS_CLOCK_GETTIME 1  // Assume available on other POSIX systems
#define HAS_GETTIMEOFDAY 1
#endif

// Windows-specific definitions
#ifdef _WIN32
#ifndef CLOCK_REALTIME
#define CLOCK_REALTIME 0
#endif
#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC 1
#endif

typedef int clockid_t;

// Define struct timespec for Windows if not already defined
#ifndef _TIMESPEC_DEFINED
struct timespec {
    time_t tv_sec;
    long tv_nsec;
};
#define _TIMESPEC_DEFINED
#endif
#endif

// Global renode instance for time queries
static renode_t *g_renode_instance = NULL;
static bool g_initialization_attempted = false;

// Initialize renode connection if not already done
static int ensure_renode_connection(void)
{
    if (g_renode_instance != NULL) {
        return 0; // Already connected
    }
    
    if (g_initialization_attempted) {
        return -1; // Previous initialization failed
    }
    
    g_initialization_attempted = true;
    
    // Get port from environment variable, default to "1234"
    const char *port = getenv("RENODE_PORT");
    if (port == NULL) {
        port = "1234";
    }
    
    renode_error_t *error = renode_connect(port, &g_renode_instance);
    if (error != NO_ERROR) {
        renode_free_error(error);
        g_renode_instance = NULL;
        printf("Failed to connect to Renode on port %s\n", port);
        return -1;
    }

    printf("Successfully connected to Renode on port %s\n", port);
    
    return 0;
}

// Cross-platform clock_gettime implementation
#if defined(_WIN32) || !HAS_CLOCK_GETTIME
// Windows or platforms without native clock_gettime
int clock_gettime(clockid_t __clock_id, struct timespec *__tp)
#else
// POSIX systems with native clock_gettime
int clock_gettime(clockid_t __clock_id, struct timespec *__tp)
#endif
{
    (void)__clock_id; // Ignore clock type for now
    
    // Ensure renode connection is established
    if (ensure_renode_connection() != 0) {
        errno = ENODEV; // No such device
        return -1;
    }
    
    renode_time_t current_time;
    renode_error_t *error = renode_get_current_time(g_renode_instance, &current_time);
    if (error != NO_ERROR) {
        renode_free_error(error);
        errno = EIO; // I/O error
        return -1;
    }

    uint64_t current_time_us = renode_time_to_time_unit(current_time, TU_MICROSECONDS);
    
    // Convert microseconds to timespec (seconds + nanoseconds)
    __tp->tv_sec = current_time_us / 1000000;
    __tp->tv_nsec = (current_time_us % 1000000) * 1000;

    // Optional: Print the current time for debugging
    //printf("Current time: %ld.%09ld seconds\n", __tp->tv_sec, __tp->tv_nsec);
    
    return 0;
}

// Cross-platform gettimeofday implementation
#if defined(_WIN32)
// Windows implementation
int gettimeofday(struct timeval *tv, void *tz)
#elif defined(__APPLE__)
// macOS implementation
int gettimeofday(struct timeval * __restrict tv, void * __restrict tz)
#else
// Linux/POSIX implementation
int gettimeofday(struct timeval * __restrict tv, void * __restrict tz)
#endif
{
    // timezone parameter is obsolete and should be NULL
    (void)tz;
    
    // Ensure renode connection is established
    if (ensure_renode_connection() != 0) {
        errno = ENODEV; // No such device
        return -1;
    }
    
    renode_time_t current_time;
    renode_error_t *error = renode_get_current_time(g_renode_instance, &current_time);
    if (error != NO_ERROR) {
        renode_free_error(error);
        errno = EIO; // I/O error
        return -1;
    }

    uint64_t current_time_us = renode_time_to_time_unit(current_time, TU_MICROSECONDS);
    
    // Convert microseconds to timeval (seconds + microseconds)
    tv->tv_sec = current_time_us / 1000000;
    tv->tv_usec = current_time_us % 1000000;

    // Optional: Print the current time for debugging
    //printf("Current time: %ld.%06ld seconds\n", (long)tv->tv_sec, (long)tv->tv_usec);
    
    return 0;
}

// Cleanup function to disconnect from renode
// This can be called explicitly or via atexit()
void silabs_time_cleanup(void)
{
    if (g_renode_instance != NULL) {
        renode_disconnect(&g_renode_instance);
        g_renode_instance = NULL;
    }
}

// Constructor to register cleanup function
#ifdef _WIN32
__declspec(dllexport) BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    (void)hinstDLL;
    (void)lpvReserved;
    
    switch (fdwReason) {
        case DLL_PROCESS_ATTACH:
            // Initialize on process attach
            break;
        case DLL_PROCESS_DETACH:
            // Cleanup on process detach
            silabs_time_cleanup();
            break;
    }
    return TRUE;
}
#else
__attribute__((constructor))
static void silabs_time_init(void)
{
    atexit(silabs_time_cleanup);
}
#endif