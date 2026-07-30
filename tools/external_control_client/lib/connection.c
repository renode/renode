//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netdb.h>
#include <sys/socket.h>
#include <unistd.h>
#include <pthread.h>

#include "connection.h"
#include "common.h"

typedef struct {
    pthread_mutex_t lock;
    pthread_cond_t cond;
    void *data;
    size_t data_size;
} channel_t;

static renode_error_t *channel_init(channel_t *c)
{
    int thread_error = pthread_mutex_init(&c->lock, NULL);
    if (thread_error != 0) {
        return create_fatal_error("Failed to create a channel mutex: %s", strerror(thread_error));
    }

    thread_error = pthread_cond_init(&c->cond, NULL);
    if (thread_error != 0) {
        pthread_mutex_destroy(&c->lock);
        return create_fatal_error("Failed to create a channel conditional variable: %s", strerror(thread_error));
    }

    c->data = NULL;
    c->data_size = 0;
    return NO_ERROR;
}

static void channel_destroy(channel_t *c)
{
    pthread_cond_destroy(&c->cond);
    pthread_mutex_destroy(&c->lock);
    free(c->data); // Free any unconsumed data
    *c = (channel_t){};
}

static void channel_get(channel_t *c, void **data, size_t *size)
{
    pthread_mutex_lock(&c->lock);
    while (c->data == NULL) {
        pthread_cond_wait(&c->cond, &c->lock);
    }

    *data = c->data;
    *size = c->data_size;
    c->data = NULL;
    c->data_size = 0;
    pthread_mutex_unlock(&c->lock);
}

static renode_error_t *channel_put(channel_t *c, void *data, size_t data_size)
{
    renode_error_t *err = NO_ERROR;
    pthread_mutex_lock(&c->lock);
    if (c->data != NULL) {
        err = create_fatal_error_static("Client received a new message without acknowledging a previous message, this is bug in the client or a protocol violation");
    }

    c->data = data;
    c->data_size = data_size;
    pthread_cond_signal(&c->cond);
    pthread_mutex_unlock(&c->lock);
    return err;
}

static renode_error_t *write_or_fail(int socket_fd, const void *data, size_t count)
{
    ssize_t sent;
    do {
        sent = write(socket_fd, data, count);
        if (sent <= 0) {
            if (errno == EINTR) {
                continue;
            } else {
                break;
            }
        }

        data += sent;
        count -= sent;
    } while (count > 0);

    if (sent == 0) {
        return create_fatal_error_static("Attempted to write to a closed socket");
    }
    if (sent < 0) {
        return create_error(ERR_FATAL, "Socket write failed (%s)", strerror(errno));
    }
    return NO_ERROR;
}

static renode_error_t *read_or_fail(int socket_fd, void *buffer, size_t count)
{
    ssize_t received;
    do {
        received = read(socket_fd, buffer, count);
        if (received <= 0) {
            if (errno == EINTR) {
                continue;
            } else {
                break;
            }
        }

        buffer += received;
        count -= received;
    } while (count > 0);

    if (received == 0) {
        return create_fatal_error_static("Attempted to read from a closed socket");
    }
    if (received < 0) {
        return create_error(ERR_FATAL, "Socket read failed (%s)", strerror(errno));
    }
    return NO_ERROR;
}

struct renode_connection {
    renode_fatal_error_callback_t fatal_error_callback;
    void *fatal_error_ud;

    int socket_fd;

    pthread_t receiver_thread;

    pthread_mutex_t client_request_lock;
    channel_t client_responses;

    // TODO: Implement
    // channel_t server_requests;
};

static void check_and_handle_async_error(renode_connection_t *conn, renode_error_t *err)
{
    if (err == NO_ERROR) {
        return;
    }

    if (conn->fatal_error_callback) {
        conn->fatal_error_callback(conn->fatal_error_ud, err);
    } else {
        fprintf(stderr, "Fatal error encountered: %s\n", err->message);
        fflush(stderr);
    }
    renode_free_error(err);
    exit(EXIT_FAILURE);
}

static void *receiver_thread(void *ud)
{
    renode_connection_t *conn = ud;

    while (true) {
        uint8_t temp;
        ssize_t received = recv(conn->socket_fd, &temp, sizeof(temp), MSG_PEEK);
        if (received < 0) {
            check_and_handle_async_error(conn, create_fatal_error("Socket reception error: %s (socket_fd = %d)", strerror(errno), conn->socket_fd));
        }

        if (received == 0) {
            return NULL; // Socket has been closed, exit the thread
        }

        uint32_t message_size;
        check_and_handle_async_error(conn, read_or_fail(conn->socket_fd, &message_size, sizeof(message_size)));

        void *buffer = malloc(message_size);
        if (buffer == NULL) {
            check_and_handle_async_error(conn, create_fatal_error_static("Failed to allocate a buffer to hold the incomming message"));
        }
        check_and_handle_async_error(conn, read_or_fail(conn->socket_fd, buffer, message_size));
        check_and_handle_async_error(conn, channel_put(&conn->client_responses, buffer, message_size));
    }
}

renode_error_t *renode_connection_open(renode_connection_t **conn, const renode_connection_config_t *cfg)
{
    assert(cfg && cfg->address && cfg->port);

    struct addrinfo  hints;
    struct addrinfo  *results, *rp;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;     /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM; /* TCP socket */
    hints.ai_protocol = 0;           /* Any protocol */
    hints.ai_flags = 0;

    int error = getaddrinfo(cfg->address, cfg->port, &hints, &results);
    assert_fmsg(!error, "Unable to find the server: %s", gai_strerror(error));

    int socket_fd = -1;
    for (rp = results; rp != NULL; rp = rp->ai_next) {

        socket_fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);

        if (socket_fd == -1) {
            verbose_print("`socket` failed: %s", strerror(errno));
            continue;
        }

        if (connect(socket_fd, rp->ai_addr, rp->ai_addrlen) == -1) {
            verbose_print("`connect` failed: %s", strerror(errno));
            close(socket_fd);
            continue;
        }

        renode_connection_t *result = xmalloc(sizeof(renode_connection_t));
        result->socket_fd = socket_fd;
        result->fatal_error_callback = NULL;
        result->fatal_error_ud = NULL;

        pthread_mutexattr_t mutex_attr;
        pthread_mutexattr_init(&mutex_attr);
        pthread_mutexattr_settype(&mutex_attr, PTHREAD_MUTEX_RECURSIVE);
        int thread_error = pthread_mutex_init(&result->client_request_lock, &mutex_attr);
        pthread_mutexattr_destroy(&mutex_attr);

        if (thread_error != 0) {
            close(result->socket_fd);
            free(result);
            return create_fatal_error("Failed to create a mutex: %s", strerror(thread_error));
        }

        renode_error_t *channel_err = channel_init(&result->client_responses);
        if (channel_err != NO_ERROR) {
            close(result->socket_fd);
            pthread_mutex_destroy(&result->client_request_lock);
            free(result);
            return channel_err;
        }

        thread_error = pthread_create(&result->receiver_thread, NULL, receiver_thread, result);
        if (thread_error != 0) {
            close(result->socket_fd);
            pthread_mutex_destroy(&result->client_request_lock);
            channel_destroy(&result->client_responses);
            free(result);
            return create_fatal_error("Failed to create the RX thread: %s", strerror(thread_error));
        }

        *conn = result;
        freeaddrinfo(results);
        return NO_ERROR;
    }

    freeaddrinfo(results);
    return create_error(ERR_FATAL, "Failed to connect to a Renode external API control server at %s:%s."
        "Make sure the server in Renode has been started with: `" SERVER_START_COMMAND " %s` and the port is accessible to this application",
        cfg->address, cfg->port, cfg->port);
}

renode_error_t *renode_connection_close(renode_connection_t *con)
{
    assert(con);

    // `shutdown` is called to interrupt the `recv` call in the RX thread
    shutdown(con->socket_fd, SHUT_RDWR);
    pthread_join(con->receiver_thread, NULL);
    close(con->socket_fd);
    pthread_mutex_destroy(&con->client_request_lock);
    channel_destroy(&con->client_responses);
    free(con);

    return NO_ERROR;
}

void renode_connection_set_fatal_error_callback(renode_connection_t *conn, renode_fatal_error_callback_t cb, void *ud)
{
    conn->fatal_error_callback = cb;
    conn->fatal_error_ud = ud;
}

renode_error_t *renode_connection_send_impl(renode_connection_t *conn, renode_connection_response_t cb, void *ud, const renode_connection_transfer_t *transfers, size_t count)
{
    renode_error_t *err = NO_ERROR;

    pthread_mutex_lock(&conn->client_request_lock); // Only 1 thread can start a request chain

    for(size_t i = 0; i < count; i++) {
        // Write the request chunks
        err = write_or_fail(conn->socket_fd, transfers[i].data, transfers[i].byte_count);
        if (err != NO_ERROR) {
            goto release_locks;
        }
    }

    // Wait for a response from the server
    void *data;
    size_t size;
    channel_get(&conn->client_responses, &data, &size);

    // Handle the response - while holding the request_lock to enable nested requests
    err = cb(conn, data, size, ud);

    free(data);

release_locks:
    pthread_mutex_unlock(&conn->client_request_lock);
    return err;
}
