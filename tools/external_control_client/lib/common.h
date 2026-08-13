#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include "renode_api.h"

#define unlikely(x) __builtin_expect(!!(x), 0)
#define assert(x) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); return create_fatal_error_static(NULL); } } while (0)
#define assert_fmsg(x, ...) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); return create_fatal_error(__VA_ARGS__); } } while (0)
#define assert_msg(x, msg) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); return create_fatal_error_static(msg); } } while (0)

// This is supposed to exit cause it's a fatal issue within the library code.
#define assert_exit(x) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); exit(EXIT_FAILURE); } } while (0)

#define return_error_if_fails(function) do { renode_error_t *_RE_ERROR; if ((_RE_ERROR = (function)) != NO_ERROR) return _RE_ERROR; } while (0)

#define SERVER_START_COMMAND "emulation CreateExternalControlServer \"<NAME>\""

// internal renode_error_t flags
#define ERROR_FREE_MESSAGE 0x01 // the message field needs to be freed

#define ERROR_DYNAMIC_MESSAGE_SIZE 0x400

#ifdef RENODE_API_VERBOSE
#define verbose_print(fmt, ...) fprintf(stderr, "Renode API: " fmt "\n", __VA_ARGS__)
#else
#define verbose_print(fmt, ...)
#endif

// Needs to be in sync with `Antmicro.Renode.Network.ExternalControl.Command` in C#
typedef enum {
    CHECK_VERSION = 0,
    RUN_FOR,
    GET_TIME,
    GET_MACHINE,
    ADC,
    GPIO,
    SYSTEM_BUS,
    TIME_ELAPSED_CALLBACK,
    SPI,
} api_command_t;

// Needs to be in sync with `Antmicro.Renode.Network.ExternalControl.CommandType` in C#
typedef enum {
    TYPE_REQUEST = 0x0,
    TYPE_EVENT_REQUEST = 0x1,
    TYPE_SUCCESS = 0x2,
    TYPE_INVALID_COMMAND = 0x3,
    TYPE_ERROR = 0x4,
} command_type_t;

// Needs to be in sync with `Antmicro.Renode.Network.ExternalControl.MessagePayload` in C#
typedef struct __attribute__((packed)) {
    uint16_t command;
    uint8_t type;
} message_payload_t;

// Needs to be in sync with `Antmicro.Renode.Network.ExternalControl.GetVersion.ProtocolVersion` in C#
static const uint32_t PROTOCOL_VERSION = 0;

static inline void *xmalloc(size_t size)
{
    void *result = malloc(size);
    assert_exit(result != NULL);
    return result;
}

static inline void xcleanup(void *ptr)
{
    free(*(void**)ptr);
}

static inline renode_error_t *create_error_static(renode_error_code_t code, char *message)
{
    renode_error_t *error = (renode_error_t *)xmalloc(sizeof(renode_error_t));
    error->code = code;
    error->flags = 0;
    error->message = message;
    error->data = NULL;
    return error;
}

static inline renode_error_t *create_error_dynamic(renode_error_code_t code, char *message)
{
    renode_error_t *error = create_error_static(code, message);
    error->flags |= ERROR_FREE_MESSAGE;
    return error;
}

#define create_connection_failed_error(message) create_error_static(ERR_COMMAND_FAILED, (message))
#define create_fatal_error_static(message) create_error_static(ERR_FATAL, (message))

static inline renode_error_t *create_error(renode_error_code_t code, char *fmt, ...)
{
    char *message = (char *)xmalloc(ERROR_DYNAMIC_MESSAGE_SIZE);
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(message, ERROR_DYNAMIC_MESSAGE_SIZE, fmt, ap);
    va_end(ap);

    renode_error_t *error = create_error_static(code, message);
    error->flags |= ERROR_FREE_MESSAGE;
    return error;
}

#define create_fatal_error(...) create_error(ERR_FATAL, __VA_ARGS__)
#define create_command_failed_error(...) create_error(ERR_COMMAND_FAILED, __VA_ARGS__)
