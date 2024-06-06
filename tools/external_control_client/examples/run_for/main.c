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

#define LINE_BUFFER_SIZE 86

void exit_with_usage_info(const char *argv0)
{
    fprintf(stderr,
        "Usage:\n"
        "  %s <PORT> <VALUE_WITH_UNIT> [<REPEAT>]\n"
        "  where:\n"
        "  * <VALUE_WITH_UNIT> is an integer with a time unit, e.g.: '100ms'\n"
        "  * accepted time units are 's', 'ms' and 'us' (for microseconds)\n"
        "  * <REPEAT> is an optional number of times (default: 1) to run\n"
        "  * the simulation for\n",
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

bool read_time_value(char *buffer, char **endptr, uint64_t *value, renode_time_unit_t *time_unit)
{
    char *noendptr;
    if (endptr == NULL) {
        endptr = &noendptr;
    }
    // base=0 tries to figure out the number's base automatically.
    uint64_t new_value = strtoull(buffer, endptr, /* base: */ 0);
    if (errno != 0) {
        perror("conversion to uint64_t value");
        exit(EXIT_FAILURE);
    }

    if (*endptr == buffer) {
        return false;
    }

    renode_time_unit_t unit = -1;
    switch (**endptr) {
        case 'u':
            unit = TU_MICROSECONDS;
            *endptr += 2;
            break;
        case 'm':
            unit = TU_MILLISECONDS;
            *endptr += 2;
            break;
        case 's':
            unit = TU_SECONDS;
            *endptr += 1;
            break;
        default:
            return false;
    }

    *value = new_value;
    *time_unit = unit;
    return true;
}

void run_options_prompt(uint64_t *value, renode_time_unit_t *time_unit, uint64_t *times)
{
    char option;
    bool retry;

    do {
        retry = false;
        printf("Continue running for %lu%ss %lu times? [y/N/c] ", *value, *time_unit == TU_MICROSECONDS ? "u" : (*time_unit == TU_MILLISECONDS ? "m" : ""), *times);

        if ((option = getchar()) != '\n') while(getchar() != '\n');

        switch (option)
        {
        case 'y':
        case 'Y':
            return;
        case 'c':
        case 'C':
            printf("Enter new value: ");
            {
                char buffer[LINE_BUFFER_SIZE];
                char *endptr;

                if (fgets(buffer, LINE_BUFFER_SIZE, stdin) != buffer) {
                    fprintf(stderr, "Failed to read line\n");
                    retry = true;
                    break;
                }

                size_t len = strlen(buffer);
                if (len == LINE_BUFFER_SIZE - 1 && buffer[len - 1] != '\n') {
                    fprintf(stderr, "Failed to read line: line too long\n");
                    retry = true;
                    break;
                }

                errno = 0;
                if (!read_time_value(buffer, &endptr, value, time_unit)) {
                    fprintf(stderr, "Failed to parse time value\n");
                    retry = true;
                    break;
                }

                if (*endptr != '\n' && *endptr != '\0')
                {
                    *times = strtoull(endptr, NULL, /* base: */ 0);
                    if (errno != 0) {
                        perror("conversion to uint64_t value");
                        exit(EXIT_FAILURE);
                    }
                }
                else
                {
                    *times = 1;
                }
            }
            return;
        case '\n':
        case 'n':
        case 'N':
            *times = 0;
            return;
        default:
            retry = true;
            break;
        }

    } while(retry);
}

int main(int argc, char **argv)
{
    if (argc < 3 || 4 < argc) {
        exit_with_usage_info(argv[0]);
    }

    uint64_t value;
    renode_time_unit_t time_unit;
    if (!read_time_value(argv[2], NULL, &value, &time_unit)) {
        exit_with_usage_info(argv[0]);
    }

    uint64_t times = 1;
    if (argc == 4)
    {
        times = strtoull(argv[3], NULL, /* base: */ 0);
        if (errno != 0) {
            perror("conversion to uint64_t value");
            exit(EXIT_FAILURE);
        }
    }

    renode_error_t *error;
    renode_t *renode;
    if ((error = renode_connect(argv[1], &renode)) != NO_ERROR) {
        fprintf(stderr, "Connecting to Renode failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    uint64_t i = times;
    while(i > 0)
    {
        uint64_t t0 = get_current_virtual_time(renode);

        if ((error = renode_run_for(renode, time_unit, value)) != NO_ERROR) {
            fprintf(stderr, "Run for failed with: %s\n", get_error_message(error));
            renode_free_error(error);
            exit(EXIT_FAILURE);
        }

        uint64_t t1 = get_current_virtual_time(renode);
        uint64_t t_delta = t1 - t0;

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

        i -= 1;
        if (i == 0)
        {
            run_options_prompt(&value, &time_unit, &times);
            i = times;
        }
    }

    if ((error = renode_disconnect(&renode)) != NO_ERROR) {
        fprintf(stderr, "Disconnecting from Renode failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    exit(EXIT_SUCCESS);
}
