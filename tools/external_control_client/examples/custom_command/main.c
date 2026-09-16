//
//  Copyright (c) 2010-2026 Antmicro
//
//  This file is licensed under MIT License.
//  Full license text is available in 'licenses/MIT.txt' file.
//
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "renode_api.h"

static void exit_with_usage_info(const char *argv0)
{
    fprintf(stderr,
            "Usage:\n"
            "  %s <PORT>\n",
            argv0);
    exit(EXIT_FAILURE);
}

static char *get_error_message(renode_error_t *error)
{
    if(error->message == NULL) {
        return "<no message>";
    }
    return error->message;
}

static int try_renode_disconnect(renode_t **renode)
{
    renode_error_t *error;
    if((error = renode_disconnect(renode)) != NO_ERROR) {
        fprintf(stderr, "Disconnecting from Renode failed with: %s\n", get_error_message(error));
        fflush(stderr);
        return -1;
    }
    return 0;
}

static void strrev(char *start, char *end)
{
    while(start < end) {
        char t = *start;
        *start = *end;
        *end = t;
        start++;
        end--;
    }
}

renode_custom_command_response_data_t * custom_command_callback(void *user_data, renode_custom_command_event_data_t *event_data)
{
    (void)user_data;
    renode_custom_command_response_data_t * ret = malloc(sizeof(renode_custom_command_response_data_t) + strlen(event_data->command) + 1);

    uint64_t microseconds = renode_time_to_time_unit(event_data->time, TU_MICROSECONDS);
    printf("Received custom command '%s' at %" PRIu64 " us\n", event_data->command, microseconds);


    if(strstr(event_data->command, "demo ping") == event_data->command) {
        ret->command_valid = true;
        strcpy(ret->response_string, "demo pong");
    } else if(strstr(event_data->command, "demo rev ") == event_data->command) {
        size_t first_char_index = sizeof("demo rev");
        size_t last_char_index = strlen(event_data->command) - 1;

        ret->command_valid = true;
        strcpy(ret->response_string, event_data->command);
        strrev(ret->response_string + first_char_index, ret->response_string + last_char_index);
    } else {
        ret->command_valid = false;
        strcpy(ret->response_string, "Unknown command");
    }
    fflush(stdout);

    return ret;
}

int main(int argc, char **argv)
{
    if(argc != 2) {
        exit_with_usage_info(argv[0]);
    }
    char *port = argv[1];


    renode_error_t *error;
    renode_t *renode;
    if((error = renode_connect(port, &renode)) != NO_ERROR) {
        fprintf(stderr, "Connecting to Renode failed with: %s\n", get_error_message(error));
        goto fail;
    }
    if((error = renode_register_custom_command_callback(renode, NULL, custom_command_callback)) != NO_ERROR) {
        fprintf(stderr, "Registering custom command callback failed with: %s\n", get_error_message(error));
        goto fail_renode;
    }

    while(true) { }

    //  Exit cleanup
    if(try_renode_disconnect(&renode)) {
        exit(EXIT_FAILURE);
    }
    exit(EXIT_SUCCESS);

    //  Failure cleanup
fail_renode:
    try_renode_disconnect(&renode);
fail:
    renode_free_error(error);
    fflush(stdout);
    fflush(stderr);
    exit(EXIT_FAILURE);
}
