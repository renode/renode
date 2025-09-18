//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <netdb.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdarg.h>
#include <stddef.h>

#include "renode_api.h"

struct renode {
    int socket_fd;
};

struct renode_machine {
    renode_t *renode;
    int32_t md;
};

struct renode_adc {
    renode_machine_t *machine;
    int32_t id;
};

struct renode_gpio {
    renode_machine_t *machine;
    int32_t id;
};

struct renode_bus_context {
    renode_machine_t *machine;
    int32_t id;
};

#define SERVER_START_COMMAND "emulation CreateExternalControlServer \"<NAME>\""
#define SOCKET_INVALID -1

#define unlikely(x) __builtin_expect(!!(x), 0)
#define assert(x) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); return create_fatal_error_static(NULL); } } while (0)
#define assert_fmsg(x, ...) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); return create_fatal_error(__VA_ARGS__); } } while (0)
#define assert_msg(x, msg) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); return create_fatal_error_static(msg); } } while (0)

// This is supposed to exit cause it's a fatal issue within the library code.
#define assert_exit(x) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); exit(EXIT_FAILURE); } } while (0)

#define return_error_if_fails(function) do { renode_error_t *_RE_ERROR; if ((_RE_ERROR = (function)) != NO_ERROR) return _RE_ERROR; } while (0)

/* Each response frame starts with 1 byte of return code and the following command and data depend on the code value.
 * Command is a 1 byte value of api_command_t.
 * Data is a 4 byte little endian unsigned value for the `count`, followed by the `count` bytes of raw data.
 * The comments next to enum values denote which parts of the frame should be expected.
 */

// matches ReturnCode enum in src/Renode/Network/ExternalControl/ExternalControlServer.cs
typedef enum {
    COMMAND_FAILED, // code, command, data
    FATAL_ERROR, // code, data
    INVALID_COMMAND, // code, command
    SUCCESS_WITH_DATA, // code, command, data
    SUCCESS_WITHOUT_DATA, // code, command
    SUCCESS_HANDSHAKE, // code
    ASYNC_EVENT, // code, command, callback id, data
} return_code_t;

// internal renode_error_t flags
#define ERROR_FREE_MESSAGE 0x01 // the message field needs to be freed

#define ERROR_DYNAMIC_MESSAGE_SIZE 0x400

static void *xmalloc(size_t size)
{
    void *result = malloc(size);
    assert_exit(result != NULL);
    return result;
}

static void xcleanup(void *ptr)
{
    free(*(void**)ptr);
}

static renode_error_t *create_error_static(renode_error_code code, char *message)
{
    renode_error_t *error = xmalloc(sizeof(renode_error_t));
    error->code = code;
    error->flags = 0;
    error->message = message;
    error->data = NULL;
    return error;
}

static renode_error_t *create_error_dynamic(renode_error_code code, char *message)
{
    renode_error_t *error = create_error_static(code, message);
    error->flags |= ERROR_FREE_MESSAGE;
    return error;
}

#define create_connection_failed_error(message) create_error_static(ERR_COMMAND_FAILED, (message))
#define create_fatal_error_static(message) create_error_static(ERR_FATAL, (message))

static renode_error_t *create_error(renode_error_code code, char *fmt, ...)
{
    char *message = xmalloc(ERROR_DYNAMIC_MESSAGE_SIZE);
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

void renode_free_error(renode_error_t *error)
{
    if (error->flags & ERROR_FREE_MESSAGE) {
        free(error->message);
    }
    free(error);
}

#define ERRMSG_FAILED_TO_READ_FROM_SOCKET "Failed to read from socket"
#define ERRMSG_FAILED_TO_WRITE_TO_SOCKET "Failed to write to socket"
#define ERRMSG_SOCKET_CLOSED "Socket was closed"
#define ERRMSG_UNEXPECTED_RETURN_CODE "Unexpected return code"
#define ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE "Received unexpected number of bytes"
#define ERRMSG_COMMAND_MISMATCH "received mismatched command"

typedef enum {
    ANY_COMMAND = 0,
    RUN_FOR = 1,
    GET_TIME,
    GET_MACHINE,
    ADC,
    GPIO,
    SYSTEM_BUS,
    EVENT = -1,
} api_command_t;

static uint8_t command_versions[][2] = {
    { 0x0, 0x0 }, // reserved for size
    { RUN_FOR, 0x0 },
    { GET_TIME, 0x0 },
    { GET_MACHINE, 0x0 },
    { ADC, 0x0 },
    { GPIO, 0x1 },
    { SYSTEM_BUS, 0x0 },
};

static renode_error_t *write_or_fail(int socket_fd, const uint8_t *data, ssize_t count)
{
    ssize_t sent;

    assert_msg(count > 0, "Usage error: attempted to write invalid number of bytes to socket");

    while (count > 0 && (sent = write(socket_fd, data, count)) > 0) {
        count -= sent;
    }

    if (sent <= 0) {
        return create_connection_failed_error(ERRMSG_FAILED_TO_WRITE_TO_SOCKET);
    }

    return NO_ERROR;
}

static renode_error_t *read_byte_or_fail(int socket_fd, uint8_t *value)
{
    ssize_t received;

    if ((received = read(socket_fd, value, 1)) == 1) {
        return NO_ERROR;
    }

    if (received == 0) {
        return create_connection_failed_error(ERRMSG_SOCKET_CLOSED);
    }

    return create_connection_failed_error(ERRMSG_FAILED_TO_READ_FROM_SOCKET);
}


static renode_error_t *read_or_fail(int socket_fd, uint8_t *buffer, uint32_t count)
{
    ssize_t received;

    assert_msg(count > 0, "Usage error: attempted to read invalid number of bytes from socket");

    while (count > 0 && (received = read(socket_fd, buffer, count)) > 0) {
        buffer += received;
        count -= received;
    }

    if (received == 0) {
        return create_connection_failed_error(ERRMSG_SOCKET_CLOSED);
    }

    if (received == -1) {
        return create_connection_failed_error(ERRMSG_FAILED_TO_READ_FROM_SOCKET);
    }

    return NO_ERROR;
}

static renode_error_t *perform_handshake(int socket_fd)
{
    *(uint16_t *)command_versions = sizeof(command_versions) / 2 - 1;

    return_error_if_fails(write_or_fail(socket_fd, (uint8_t *)command_versions, sizeof(command_versions)));

    uint8_t response;

    return_error_if_fails(read_byte_or_fail(socket_fd, &response));

    assert_msg(response == SUCCESS_HANDSHAKE, "API command version mismatch");

    return NO_ERROR;
}

static renode_error_t *obtain_socket(int *socket_fd, const char *address, const char *port)
{
    struct addrinfo  hints;
    struct addrinfo  *results, *rp;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;     /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM; /* TCP socket */
    hints.ai_protocol = 0;           /* Any protocol */
    hints.ai_flags = 0;

    int error = getaddrinfo(address, port, &hints, &results);
    assert_fmsg(!error, "Unable to find the server: %s", gai_strerror(error));

    for (rp = results; rp != NULL; rp = rp->ai_next) {

        *socket_fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);

        if (*socket_fd == -1) {
            continue;
        }

        if (connect(*socket_fd, rp->ai_addr, rp->ai_addrlen) == -1) {
            close(*socket_fd);
            continue;
        }

        freeaddrinfo(results);
        return NO_ERROR;
    }

    fprintf(stderr,
        "Failed to connect to the server using port %s.\n"
        "Make sure the server in Renode has been started with: `" SERVER_START_COMMAND " %s`\n",
        port, port);
    return create_fatal_error_static("Unable to connect to the server");
}

renode_error_t *renode_connect(const char *port, renode_t **renode)
{
    int socket_fd = -1;

    assert(port != NULL && renode != NULL);

    return_error_if_fails(obtain_socket(&socket_fd, "localhost", port));

    return_error_if_fails(perform_handshake(socket_fd));

    *renode = xmalloc(sizeof(renode_t));
    (*renode)->socket_fd = socket_fd;

    return NO_ERROR;
};

renode_error_t *renode_disconnect(renode_t **renode)
{
    assert(renode != NULL && *renode != NULL);

    close((*renode)->socket_fd);
    free(*renode);
    *renode = NULL;

    return NO_ERROR;
}

static renode_error_t *renode_send_header(renode_t *renode, api_command_t api_command, uint32_t data_size)
{
    uint8_t header[7] = {
        'R', 'E', api_command
    };

    *(uint32_t*)(header + 3) = data_size;

    return write_or_fail(renode->socket_fd, header, sizeof(header));
}

static renode_error_t *renode_send_command(renode_t *renode, api_command_t api_command, const uint8_t *data, uint32_t data_size)
{
    // `api_command` should be 1B non-negative integer.
    assert_exit(renode != NULL && api_command >= 0 && api_command < 0xFF);

    return_error_if_fails(renode_send_header(renode, api_command, data_size));

    return write_or_fail(renode->socket_fd, data, data_size);
}

static renode_error_t *renode_receive_byte(renode_t *renode, uint8_t *value)
{
    return read_byte_or_fail(renode->socket_fd, value);
}

static renode_error_t *renode_receive_bytes(renode_t *renode, uint8_t *buffer, uint32_t count)
{
    return read_or_fail(renode->socket_fd, buffer, count);
}

struct renode_event {
    uint32_t ed;
    api_command_t command;
    uint32_t size;
    uint8_t data[];
};

#define MAX_CALLBACK_COUNT 1024

typedef void (*raw_callback_t)(void *, void *);

static raw_callback_t callbacks[MAX_CALLBACK_COUNT];
static void *callback_user_data[MAX_CALLBACK_COUNT];
static uint32_t callbacks_count;

static renode_error_t *register_callback(raw_callback_t callback, void *user_data, uint32_t *ed)
{
    assert_msg(callbacks_count < MAX_CALLBACK_COUNT, "Cannot register any more callbacks");

    callbacks[callbacks_count] = callback;
    callback_user_data[callbacks_count] = user_data;

    *ed = callbacks_count;
    callbacks_count += 1;

    return NO_ERROR;
}

static renode_error_t *invoke_callback(struct renode_event *response)
{
    switch(response->command)
    {
    case GPIO:
        assert_msg(response->ed < callbacks_count, "Tried to invoke callback for an invalid event descriptor");
        assert_msg(response->size == sizeof(renode_gpio_event_data_t), ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);
        renode_gpio_event_data_t *data = (renode_gpio_event_data_t*)response->data;

        callbacks[response->ed](callback_user_data[response->ed], data);
        return NO_ERROR;
    default:
        assert_msg(false, "Tried to invoke callback for an invalid command");
    }
}

static renode_error_t *renode_receive_event(renode_t *renode, void **buffer)
{
    uint8_t command = 0;
    uint32_t ed = 0;
    uint32_t size = 0;

    return_error_if_fails(renode_receive_bytes(renode, &command, 1));
    return_error_if_fails(renode_receive_bytes(renode, (uint8_t*)&ed, 4));
    return_error_if_fails(renode_receive_bytes(renode, (uint8_t*)&size, 4));

    struct renode_event *event = xmalloc(sizeof(struct renode_event) + size);
    event->ed = ed;
    event->size = size;
    event->command = command;

    renode_error_t *error = renode_receive_bytes(renode, (uint8_t*)&event->data, event->size);

    if (error != NO_ERROR) {
        free(event);
        return error;
    }

    *buffer = event;
    return NO_ERROR;
}

static renode_error_t *renode_receive_response(renode_t *renode, api_command_t *command, void **data_buffer, uint32_t buffer_size, uint32_t *data_size)
{
    uint8_t *buffer = *data_buffer;
    uint8_t return_code;
    uint8_t received_command;
    *data_size = -1;

    return_error_if_fails(renode_receive_byte(renode, &return_code));

    switch (return_code) {
        case COMMAND_FAILED:
        case INVALID_COMMAND:
        case SUCCESS_WITH_DATA:
        case SUCCESS_WITHOUT_DATA:
        case FATAL_ERROR:
            break;
        case ASYNC_EVENT:
            return_error_if_fails(renode_receive_event(renode, data_buffer));
            if (*command == EVENT || *command == ANY_COMMAND) {
                *command = EVENT;
                return NO_ERROR;
            }
            free(*data_buffer);
            return create_fatal_error_static("received unexpected event");
        default:
            return create_fatal_error_static(ERRMSG_UNEXPECTED_RETURN_CODE);
    }

    switch (return_code) {
        case COMMAND_FAILED:
        case INVALID_COMMAND:
        case SUCCESS_WITH_DATA:
        case SUCCESS_WITHOUT_DATA:
            return_error_if_fails(renode_receive_byte(renode, &received_command));
        case FATAL_ERROR:
            break;
        default:
            return create_fatal_error_static(ERRMSG_UNEXPECTED_RETURN_CODE);
    }

    switch (return_code) {
        case COMMAND_FAILED:
        case FATAL_ERROR:
            return_error_if_fails(renode_receive_bytes(renode, (uint8_t*)data_size, 4));

            if (buffer_size < *data_size + 1) {
                buffer = xmalloc(*data_size + 1);
            }
            buffer[*data_size] = '\0';

            return_error_if_fails(renode_receive_bytes(renode, buffer, *data_size));
            break;
        case SUCCESS_WITH_DATA:
            return_error_if_fails(renode_receive_bytes(renode, (uint8_t*)data_size, 4));

            if (buffer_size < *data_size) {
                return create_fatal_error_static("Buffer too small");
            }

            return_error_if_fails(renode_receive_bytes(renode, buffer, *data_size));
            break;
        case INVALID_COMMAND:
        case SUCCESS_WITHOUT_DATA:
            *data_size = 0;
            break;
        default:
            return create_fatal_error_static(ERRMSG_UNEXPECTED_RETURN_CODE);
    }

    renode_error_code error_code = ERR_NO_ERROR;
    switch (return_code) {
        case COMMAND_FAILED:
            error_code = ERR_COMMAND_FAILED;
            break;
        case FATAL_ERROR:
            error_code = ERR_COMMAND_FAILED;
            break;
        default:
            break;
    }

    if (error_code != ERR_NO_ERROR) {
        return create_error_dynamic(error_code, (char *)buffer);
    }

    if (return_code == INVALID_COMMAND) {
        return create_fatal_error_static("received invalid command error");
    }

    if (*command != ANY_COMMAND && received_command != *command) {
        return create_fatal_error_static(ERRMSG_COMMAND_MISMATCH);
    }
    *command = received_command;

    return NO_ERROR;
}

static renode_error_t *renode_execute_command(renode_t *renode, api_command_t api_command, void *data_buffer, uint32_t buffer_size, uint32_t sent_data_size, uint32_t *received_data_size)
{
    assert(api_command != ANY_COMMAND && api_command != EVENT);
    assert(buffer_size >= sent_data_size);

    return_error_if_fails(renode_send_command(renode, api_command, data_buffer, sent_data_size));

    uint32_t ignored_data_size;
    void **buffer = &data_buffer;
    return_error_if_fails(renode_receive_response(renode, &api_command, buffer, buffer_size, received_data_size == NULL ? &ignored_data_size : received_data_size));

    return NO_ERROR;
}

renode_error_t *renode_get_machine(renode_t *renode, const char *name, renode_machine_t **machine)
{
    uint32_t name_length = strlen(name);
    uint32_t data_size = name_length + sizeof(int32_t);
    int32_t *data __attribute__ ((__cleanup__(xcleanup))) = xmalloc(data_size);

    data[0] = name_length;
    memcpy(data + 1, name, name_length);

    return_error_if_fails(renode_execute_command(renode, GET_MACHINE, data, data_size, data_size, &data_size));

    assert_msg(data_size == 4, "received unexpected number of bytes");

    assert_msg(data[0] >= 0, "received invalid machine descriptor");

    *machine = xmalloc(sizeof(renode_machine_t));
    (*machine)->renode = renode;
    (*machine)->md = data[0];

    return NO_ERROR;
}

static renode_error_t *renode_get_instance_descriptor(renode_machine_t *machine, api_command_t api_command, const char *name, int32_t *instance_descriptor)
{
    uint32_t name_length = strlen(name);
    uint32_t data_size = name_length + sizeof(int32_t) * 3;
    int32_t *data __attribute__ ((__cleanup__(xcleanup))) = xmalloc(data_size);

    data[0] = -1;
    data[1] = machine->md;
    data[2] = name_length;
    memcpy(data + 3, name, name_length);

    return_error_if_fails(renode_execute_command(machine->renode, api_command, data, data_size, data_size, &data_size));

    assert_msg(data_size == 4, "received unexpected number of bytes");

    *instance_descriptor = data[0];

    assert_msg(*instance_descriptor >= 0, "received invalid instance descriptor");

    return NO_ERROR;
}

struct __attribute__((packed)) run_for_out {
    uint8_t header[2];
    uint8_t api_command;
    uint32_t data_size;
    uint64_t microseconds;
};

renode_error_t *renode_run_for(renode_t *renode, renode_time_unit_t unit, uint64_t value)
{
    assert(renode != NULL && value < UINT64_MAX / unit);

    struct run_for_out data = {
        .header = {'R', 'E'},
        .api_command = RUN_FOR,
        .data_size = sizeof(data.microseconds)
    };
    switch (unit) {
        case TU_MICROSECONDS:
        case TU_MILLISECONDS:
        case TU_SECONDS:
            // The enum values are equal to 1 `unit` expressed in microseconds.
            data.microseconds = value * unit;
            break;
        default:
            assert_fmsg(false, "Invalid unit: %d\n", unit);
    }

    return_error_if_fails(write_or_fail(renode->socket_fd, (uint8_t*)&data, sizeof(data)));

    api_command_t command;
    do {
        command = ANY_COMMAND;

        uint32_t response_size;
        void *buffer = &data;
        return_error_if_fails(renode_receive_response(renode, &command, &buffer, sizeof(data), &response_size));

        if (command == RUN_FOR) {
            break;
        }

        if (command != EVENT) {
            return create_fatal_error_static(ERRMSG_COMMAND_MISMATCH);
        }

        struct renode_event *event = buffer;
        renode_error_t *error = invoke_callback(event);
        free(event);

        if (error != NO_ERROR) {
            return error;
        }
    }
    while(command != RUN_FOR);

    return NO_ERROR;
}

renode_error_t *renode_get_current_time(renode_t *renode, renode_time_unit_t unit, uint64_t *current_time)
{
    assert(renode != NULL);

    uint64_t divider;
    switch (unit) {
        case TU_MICROSECONDS:
        case TU_MILLISECONDS:
        case TU_SECONDS:
            // The enum values are equal to 1 `unit` expressed in microseconds.
            divider = unit;
            break;
        default:
            assert_fmsg(false, "Invalid unit: %d\n", unit);
    }

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(renode, GET_TIME, current_time, sizeof(*current_time), sizeof(*current_time), &response_size));

    assert_msg(response_size == sizeof(*current_time), ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    *current_time /= divider;

    return NO_ERROR;
}

renode_error_t *renode_get_adc(renode_machine_t *machine, const char *name, renode_adc_t **adc)
{
    int32_t id;
    return_error_if_fails(renode_get_instance_descriptor(machine, ADC, name, &id));

    *adc = xmalloc(sizeof(renode_adc_t));
    (*adc)->machine = machine;
    (*adc)->id = id;

    return NO_ERROR;
}

typedef enum {
    GET_CHANNEL_COUNT = 0,
    GET_CHANNEL_VALUE,
    SET_CHANNEL_VALUE,
} adc_command_t;

typedef union {
    struct {
        int32_t id;
        int8_t command;
        int32_t channel;
        uint32_t value;
    } __attribute__((packed)) out;

    struct {
        int32_t count;
    } get_count_result;

    struct {
        uint32_t value;
    } get_value_result;
} adc_frame_t;

renode_error_t *renode_get_adc_channel_count(renode_adc_t *adc, int32_t *count)
{
    // adc id, adc command -> count
    adc_frame_t frame = {
        .out = {
            .id = adc->id,
            .command = GET_CHANNEL_COUNT,
        },
    };

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(adc->machine->renode, ADC, &frame, sizeof(frame), offsetof(adc_frame_t, out.channel), &response_size));

    assert_msg(response_size == sizeof(*count), ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    *count = frame.get_count_result.count;

    return NO_ERROR;
}

renode_error_t *renode_get_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t *value)
{
    // adc id, adc command, channel index -> value
    adc_frame_t frame = {
        .out = {
            .id = adc->id,
            .command = GET_CHANNEL_VALUE,
            .channel = channel,
        },
    };

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(adc->machine->renode, ADC, &frame, sizeof(frame), offsetof(adc_frame_t, out.value), &response_size));

    assert_msg(response_size == sizeof(*value), ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    *value = frame.get_value_result.value;

    return NO_ERROR;
}

renode_error_t *renode_set_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t value)
{
    // adc id, adc command, channel index, value -> ()
    adc_frame_t frame = {
        .out = {
            .id = adc->id,
            .command = SET_CHANNEL_VALUE,
            .channel = channel,
            .value = value,
        },
    };

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(adc->machine->renode, ADC, &frame, sizeof(frame), sizeof(frame.out), &response_size));

    assert_msg(response_size == 0, ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    return NO_ERROR;
}

renode_error_t *renode_get_gpio(renode_machine_t *machine, const char *name, renode_gpio_t **gpio)
{
    int32_t id;
    return_error_if_fails(renode_get_instance_descriptor(machine, GPIO, name, &id));

    *gpio = xmalloc(sizeof(renode_gpio_t));
    (*gpio)->machine = machine;
    (*gpio)->id = id;

    return NO_ERROR;
}

typedef enum {
    GET_STATE,
    SET_STATE,
    REGISTER_EVENT,
} gpio_command_t;

typedef union {
    struct {
        int32_t id;
        int8_t command;
        int32_t number;
        uint8_t state;
    } __attribute__((packed)) out;

    struct {
        uint8_t value;
    } get_state_result;
} gpio_frame_t;

renode_error_t *renode_get_gpio_state(renode_gpio_t *gpio, int32_t id, bool *state)
{
    // gpio id, gpio command, pin number -> state
    gpio_frame_t frame = {
        .out = {
            .id = gpio->id,
            .command = GET_STATE,
            .number = id,
        },
    };
    uint8_t value = *state;

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(gpio->machine->renode, GPIO, &frame, sizeof(frame), offsetof(gpio_frame_t, out.state), &response_size));

    assert_msg(response_size == sizeof(value), ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    *state = frame.get_state_result.value;

    return NO_ERROR;
}

renode_error_t *renode_set_gpio_state(renode_gpio_t *gpio, int32_t id, bool state)
{
    // gpio id, gpio command, pin number, state -> ()
    gpio_frame_t frame = {
        .out = {
            .id = gpio->id,
            .command = SET_STATE,
            .number = id,
            .state = state,
        },
    };

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(gpio->machine->renode, GPIO, &frame, sizeof(frame), sizeof(frame.out), &response_size));

    assert_msg(response_size == 0, ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    return NO_ERROR;
}

struct gpio_callback_data
{
    bool current_state;
};

struct __attribute__((packed)) event_gpio_frame
{
    int32_t id;
    int8_t command;
    int32_t number;
    int32_t ed;
};

renode_error_t *renode_register_gpio_state_change_callback(renode_gpio_t *gpio, int32_t id, void *user_data, void (*callback)(void *, renode_gpio_event_data_t *))
{
    uint32_t ed;
    return_error_if_fails(register_callback((raw_callback_t)callback, user_data, &ed));

    struct event_gpio_frame frame = {
        .id = gpio->id,
        .command = REGISTER_EVENT,
        .number = id,
        .ed = ed,
    };

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(gpio->machine->renode, GPIO, &frame, sizeof(frame), sizeof(frame), &response_size));

    assert_msg(response_size == 0, ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    return NO_ERROR;
}

renode_error_t *renode_get_bus_context(renode_machine_t *machine, const char *name, renode_bus_context_t **peripheral)
{
    int32_t id;
    return_error_if_fails(renode_get_instance_descriptor(machine, SYSTEM_BUS, name, &id));

    *peripheral = xmalloc(sizeof(renode_bus_context_t));
    (*peripheral)->machine = machine;
    (*peripheral)->id = id;

    return NO_ERROR;
}

renode_error_t *renode_get_sysbus(renode_machine_t *machine, renode_bus_context_t **sysbus)
{
    return renode_get_bus_context(machine, "sysbus", sysbus);
}

typedef enum {
    SYSBUS_READ = 0,
    SYSBUS_WRITE = 1,
} sysbus_operation_t;

typedef struct __attribute__((packed)) {
    int32_t id;
    uint8_t operation;
    uint8_t access_width;
    uint64_t address;
    uint32_t data_count;
    uint8_t data[];
} sysbus_command_t;

static renode_error_t *sysbus_data_count_to_byte_count(renode_access_width_t width, size_t count, uint64_t *byte_count)
{
    if (width == AW_MULTI_BYTE) {
        *byte_count = count;
        return NO_ERROR;
    }

    uint32_t result;
    switch (width) {
    case AW_BYTE:
    case AW_WORD:
    case AW_DOUBLE_WORD:
    case AW_QUAD_WORD:
        result = (uint32_t)width * count;
        // Handle overflow
        if (result / (uint32_t)width != count) {
            return create_fatal_error("Payload size exceeds %u bytes", UINT32_MAX);
        }
        *byte_count = result;
        return NO_ERROR;
    default:
        return create_fatal_error("Invalid bus access width: %d", width);
    }
}

renode_error_t *renode_sysbus_read(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, void *buffer, uint32_t count)
{
    size_t data_bytes;
    return_error_if_fails(sysbus_data_count_to_byte_count(width, count, &data_bytes));
    size_t payload_size = sizeof(sysbus_command_t) + data_bytes;
    sysbus_command_t *command __attribute__ ((__cleanup__(xcleanup)))  = xmalloc(payload_size);
    *command = (sysbus_command_t){
        .id = ctx->id,
        .operation = SYSBUS_READ,
        .access_width = width,
        .address = address,
        .data_count = count,
    };

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(ctx->machine->renode, SYSTEM_BUS, command, payload_size, sizeof(sysbus_command_t), &response_size));
    assert_msg(response_size == data_bytes, ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);

    // `renode_execute_command` returns the resulting data into the same buffer that contained the command
    // to send, effectively overriding the command bytes. This causes the returned data to be to be present
    // at the start of the command structure not at `sysbus_command_t::data`
    memcpy(buffer, command, data_bytes);
    return NO_ERROR;
}

renode_error_t *renode_sysbus_write(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, const void *buffer, uint32_t count)
{
    size_t data_bytes;
    return_error_if_fails(sysbus_data_count_to_byte_count(width, count, &data_bytes));
    size_t payload_size = sizeof(sysbus_command_t) + data_bytes;
    sysbus_command_t *command __attribute__ ((__cleanup__(xcleanup)))  = xmalloc(payload_size);
    *command = (sysbus_command_t){
        .id = ctx->id,
        .operation = SYSBUS_WRITE,
        .access_width = width,
        .address = address,
        .data_count = count,
    };
    memcpy(command->data, buffer, data_bytes);

    uint32_t response_size;
    return_error_if_fails(renode_execute_command(ctx->machine->renode, SYSTEM_BUS, command, payload_size, payload_size, &response_size));
    assert_msg(response_size == 0, ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);
    return NO_ERROR;
}
