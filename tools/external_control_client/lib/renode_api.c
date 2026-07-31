//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
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

#include "common.h"
#include "connection.h"

struct renode {
    renode_connection_t *conn;
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

void renode_free_error(renode_error_t *error)
{
    if (error == NO_ERROR) {
        return;
    }

    if (error->flags & ERROR_FREE_MESSAGE) {
        free(error->message);
    }
    free(error);
}

void renode_set_fatal_error_callback(renode_t *renode, void *user_data, renode_fatal_error_callback_t callback)
{
    renode_connection_set_fatal_error_callback(renode->conn, callback, user_data);
}

#define ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE "Received unexpected number of bytes"
#define ERRMSG_COMMAND_MISMATCH "Received mismatched command"

// Needs to be in sync with `Antmicro.Renode.Network.ExternalControl.Command` in C#
typedef enum {
    CHECK_VERSION = 0,
    RUN_FOR,
    GET_TIME,
    GET_MACHINE,
    ADC,
    GPIO,
    SYSTEM_BUS,
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

#define REQUEST_HEADER(cmd) {&(const message_payload_t){ cmd, TYPE_REQUEST }, sizeof(message_payload_t)}

// Needs to be in sync with `Antmicro.Renode.Network.ExternalControl.GetVersion.ProtocolVersion` in C#
static const uint32_t PROTOCOL_VERSION = 0;

static renode_error_t *generic_handler(renode_connection_t *conn, const void *response, size_t size, void *ud);
static renode_error_t *parse_response(const void *response, size_t size, message_payload_t *header, const void **data, uint32_t *data_size);

static renode_error_t *check_version_handler(renode_connection_t *conn, const void *response, size_t size, void *ud)
{
    (void)conn;
    (void)ud;

    message_payload_t header;
    const void *data;
    uint32_t data_size;

    return_error_if_fails(parse_response(response, size, &header, &data, &data_size));
    if(header.type != TYPE_SUCCESS) {
        return create_error(ERR_COMMAND_FAILED, "Unexpected status on a CHECK_VERSION response: 0x%"PRIx8, header.type);
    }
    return NO_ERROR;
}

renode_error_t *renode_connect(const char *port, renode_t **renode)
{
    assert(port != NULL && renode != NULL);

    renode_connection_t *conn;
    return_error_if_fails(renode_connection_open(&conn, &(renode_connection_config_t) {
        .address = "localhost",
        .port = port,
    }));

    renode_error_t *err = renode_connection_send(conn, check_version_handler, NULL,
        REQUEST_HEADER(CHECK_VERSION),
        {&PROTOCOL_VERSION, sizeof(PROTOCOL_VERSION)},
    );

    if (err != NO_ERROR) {
        renode_connection_close(conn);
        return err;
    }

    *renode = xmalloc(sizeof(renode_t));
    (*renode)->conn = conn;

    return NO_ERROR;
}

renode_error_t *renode_disconnect(renode_t **renode)
{
    assert(renode != NULL && *renode != NULL);

    return_error_if_fails(renode_connection_close((*renode)->conn));
    free(*renode);
    *renode = NULL;

    return NO_ERROR;
}

#define MAX_CALLBACK_COUNT 1024

typedef void (*raw_callback_t)(void *, void *);

static raw_callback_t callbacks[MAX_CALLBACK_COUNT];
static void *callback_user_data[MAX_CALLBACK_COUNT];
static int32_t callbacks_count;

static renode_error_t *register_callback(raw_callback_t callback, void *user_data, int32_t *ed)
{
    assert_msg(callbacks_count < MAX_CALLBACK_COUNT, "Cannot register any more callbacks");

    callbacks[callbacks_count] = callback;
    callback_user_data[callbacks_count] = user_data;

    *ed = callbacks_count;
    callbacks_count += 1;

    return NO_ERROR;
}

static renode_error_t *invoke_callback(api_command_t cmd, int32_t ed, const void *data, size_t size)
{
    switch(cmd)
    {
    case GPIO:
        assert_msg(ed < callbacks_count, "Tried to invoke callback for an invalid event descriptor");
        assert_msg(size == sizeof(renode_gpio_event_data_t), ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);
        renode_gpio_event_data_t event_data;
        memcpy(&event_data, data, sizeof(event_data));

        callbacks[ed](callback_user_data[ed], &event_data);
        return NO_ERROR;
    default:
        assert_msg(false, "Tried to invoke callback for an invalid command");
    }
    return create_fatal_error_static("Unreachable logic reached");
}

static renode_error_t *get_machine_handler(renode_connection_t *conn, const void *data, size_t size, void *ud)
{
    (void)conn;

    int32_t *id = ud;
    assert_msg(size == 4, ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);
    memcpy(id, data, 4);
    return NO_ERROR;
}

renode_error_t *renode_get_machine(renode_t *renode, const char *name, renode_machine_t **machine)
{
    int32_t id;
    uint32_t name_length = strlen(name);
    return_error_if_fails(renode_connection_send(renode->conn, generic_handler, &id,
        REQUEST_HEADER(GET_MACHINE),
        {&name_length, sizeof(name_length)},
        {name, name_length},
    ));

    assert_msg(id >= 0, "received invalid machine descriptor");

    *machine = xmalloc(sizeof(renode_machine_t));
    (*machine)->renode = renode;
    (*machine)->md = id;

    return NO_ERROR;
}

static const char *time_unit_to_string(renode_time_unit_t unit)
{
    switch (unit) {
    case TU_NANOSECONDS:
        return "ns";
    case TU_MICROSECONDS:
        return "us";
    case TU_MILLISECONDS:
        return "ms";
    case TU_SECONDS:
        return "s";
    }
    return "<unknown unit>";
}

renode_error_t *renode_create_time(uint64_t value, renode_time_unit_t unit, renode_time_t *time)
{
    uint64_t result;
    switch (unit) {
    case TU_NANOSECONDS:
    case TU_MICROSECONDS:
    case TU_MILLISECONDS:
    case TU_SECONDS:
        result = value * unit;
        if (result / unit != value) {
            return create_error(ERR_INVALID_ARGUMENT, "%"PRIu64"%s exceedes the maximum time value of %"PRIu64"ns", time, time_unit_to_string(unit), UINT64_MAX);
        }
        *time = result;
        return NO_ERROR;
    }
    return create_error(ERR_INVALID_ARGUMENT, "Invalid time unit: %d", unit);
}

uint64_t renode_time_to_time_unit(renode_time_t time, renode_time_unit_t unit)
{
    switch(unit) {
    case TU_NANOSECONDS:
    case TU_MICROSECONDS:
    case TU_MILLISECONDS:
    case TU_SECONDS:
        return time / unit;
    }
    assert_exit(!"Invalid time unit value");
}

double renode_time_to_seconds(renode_time_t time)
{
    return (double)time / TU_SECONDS;
}

static renode_error_t *get_instance_handler(renode_connection_t *conn, const void *response, size_t response_size, void *ud)
{
    (void)conn;

    message_payload_t header;
    const void *data;
    uint32_t data_size;

    return_error_if_fails(parse_response(response, response_size, &header, &data, &data_size));

    assert_msg(data_size == sizeof(int32_t), ERRMSG_UNEXPECTED_RESPONSE_PAYLOAD_SIZE);
    memcpy(ud, data, sizeof(int32_t));
    return NO_ERROR;
}

static renode_error_t *renode_get_instance_descriptor(renode_machine_t *machine, api_command_t api_command, const char *name, int32_t *instance_descriptor)
{
    uint32_t name_length = strlen(name);
    *instance_descriptor = -1;

    // ASSUMPTION: Obtaining an instance cannot generate side-effects
    return renode_connection_send(machine->renode->conn, get_instance_handler, instance_descriptor,
        REQUEST_HEADER(api_command),
        {instance_descriptor, sizeof(*instance_descriptor)},
        {&machine->md, sizeof(machine->md)},
        {&name_length, sizeof(name_length)},
        {name, name_length},
    );
}

renode_error_t *renode_run_for(renode_t *renode, renode_time_t time)
{
    assert(renode != NULL);

    return renode_connection_send(renode->conn, generic_handler, NULL,
        REQUEST_HEADER(RUN_FOR),
        {&time, sizeof(time)},
    );
}

static renode_error_t *current_time_handler(renode_connection_t *conn, const void *data, size_t size, void *ud)
{
    (void)conn;

    assert_fmsg(size == sizeof(uint64_t), "Expected %zu bytes, but received: %zu", sizeof(uint64_t), size);
    memcpy(ud, data, sizeof(uint64_t));
    return NO_ERROR;
}

renode_error_t *renode_get_current_time(renode_t *renode, renode_time_t *current_time)
{
    assert(renode != NULL);

    return renode_connection_send(renode->conn, generic_handler, current_time,
        REQUEST_HEADER(GET_TIME),
        {current_time, sizeof(*current_time)},
    );
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
} adc_operation_t;

typedef struct {
    struct __attribute__((packed)) {
        int32_t id;
        uint8_t command;
    } header;

    int32_t result_value;
} adc_command_t;

static renode_error_t *adc_handler(renode_connection_t *conn, const void *data, size_t size, void *ud)
{
    (void)conn;

    adc_command_t *cmd = ud;
    switch (cmd->header.command) {
    case GET_CHANNEL_COUNT:
    case GET_CHANNEL_VALUE:
        assert_fmsg(size == sizeof(int32_t), "Expected %zu bytes, but received: %zu", sizeof(int32_t), size);
        memcpy(&cmd->result_value, data, sizeof(int32_t));
        return NO_ERROR;
    case SET_CHANNEL_VALUE:
        return NO_ERROR; // Nothing to do - we only care about a successfull status
    default:
        // TODO: Maybe assert_exit instead? (This is most likely a programmer error)
        return create_fatal_error_static("Unknown ADC operation");
    }
}

renode_error_t *renode_get_adc_channel_count(renode_adc_t *adc, int32_t *count)
{
    adc_command_t cmd = {
        .header = {
            .id = adc->id,
            .command = GET_CHANNEL_COUNT,
        },
    };

    return_error_if_fails(renode_connection_send(adc->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(ADC),
        {&cmd, sizeof(cmd.header)},
    ));

    *count = cmd.result_value;
    return NO_ERROR;
}

renode_error_t *renode_get_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t *value)
{
    adc_command_t cmd = {
        .header = {
            .id = adc->id,
            .command = GET_CHANNEL_VALUE,
        },
    };

    return_error_if_fails(renode_connection_send(adc->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(ADC),
        {&cmd, sizeof(cmd.header)},
        {&channel, sizeof(channel)},
    ));

    *value = cmd.result_value;
    return NO_ERROR;
}

renode_error_t *renode_set_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t value)
{
    adc_command_t cmd = {
        .header = {
            .id = adc->id,
            .command = SET_CHANNEL_VALUE,
        },
    };

    return renode_connection_send(adc->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(ADC),
        {&cmd, sizeof(cmd.header)},
        {&channel, sizeof(channel)},
        {&value, sizeof(value)},
    );
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
} gpio_operation_t;

typedef struct {
    struct __attribute__((packed)) {
        int32_t id;
        int8_t command;
        int32_t number;
    } header;

    uint8_t state;
} gpio_command_t;

static renode_error_t *gpio_handler(renode_connection_t *conn, const void *data, size_t size, void *ud)
{
    (void)conn;

    gpio_command_t *cmd = ud;
    switch (cmd->header.command) {
    case GET_STATE:
        assert_fmsg(size == sizeof(uint8_t), "Expected %zu bytes, but received: %zu", sizeof(uint8_t), size);
        memcpy(&cmd->state, data, sizeof(uint8_t));
        return NO_ERROR;
    case SET_STATE:
    case REGISTER_EVENT:
        return NO_ERROR; // Nothing to do here - we only care about the successfull status
    default:
        // TODO: Maybe assert_exit instead? (This is most likely a programmer error)
        return create_fatal_error_static("Unknown GPIO operation");
    }
}

renode_error_t *renode_get_gpio_state(renode_gpio_t *gpio, int32_t id, bool *state)
{
    gpio_command_t cmd = {
        .header = {
            .id = gpio->id,
            .command = GET_STATE,
            .number = id,
        },
    };

    return_error_if_fails(renode_connection_send(gpio->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(GPIO),
        {&cmd.header, sizeof(cmd.header)},
    ));

    *state = cmd.state;
    return NO_ERROR;
}

renode_error_t *renode_set_gpio_state(renode_gpio_t *gpio, int32_t id, bool state)
{
    gpio_command_t cmd = {
        .header = {
            .id = gpio->id,
            .command = SET_STATE,
            .number = id,
        },
        .state = state,
    };

    return renode_connection_send(gpio->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(GPIO),
        {&cmd.header, sizeof(cmd.header)},
        {&cmd.state, sizeof(cmd.state)},
    );
}

struct gpio_callback_data
{
    bool current_state;
};

renode_error_t *renode_register_gpio_state_change_callback(renode_gpio_t *gpio, int32_t id, void *user_data, void (*callback)(void *, renode_gpio_event_data_t *))
{
    int32_t ed;
    return_error_if_fails(register_callback((raw_callback_t)callback, user_data, &ed));

    gpio_command_t cmd = {
        .header = {
            .id = gpio->id,
            .command = REGISTER_EVENT,
            .number = id,
        },
    };

    return renode_connection_send(gpio->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(GPIO),
        {&cmd.header, sizeof(cmd.header)},
        {&ed, sizeof(ed)},
    );
}

renode_error_t *renode_get_bus_context(renode_machine_t *machine, const char *name, renode_bus_context_t **ctx)
{
    int32_t id;
    return_error_if_fails(renode_get_instance_descriptor(machine, SYSTEM_BUS, name, &id));

    *ctx = xmalloc(sizeof(renode_bus_context_t));
    (*ctx)->machine = machine;
    (*ctx)->id = id;

    return NO_ERROR;
}

renode_error_t *renode_get_sysbus(renode_machine_t *machine, renode_bus_context_t **sysbus)
{
    return renode_get_bus_context(machine, "sysbus", sysbus);
}

renode_error_t *renode_get_byte_count(renode_access_width_t width, uint32_t count, uint32_t *byte_count)
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
            return create_error(ERR_INVALID_ARGUMENT, "Payload size exceeds %u bytes", UINT32_MAX);
        }
        *byte_count = result;
        return NO_ERROR;
    default:
        return create_error(ERR_INVALID_ARGUMENT, "Invalid bus access width: %d", width);
    }
}

typedef enum {
    SYSBUS_READ = 0,
    SYSBUS_WRITE = 1,
    SYSBUS_GET_NAME = 2,
} sysbus_operation_t;

static renode_error_t *get_bus_context_name_handler(renode_connection_t *conn, const void *response, size_t response_size, void *ud)
{
    (void)conn;

    message_payload_t header;
    const void *data;
    uint32_t data_size;

    return_error_if_fails(parse_response(response, response_size, &header, &data, &data_size));

    if (header.command != SYSTEM_BUS) {
        return create_fatal_error_static(ERRMSG_COMMAND_MISMATCH);
    }

    char **name = ud;
    *name = xmalloc(data_size + 1);
    memcpy(*name, data, data_size);
    (*name)[data_size] = '\0';
    return NO_ERROR;
}

renode_error_t *renode_get_bus_context_name(renode_bus_context_t *ctx, char **name)
{
    struct __attribute__((packed)) {
        int32_t id;
        uint8_t operation;
    } command_data;

    command_data.id = ctx->id;
    command_data.operation = SYSBUS_GET_NAME;

    // ASSUMPTION: Obtaining the name cannot generate side-effects
    return renode_connection_send(ctx->machine->renode->conn, get_bus_context_name_handler, name,
        REQUEST_HEADER(SYSTEM_BUS),
        {&command_data, sizeof(command_data)},
    );
}

typedef struct {
    struct __attribute__((packed)) {
        int32_t id;
        uint8_t operation;
        uint8_t access_width;
        uint64_t address;
        uint32_t data_count;
    } header;

    void *data;
    uint32_t data_size;
} sysbus_command_t;

static renode_error_t *sysbus_handler(renode_connection_t *conn, const void *data, size_t size, void *ud)
{
    (void)conn;

    sysbus_command_t *cmd = ud;
    switch (cmd->header.operation) {
    case SYSBUS_READ:
        assert_fmsg(size == cmd->data_size, "Expected to receive %zu bytes, but received %zu instead", cmd->data_size, size);
        memcpy(cmd->data, data, size);
        return NO_ERROR;
    case SYSBUS_WRITE:
        return NO_ERROR;
    default:
        // TODO: Maybe assert_exit instead? (This is most likely a programmer error)
        return create_fatal_error_static("Unknown sysbus operation");
    }
}

renode_error_t *renode_sysbus_read(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, void *buffer, uint32_t count)
{
    sysbus_command_t cmd = {
        .header = {
            .id = ctx->id,
            .operation = SYSBUS_READ,
            .access_width = width,
            .address = address,
            .data_count = count,
        },
        .data = buffer,
    };
    return_error_if_fails(renode_get_byte_count(width, count, &cmd.data_size));

    return renode_connection_send(ctx->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(SYSTEM_BUS),
        {&cmd.header, sizeof(cmd.header)},
    );
}

renode_error_t *renode_sysbus_write(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, const void *buffer, uint32_t count)
{
    sysbus_command_t cmd = {
        .header = {
            .id = ctx->id,
            .operation = SYSBUS_WRITE,
            .access_width = width,
            .address = address,
            .data_count = count,
        },
    };

    uint32_t data_bytes;
    return_error_if_fails(renode_get_byte_count(width, count, &data_bytes));

    return renode_connection_send(ctx->machine->renode->conn, generic_handler, &cmd,
        REQUEST_HEADER(SYSTEM_BUS),
        {&cmd.header, sizeof(cmd.header)},
        {buffer, data_bytes},
    );
}

static renode_error_t *parse_response(const void *response, size_t size, message_payload_t *header, const void **data, uint32_t *data_size)
{
    assert_fmsg(size >= sizeof(*header), "Expected at least %zu command data header bytes, but got only %zu", sizeof(*header), size);
    memcpy(header, response, sizeof(*header));

    response += sizeof(*header);
    size -= sizeof(*header);

    verbose_print("Incomming command: 0x%"PRIx16", message type: 0x%"PRIx8, header->command, header->type);

    switch(header->type) {
    case TYPE_REQUEST:
        return create_fatal_error_static("Current client implementation cannot service direct requests");
    case TYPE_SUCCESS:
    case TYPE_EVENT_REQUEST:
        *data = response;
        *data_size = size;
        return NO_ERROR;
    case TYPE_INVALID_COMMAND:
        return create_error_static(ERR_INVALID_COMMAND, "Unknown command");
    case TYPE_ERROR: {
        uint8_t err_code = header->command == 0x0 ? ERR_FATAL : ERR_COMMAND_FAILED;
        if (size > 0) {
            char *message = xmalloc(size + 1);
            memcpy(message, response, size);
            message[size] = '\0';
            return create_error_dynamic(err_code, message);
        } else {
            return create_error_static(err_code, "No error message provided");
        }
    }
    default:
        return create_fatal_error_static("Unexpected message type");
    }
}

static renode_error_t *generic_handler(renode_connection_t *conn, const void *response, size_t size, void *ud)
{
    message_payload_t header;
    const void *data = NULL;
    uint32_t data_size = 0;

    return_error_if_fails(parse_response(response, size, &header, &data, &data_size));

    if (header.type == TYPE_EVENT_REQUEST) {
        int32_t ed;
        assert_fmsg(sizeof(ed) <= data_size, "Expected at least %zu bytes of an event descriptor, but got only %zu", sizeof(ed), size);
        memcpy(&ed, data, sizeof(ed));
        return invoke_callback(header.command, ed, data + sizeof(ed), data_size - sizeof(ed));
    }

    switch (header.command) {
    case RUN_FOR:
        return NO_ERROR; // This command doesn't return any data (The success status means that run_for has finished)
    case GET_TIME:
        return current_time_handler(conn, data, data_size, ud);
    case GET_MACHINE:
        return get_machine_handler(conn, data, data_size, ud);
    case ADC:
        return adc_handler(conn, data, data_size, ud);
    case GPIO:
        return gpio_handler(conn, data, data_size, ud);
    case SYSTEM_BUS:
        return sysbus_handler(conn, data, data_size, ud);
    default:
        return create_fatal_error_static("Encountered a command without a response handler");
    }
}
