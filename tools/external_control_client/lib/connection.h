#pragma once

#include <stddef.h>

#include "common.h"

typedef struct renode_connection renode_connection_t;

typedef struct {
    const char *address;
    const char *port;
} renode_connection_config_t;

typedef struct {
    const void *data;
    size_t byte_count;
} renode_connection_transfer_t;

typedef renode_error_t *(*renode_connection_response_t)(renode_connection_t *conn, const void *response, size_t respones_size, void *ud);

renode_error_t *renode_connection_open(renode_connection_t **conn, const renode_connection_config_t *cfg);
renode_error_t *renode_connection_close(renode_connection_t *con);
void renode_connection_set_fatal_error_callback(renode_connection_t *conn, renode_fatal_error_callback_t cb, void *ud);

// Do not call directly - go through the `renode_connection_send` macro instead
renode_error_t *renode_connection_send_impl(renode_connection_t *conn, renode_connection_response_t cb, void *ud, const renode_connection_transfer_t *transfers, size_t count);

/**
 * Send N data buffers
 *
 * @param[in] conn renode_connection_t instance throug which the data should be sent
 * @param[in] cb callback to execute with on the response
 * @param[in] ud userdata pointer to be passed into the callback
 * @param[in] ... buffers that should be send. It is a variadic list of structures of type renode_connection_transfer_t
 *
 * Example:
 *
 * @code
 * uint8_t data[8] = ...;
 * uint32_t data_size = sizeof(data);
 * renode_connection_send(conn, NULL, response_handler,
 *     {&data_size, sizeof(data_size)},
 *     {data, data_size},
 * );
 * @endcode
 *
 * In the example 12 bytes will be sent in total (4 bytes of the `data_size` variable and the 8 bytes of the `data` buffer).
 * This function send all of the buffers as a single message, any subsequent calls to `renode_connection_send` will generate a new message.
 */
#define renode_connection_send(conn, cb, ud, ...) \
    renode_connection_send_impl( \
        (conn), (cb), (ud), (const renode_connection_transfer_t []) { __VA_ARGS__ }, \
        sizeof((const renode_connection_transfer_t []) { __VA_ARGS__ }) / sizeof(renode_connection_transfer_t) \
    )
