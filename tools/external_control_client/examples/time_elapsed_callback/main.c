//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <inttypes.h>

#include "renode_api.h"

static void exit_with_usage_info(const char *argv0)
{
    fprintf(stderr,
        "Usage:\n"
        "  %s <PORT> <TIME_EVENTS_COUNT>\n",
        argv0);
    exit(EXIT_FAILURE);
}

static char *get_error_message(renode_error_t *error)
{
    if (error->message == NULL) {
        return "<no message>";
    }
    return error->message;
}

static void try_renode_disconnect(renode_t **renode)
{
    renode_error_t *error = renode_disconnect(renode);
    if (error != NO_ERROR) {
        fprintf(stderr, "Failed to disconnect from Renode: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }
}

static pthread_mutex_t time_elapsed_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t time_elapsed_cond = PTHREAD_COND_INITIALIZER;
static volatile bool time_elapsed_flag = false;

static void time_callback(void *user_data, renode_time_t *timestamp)
{
    printf("%s: %fs\n", (const char *)user_data, renode_time_to_seconds(*timestamp));

    pthread_mutex_lock(&time_elapsed_lock);
    time_elapsed_flag = true;
    pthread_cond_signal(&time_elapsed_cond);
    pthread_mutex_unlock(&time_elapsed_lock);
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        exit_with_usage_info(argv[0]);
    }

    uint64_t times = 1;
    times = strtoull(argv[2], NULL, /* base: */ 0);
    if (errno != 0) {
        perror("conversion to uint64_t value");
        exit(EXIT_FAILURE);
    }

    renode_error_t *error;
    renode_t *renode;
    if ((error = renode_connect(argv[1], &renode)) != NO_ERROR) {
        fprintf(stderr, "Connecting to Renode failed with: %s\n", get_error_message(error));
        goto fail;
    }

    const char *user_data = "Elapsed virtual time";
    if ((error = renode_register_time_elapsed_callback(renode, (void *)user_data, time_callback)) != NO_ERROR) {
        fprintf(stderr, "Registering callback failed with: %s\n", get_error_message(error));
        goto fail_renode;
    }

    for(; times > 0; times--) {
        pthread_mutex_lock(&time_elapsed_lock);
        while (!time_elapsed_flag) {
            pthread_cond_wait(&time_elapsed_cond, &time_elapsed_lock);
        }
        time_elapsed_flag = false;
        pthread_mutex_unlock(&time_elapsed_lock);
    }

    try_renode_disconnect(&renode);
    exit(EXIT_SUCCESS);

fail_renode:
    try_renode_disconnect(&renode);
fail:
    renode_free_error(error);
    exit(EXIT_FAILURE);
}
