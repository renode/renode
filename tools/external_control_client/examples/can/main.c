//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <unistd.h>
#include <stdlib.h>
#include <pthread.h>

#include "renode_api.h"

uint8_t next_packet_to_send[MAX_CAN_FRAME_SIZE];
int next_packet_length;
uint32_t next_packet_id;
pthread_mutex_t next_packet_lock;

static void exit_with_usage_info(const char *argv0)
{
    fprintf(stderr,
        "Usage:\n"
        "  %s <PORT> <MACHINE_NAME> <CAN_NAME>\n",
        argv0);
    exit(EXIT_FAILURE);
}

static char *get_error_message(renode_error_t *error)
{
    if (error->message == NULL)
    {
        return "<no message>";
    }
    return error->message;
}

static int try_renode_disconnect(renode_t **renode)
{
    renode_error_t *error;
    if ((error = renode_disconnect(renode)) != NO_ERROR) {
        fprintf(stderr, "Disconnecting from Renode failed with: %s\n", get_error_message(error));
        return -1;
    }
    return 0;
}

typedef struct {
    char *machine_name;
    char *can_name;
} can_event_user_data;

void can_callback(void *user_data, renode_can_event_data_t *event_data)
{
    
    can_event_user_data *udata = (can_event_user_data *)user_data;
    printf("%s:%s can packet with length %d received:\n\t", udata->machine_name, udata->can_name, event_data->packet_length);


    printf("0x");
    for (int current_position = 0; current_position < event_data->packet_length; current_position++) {
        printf("%02x", event_data->packet[current_position]);
    }
    printf("\n");
    fflush(stdout);

    pthread_mutex_lock(&next_packet_lock);
    memcpy(&next_packet_to_send, &event_data->packet, event_data->packet_length);
    next_packet_id = event_data->packet_id;
    next_packet_length = event_data->packet_length;
    pthread_mutex_unlock(&next_packet_lock);
}

int main(int argc, char **argv)
{
    if (argc < 4) {
        exit_with_usage_info(argv[0]);
    }
    char *port_number_string = argv[1];
    char *machine_name = argv[2];
    char *can_name = argv[3];

    pthread_mutex_init(&next_packet_lock, NULL);

    // get Renode, machine and can instances
    renode_error_t *error;
    renode_t *renode;
    if ((error = renode_connect(port_number_string, &renode)) != NO_ERROR) {
        fprintf(stderr, "Connecting to Renode failed with: %s\n", get_error_message(error));
        goto fail;
    }

    renode_machine_t *machine;
    if ((error = renode_get_machine(renode, machine_name, &machine)) != NO_ERROR) {
        fprintf(stderr, "Getting '%s' machine object failed with: %s\n", machine_name, get_error_message(error));
        goto fail_renode;
    }

    renode_can_t *can;
    if ((error = renode_get_can(machine, can_name, &can)) != NO_ERROR) {
        fprintf(stderr, "Getting '%s' CAN object failed with: %s\n", can_name, get_error_message(error));
        goto fail_machine;
    }

    can_event_user_data user_data = (can_event_user_data){
            .machine_name = machine_name,
            .can_name = can_name,
            };

    if ((error = renode_register_can_callback(can, &user_data, can_callback)) != NO_ERROR) {
        fprintf(stderr, "Registering CAN event for peripheral '%s' failed with: '%s'\n", can_name, get_error_message(error));
        goto fail_can;
    }

    while(true){

        pthread_mutex_lock(&next_packet_lock);
        if (next_packet_length > 0)
        {

            printf("About to send can message");
            fflush(stdout);
            if((error = renode_send_can_message(can, &next_packet_to_send, next_packet_length, next_packet_id))) {
                fprintf(stderr, "send can message failed with: %s\n", get_error_message(error));
                goto fail_can;
            }
            next_packet_length = 0;
        }
        pthread_mutex_unlock(&next_packet_lock);
    }
    // clean up

    free(can);
    free(machine);
    if (try_renode_disconnect(&renode)) {
        exit(EXIT_FAILURE);
    }

    fflush(stdout);
    exit(EXIT_SUCCESS);

fail_can:
    free(can);
fail_machine:
    free(machine);
fail_renode:
    try_renode_disconnect(&renode);
    free(renode);
fail:
    renode_free_error(error);
    fflush(stdout);
    fflush(stderr);
    exit(EXIT_FAILURE);
}
