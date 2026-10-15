//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//

// Carries the external control protocol to the Renode instance that runs in this process through librenode.
// A request from the client runs on the calling thread. A request from Renode runs on the Renode thread that
// sends it, and the client responds before that thread continues.

#include <pthread.h>
#include <string.h>

#include "librenode.h"

#include "connection.h"

struct renode_connection {
    RenodeExternalControl *endpoint;
    renode_server_request_t request_callback;
    void *request_user_data;

    pthread_mutex_t lifecycle_lock;
    bool disposed;
    int active_handler_count;

    // Only one thread at a time starts a request chain, because Renode commands such as `RunFor` are not safe
    // to run concurrently.
    pthread_mutex_t client_request_lock;
};

// A request from Renode that a thread handles.
typedef struct {
    renode_connection_t *connection;
    RenodeExternalControlTransactionToken *transaction_token;
} renode_request_t;

static _Thread_local renode_request_t *current_renode_request;

// The socket transport writes each transfer to the socket separately, but librenode takes a message as one buffer, so
// we concatenate the transfers into a new buffer, which the caller frees.
static renode_error_t *concatenate_transfers(const renode_connection_transfer_t *transfers, size_t count, uint8_t **message, uint32_t *size)
{
    size_t total = 0;
    for (size_t i = 0; i < count; i++) {
        assert_msg(transfers[i].byte_count <= UINT32_MAX - total, "Transfer buffer size overflow");
        total += transfers[i].byte_count;
    }

    *message = xmalloc(total);
    size_t offset = 0;
    for (size_t i = 0; i < count; i++) {
        memcpy(*message + offset, transfers[i].data, transfers[i].byte_count);
        offset += transfers[i].byte_count;
    }
    *size = (uint32_t)total;
    return NO_ERROR;
}

static bool is_handling_renode_request(renode_connection_t *connection)
{
    return current_renode_request != NULL && current_renode_request->connection == connection;
}

static void on_renode_request(void *context, const uint8_t *message, uint32_t size, RenodeExternalControlTransactionToken *transaction_token)
{
    renode_connection_t *connection = context;
    renode_request_t request = {
        .connection = connection,
        .transaction_token = transaction_token,
    };

    pthread_mutex_lock(&connection->lifecycle_lock);
    connection->active_handler_count += 1;
    pthread_mutex_unlock(&connection->lifecycle_lock);

    renode_request_t *outer_request = current_renode_request;
    current_renode_request = &request;
    // `renode_connection_send_response_impl` ignores the message ID, so any value works.
    renode_error_t *error = connection->request_callback(connection, 0, message, size, connection->request_user_data);
    current_renode_request = outer_request;

    pthread_mutex_lock(&connection->lifecycle_lock);
    connection->active_handler_count -= 1;
    pthread_mutex_unlock(&connection->lifecycle_lock);

    if (error != NO_ERROR) {
        fprintf(stderr, "Request handler failed with: %s\n", error->message);
        fflush(stderr);
        renode_free_error(error);
    }
}

renode_error_t *renode_connection_open(renode_connection_t **conn, const renode_connection_config_t *cfg)
{
    assert(cfg);

    renode_connection_t *result = xmalloc(sizeof(renode_connection_t));
    result->request_callback = cfg->request_callback;
    result->request_user_data = cfg->server_request_ud;
    result->disposed = false;
    result->active_handler_count = 0;

    pthread_mutexattr_t mutex_attributes;
    pthread_mutexattr_init(&mutex_attributes);
    pthread_mutexattr_settype(&mutex_attributes, PTHREAD_MUTEX_RECURSIVE);
    int thread_error = pthread_mutex_init(&result->client_request_lock, &mutex_attributes);
    pthread_mutexattr_destroy(&mutex_attributes);
    if (thread_error != 0) {
        free(result);
        return create_fatal_error("Failed to create a mutex: %s", strerror(thread_error));
    }

    thread_error = pthread_mutex_init(&result->lifecycle_lock, NULL);
    if (thread_error != 0) {
        pthread_mutex_destroy(&result->client_request_lock);
        free(result);
        return create_fatal_error("Failed to create a mutex: %s", strerror(thread_error));
    }

    RenodeStatus status = renode_external_control_open(cfg->name, on_renode_request, result, &result->endpoint);
    if (status != RENODE_SUCCESS) {
        // Renode sends no request before the open succeeds, so no handler uses `result`.
        pthread_mutex_destroy(&result->lifecycle_lock);
        pthread_mutex_destroy(&result->client_request_lock);
        free(result);
        return create_fatal_error("Failed to open an external control endpoint, librenode returned %d", status);
    }

    *conn = result;
    return NO_ERROR;
}

static renode_error_t *renode_connection_close_impl(renode_connection_t *connection)
{
    pthread_mutex_lock(&connection->lifecycle_lock);
    if (connection->active_handler_count > 0) {
        pthread_mutex_unlock(&connection->lifecycle_lock);
        return create_error_static(ERR_CONNECTION_BUSY, "Cannot close a connection while handlers are running");
    }

    if (connection->disposed) {
        pthread_mutex_unlock(&connection->lifecycle_lock);
        return create_error_static(ERR_FATAL, "This Renode connection has already been closed");
    }

    connection->disposed = true;
    pthread_mutex_unlock(&connection->lifecycle_lock);

    // Waits for a request chain on another thread to end.
    pthread_mutex_lock(&connection->client_request_lock);
    RenodeStatus status = renode_external_control_close(connection->endpoint);
    pthread_mutex_unlock(&connection->client_request_lock);

    pthread_mutex_destroy(&connection->client_request_lock);
    pthread_mutex_destroy(&connection->lifecycle_lock);
    free(connection);

    if (status != RENODE_SUCCESS) {
        return create_fatal_error("Failed to close the external control endpoint, librenode returned %d", status);
    }
    return NO_ERROR;
}

renode_error_t *renode_connection_close(renode_connection_t *conn, bool blocking)
{
    assert(conn);

    renode_error_t *error;
    while ((error = renode_connection_close_impl(conn)) != NO_ERROR) {
        if (!blocking || error->code != ERR_CONNECTION_BUSY) {
            return error;
        }
        renode_free_error(error);
    }
    return NO_ERROR;
}

void renode_connection_set_fatal_error_callback(renode_connection_t *conn, renode_fatal_error_callback_t cb, void *ud)
{
    // The socket transport calls this callback for errors on its receiver thread. This transport has no threads of
    // its own, so it never calls it.
    (void)conn;
    (void)cb;
    (void)ud;
}

typedef struct {
    renode_connection_t *connection;
    renode_connection_response_t callback;
    void *user_data;
    renode_error_t *error;
} pending_response_t;

// Response handler that `renode_connection_send_request_impl` passes to `renode_external_control_request`.
static void on_renode_response(void *context, const uint8_t *message, uint32_t size)
{
    pending_response_t *response = context;
    response->error = response->callback(response->connection, message, size, response->user_data);
}

renode_error_t *renode_connection_send_request_impl(renode_connection_t *conn, renode_connection_response_t cb, void *ud, const renode_connection_transfer_t *transfers, size_t count)
{
    pthread_mutex_lock(&conn->lifecycle_lock);
    bool disposed = conn->disposed;
    pthread_mutex_unlock(&conn->lifecycle_lock);
    if (disposed) {
        return create_fatal_error_static("This Renode connection has been disposed of");
    }

    uint8_t *message;
    uint32_t size;
    return_error_if_fails(concatenate_transfers(transfers, count, &message, &size));

    // A request made while handling a request from Renode is a part of Renode's request chain.
    bool starts_request_chain = !is_handling_renode_request(conn);
    if (starts_request_chain) {
        pthread_mutex_lock(&conn->client_request_lock);
    }

    pending_response_t response = {
        .connection = conn,
        .callback = cb,
        .user_data = ud,
        .error = NO_ERROR,
    };
    RenodeStatus status = renode_external_control_request(conn->endpoint, message, size, on_renode_response, &response);

    if (starts_request_chain) {
        pthread_mutex_unlock(&conn->client_request_lock);
    }
    free(message);

    if (status != RENODE_SUCCESS) {
        return create_fatal_error("External control request failed, librenode returned %d", status);
    }
    return response.error;
}

renode_error_t *renode_connection_send_response_impl(renode_connection_t *conn, uint16_t id, const renode_connection_transfer_t *transfers, size_t count)
{
    // Responses go to the request that this thread handles, so the message ID is not needed.
    (void)id;
    assert_msg(is_handling_renode_request(conn), "Only a response to a request from Renode that this thread handles can be sent");

    uint8_t *message;
    uint32_t size;
    return_error_if_fails(concatenate_transfers(transfers, count, &message, &size));

    RenodeStatus status = renode_external_control_respond(current_renode_request->transaction_token, message, size);
    free(message);

    if (status != RENODE_SUCCESS) {
        return create_fatal_error("External control response failed, librenode returned %d", status);
    }
    return NO_ERROR;
}
