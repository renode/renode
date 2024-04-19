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

#include "renode_api.h"

// TODO: Move to internal header
struct renode {
    int socket_fd;
};

#define SERVER_START_COMMAND "emulation CreateExternalControlServer \"<NAME>\""
#define SOCKET_INVALID -1

// TODO: return error_t* instead of exiting.
#define unlikely(x) __builtin_expect(!!(x), 0)
#define assert(x) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); exit(EXIT_FAILURE); } } while (0)
#define assert_msg(x, ...) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); fprintf(stderr, __VA_ARGS__); exit(EXIT_FAILURE); } } while (0)

// This is supposed to exit cause it's a fatal issue within the library code.
#define assert_exit(x) do { if (unlikely(!(x))) { fprintf(stderr, "Assert not met in %s:%d: %s\n", __FILE__, __LINE__, #x); exit(EXIT_FAILURE); } } while (0)

typedef enum {
    CURRENT_TIME,
    RUN_FOR,
} api_command_t;

error_t *renode_connect(const char *port, renode_t **renode)
{
    int              sfd, s;
    struct addrinfo  hints;
    struct addrinfo  *result, *rp;

    assert(port != NULL && renode != NULL);

    /* Obtain address(es) matching host/port. */

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;    /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM; /* TCP socket */
    hints.ai_flags = 0;
    hints.ai_protocol = 0;          /* Any protocol */

    s = getaddrinfo("localhost", port, &hints, &result);
    if (s != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(s));
        exit(EXIT_FAILURE);  // TODO: return error_t*
    }

    /* getaddrinfo() returns a list of address structures.
        Try each address until we successfully connect(2).
        If socket(2) (or connect(2)) fails, we (close the socket
        and) try the next address. */

    for (rp = result; rp != NULL; rp = rp->ai_next) {
        sfd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (sfd == -1)
            continue;

        if (connect(sfd, rp->ai_addr, rp->ai_addrlen) != -1)
            break;                  /* Success */

        close(sfd);
    }

    freeaddrinfo(result);           /* No longer needed */

    if (rp == NULL) {               /* No address succeeded */
        fprintf(stderr,
            "Failed to connect to the server using port %s.\n"
            "Make sure the server in Renode has been started with: `" SERVER_START_COMMAND " %s`\n",
            port, port);
        exit(EXIT_FAILURE);  // TODO: return error_t*
    }

    *renode = calloc(1, sizeof(renode_t));
    (*renode)->socket_fd = sfd;

    return NO_ERROR;
};

error_t *renode_disconnect(renode_t **renode)
{
    assert(renode != NULL && *renode != NULL);

    close((*renode)->socket_fd);
    free(*renode);
    *renode = NULL;

    return NO_ERROR;
}

// TODO: Use htonl or maybe always convert to little-endian?
//       Maybe add #abort if compiled on big-endian machine?
//       Perhaps we're safe without any conversions because we always run on the same machine as Renode?
static inline uint32_t add_uint(uint8_t *dest, size_t dest_size, uint64_t value, uint8_t size)
{
    assert_exit(dest_size >= size);
    memcpy(dest, &value, size);
    return size;
}

static inline uint32_t add_bytes(uint8_t *dest, size_t dest_size, const uint8_t *bytes, uint32_t size, bool prepend_data_size)
{
    assert_exit(prepend_data_size ? dest_size >= size + sizeof(size) : dest_size >= size);

    uint32_t added_bytes = 0;
    if (prepend_data_size) {
        added_bytes += add_uint(dest, dest_size, size, sizeof(size));
    }

    memcpy(dest + added_bytes, bytes, size);
    return added_bytes + size;
}

error_t *renode_send_command(renode_t *renode, api_command_t api_command, const uint8_t *data, uint32_t data_size)
{
    #define BUFFER_SIZE 500

    // `api_command` should be 1B non-negative integer.
    assert_exit(renode != NULL && api_command >= 0 && api_command < 0xFF && data_size < BUFFER_SIZE);

    #define MAGIC_AND_COMMAND_SIZE 3
    #define MAGIC1 'R'
    #define MAGIC2 'E'

    uint8_t buffer[BUFFER_SIZE + MAGIC_AND_COMMAND_SIZE] = { MAGIC1, MAGIC2, api_command };
    uint32_t added_bytes = 3;

    added_bytes += add_bytes(&buffer[added_bytes], BUFFER_SIZE, data, data_size, /* prepend_data_size: */ true);

    if (write(renode->socket_fd, buffer, added_bytes) != added_bytes) {
        fprintf(stderr, "partial/failed write\n");
        exit(EXIT_FAILURE);  // TODO
    }

    return NO_ERROR;
}

error_t *renode_receive_byte(renode_t *renode, uint8_t *value)
{
    ssize_t nread = read(renode->socket_fd, value, 1);
    if (nread == -1) {
        perror("read");
        exit(EXIT_FAILURE);  // TODO
    }
    return NO_ERROR;
}

typedef enum {
    COMMAND_FAILED,
    FATAL_ERROR,
    INVALID_COMMAND,
    SUCCESS_WITH_DATA,
    SUCCESS_WITHOUT_DATA,
} return_code_t;

#define return_error_if_fails(function) do { if ((error = (function)) != NO_ERROR) return error; } while (0)

error_t *renode_receive_response(renode_t *renode, api_command_t expected_command, uint8_t *data_buffer, uint32_t buffer_size, uint32_t *data_size)
{
    error_t *error;
    *data_size = 0;

    uint8_t return_code;
    return_error_if_fails(renode_receive_byte(renode, &return_code));

    // TODO: Nicely handle errors and implement SUCCESS_WITH_DATA.
    assert_msg(return_code == SUCCESS_WITHOUT_DATA, "invalid return code: %" PRIu8 "\n", return_code);

    uint8_t command;
    return_error_if_fails(renode_receive_byte(renode, &command));
    assert_msg(command == (uint8_t)expected_command, "received response for command %" PRIu8 " but expected %" PRIu8 "\n", command, expected_command);

    // TODO: Receive data
    (void)data_buffer;
    (void)buffer_size;

    return NO_ERROR;
}

error_t *renode_execute_command(renode_t *renode, api_command_t api_command, void *data_buffer, uint32_t buffer_size, uint32_t sent_data_size, uint32_t *received_data_size)
{
    assert(buffer_size >= sent_data_size);
    error_t *error;

    return_error_if_fails(renode_send_command(renode, api_command, data_buffer, sent_data_size));

    uint32_t ignored_data_size;
    return_error_if_fails(renode_receive_response(renode, api_command, data_buffer, buffer_size, received_data_size == NULL ? &ignored_data_size : received_data_size));

    return NO_ERROR;
}

struct run_for_out {
    uint64_t microseconds;
};

error_t *run_for(renode_t *renode, time_unit_t unit, uint64_t value)
{
    assert(renode != NULL && value < UINT64_MAX / unit);

    struct run_for_out data;
    switch (unit) {
        case TU_MICROSECONDS:
        case TU_MILLISECONDS:
        case TU_SECONDS:
            // The enum values are equal to 1 `unit` expressed in microseconds.
            data.microseconds = value * unit;
            break;
        default:
            assert_msg(false, "Invalid unit: %d\n", unit);
    }

    uint32_t data_size = sizeof(data) / sizeof(uint8_t);
    return renode_execute_command(renode, RUN_FOR, &data, data_size, data_size, NULL);
}
