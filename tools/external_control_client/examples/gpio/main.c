//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "renode_api.h"

void exit_with_usage_info(const char *argv0)
{
    fprintf(stderr,
        "Usage:\n"
        "  %s <PORT> <MACHINE_NAME> <GPIO_NAME> <NUMBER> [true|false|event]",
        argv0);
    exit(EXIT_FAILURE);
}

char *get_error_message(renode_error_t *error)
{
    if (error->message == NULL)
    {
        return "<no message>";
    }
    return error->message;
}

int try_renode_disconnect(renode_t **renode)
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
    char *gpio_name;
    int pin_no;
    bool run;
} gpio_event_user_data;

void gpio_callback(void *user_data, renode_gpio_event_data_t *event_data)
{
    gpio_event_user_data *udata = (gpio_event_user_data *)user_data;
    printf("%s: GPIO #%d in %s %sset", udata->machine_name, udata->pin_no, udata->gpio_name, event_data->state ? "" : "un");
    printf(" at %lu us\n", event_data->timestamp_us);
    udata->run = false;
}

int main(int argc, char **argv)
{
    if (argc < 5 || 6 < argc) {
        exit_with_usage_info(argv[0]);
    }
    char *machine_name = argv[2];
    char *gpio_name = argv[3];
    bool set = argc == 6;
    bool state = false;
    bool wait_for_event = false;

    char *endptr;
    // base=0 tries to figure out the number's base automatically.
    int32_t number = strtol(argv[4], &endptr, /* base: */ 0);
    if (errno != 0) {
        perror("conversion to uint32_t value");
        exit(EXIT_FAILURE);
    }

    if (endptr == argv[4] || *endptr != '\0') {
        exit_with_usage_info(argv[0]);
    }

    if (set)
    {
        if (strcmp(argv[5], "true") != 0 && strcmp(argv[5], "false") != 0 && strcmp(argv[5], "event")) {
            exit_with_usage_info(argv[0]);
        }
        state = argv[5][0] == 't';
        wait_for_event = argv[5][0] == 'e';
    }

    // get Renode, machine and GPIO instances

    renode_error_t *error;
    renode_t *renode;
    if ((error = renode_connect(argv[1], &renode)) != NO_ERROR) {
        fprintf(stderr, "Connecting to Renode failed with: %s\n", get_error_message(error));
        goto fail;
    }

    renode_machine_t *machine;
    if ((error = renode_get_machine(renode, machine_name, &machine)) != NO_ERROR) {
        fprintf(stderr, "Getting '%s' machine object failed with: %s\n", machine_name, get_error_message(error));
        goto fail_renode;
    }

    renode_gpio_t *gpio;
    if ((error = renode_get_gpio(machine, gpio_name, &gpio)) != NO_ERROR) {
        fprintf(stderr, "Getting '%s' ADC object failed with: %s\n", gpio_name, get_error_message(error));
        goto fail_machine;
    }

    // perform get/set

    if (wait_for_event) {
        gpio_event_user_data user_data = (gpio_event_user_data){
            .machine_name = machine_name,
            .gpio_name = gpio_name,
            .pin_no = number,
            .run = true
        };

        if ((error = renode_register_gpio_state_change_callback(gpio, number, &user_data, gpio_callback)) != NO_ERROR) {
            fprintf(stderr, "Registering event on pin #%d for '%s' failed with: %s\n", number, gpio_name, get_error_message(error));
            goto fail_gpio;
        }

        while (user_data.run) {
            if ((error = renode_run_for(renode, TU_SECONDS, 60)) != NO_ERROR) {
                fprintf(stderr, "Run for failed with: %s\n", get_error_message(error));
                goto fail_gpio;
            }
        }
    } else if (set) {
        if ((error = renode_set_gpio_state(gpio, number, state)) != NO_ERROR) {
            fprintf(stderr, "Setting state on pin #%d for '%s' failed with: %s\n", number, gpio_name, get_error_message(error));
            goto fail_gpio;
        }

        printf("GPIO set to: %s\n", state ? "true" : "false");
    } else {
        if ((error = renode_get_gpio_state(gpio, number, &state)) != NO_ERROR) {
            fprintf(stderr, "Getting state on pin #%d for '%s' failed with: %s\n", number, gpio_name, get_error_message(error));
            goto fail_gpio;
        }

        printf("GPIO state: %s\n", state ? "true" : "false");
    }

    // clean up

    free(gpio);
    free(machine);
    if (try_renode_disconnect(&renode)) {
        exit(EXIT_FAILURE);
    }

    exit(EXIT_SUCCESS);

fail_gpio:
    free(gpio);
fail_machine:
    free(machine);
fail_renode:
    try_renode_disconnect(&renode);
    free(renode);
fail:
    renode_free_error(error);
    exit(EXIT_FAILURE);
}
