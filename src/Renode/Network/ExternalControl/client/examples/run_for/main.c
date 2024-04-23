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

    time_unit_t time_unit = -1;
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

    error_t *error;
    renode_t *renode;
    renode_connect(argv[1], &renode);

    if ((error = run_for(renode, time_unit, value)) != NO_ERROR) {
        fprintf(stderr, "Run for failed");
        exit(EXIT_FAILURE);
    }

    renode_disconnect(&renode);
    exit(EXIT_SUCCESS);
}
