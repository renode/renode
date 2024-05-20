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
        "  %s <PORT> <VALUE_WITH_UNIT>\n"
        "  where:\n"
        "  * <VALUE_WITH_UNIT> is an integer with a time unit, e.g.: '100ms'\n"
        "  * accepted time units are 's', 'ms' and 'us' (for microseconds)\n",
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

uint64_t get_current_virtual_time(renode_t *renode)
{
    renode_error_t *error;
    uint64_t current_time;
    if ((error = renode_get_current_time(renode, TU_MICROSECONDS, &current_time)) != NO_ERROR) {
        fprintf(stderr, "Get current time failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    return current_time;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        exit_with_usage_info(argv[0]);
    }

    char *endptr;
    // base=0 tries to figure out the number's base automatically.
    uint64_t value = strtoull(argv[2], &endptr, /* base: */ 0);
    if (errno != 0) {
        perror("conversion to uint64_t value");
        exit(EXIT_FAILURE);
    }

    if (endptr == argv[2]) {
        exit_with_usage_info(argv[0]);
    }

    renode_time_unit_t time_unit = -1;
    switch (*endptr) {
        case 'u':
            time_unit = TU_MICROSECONDS;
            break;
        case 'm':
            time_unit = TU_MILLISECONDS;
            break;
        case 's':
            time_unit = TU_SECONDS;
            break;
        default:
            exit_with_usage_info(argv[0]);
    }

    renode_error_t *error;
    renode_t *renode;
    if ((error = renode_connect(argv[1], &renode)) != NO_ERROR) {
        fprintf(stderr, "Connecting to Renode failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    uint64_t t0 = get_current_virtual_time(renode);

    if ((error = renode_run_for(renode, time_unit, value)) != NO_ERROR) {
        fprintf(stderr, "Run for failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    uint64_t t1 = get_current_virtual_time(renode);
    uint64_t t_delta = t1 - t0;

    if ((error = renode_disconnect(&renode)) != NO_ERROR) {
        fprintf(stderr, "Disconnecting from Renode failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    int microseconds = t1 % TU_SECONDS;
    int seconds_total = t1 / TU_SECONDS;
    int seconds = seconds_total % 60;
    int minutes_total = seconds_total / 60;
    int minutes = minutes_total % 60;
    int hours_total = minutes_total / 60;

    printf("Elapsed virtual time %02d:%02d:%02d.%06d\n", hours_total, minutes, seconds, microseconds);

    if (t_delta != value * time_unit) {
        fprintf(stderr, "Reported current virtual time doesn't match the expected virtual time after running for the requested interval\n");
        exit(EXIT_FAILURE);
    }

    exit(EXIT_SUCCESS);
}
