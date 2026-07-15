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
#include <string.h>
#include <inttypes.h>

#include "renode_api.h"

#define LINE_BUFFER_SIZE 86

char *get_error_message(renode_error_t *error)
{
    if (error->message == NULL)
    {
        return "<no message>";
    }
    return error->message;
}

#ifdef LOG_PERF
#include <time.h>

static int tsi;
static struct timespec t[2];

static void perf_start()
{
    clock_gettime(CLOCK_REALTIME, &t[tsi]);
}

static void perf_stop(uint64_t times, renode_time_t run_for)
{
    tsi ^= 1;
    clock_gettime(CLOCK_REALTIME, &t[tsi]);

    int64_t seconds = t[tsi].tv_sec - t[tsi ^ 1].tv_sec;
    int64_t nanoseconds = t[tsi].tv_nsec - t[tsi ^ 1].tv_nsec;
    if(nanoseconds < 0)
    {
        seconds -= 1;
        nanoseconds += 1000000000;
    }
    int64_t microseconds = (nanoseconds + 500) / 1000;

    double virt_seconds = renode_time_to_seconds(run_for) * times;
    double ratio = (seconds * 1e6 + microseconds) / virt_seconds;

    fprintf(stderr, "delta: %"PRId64".%06"PRId64"s real\t %lfs virt\t real / virt %lf\n", seconds, microseconds, virt_seconds, ratio);
}

static void start_virtual_time_check(renode_t *renode)
{
    (void)renode;
}

static void stop_virtual_time_check(renode_t *renode, uint64_t value, renode_time_unit_t time_unit)
{
    (void)renode;
    (void)value;
    (void)time_unit;
}

#else // !LOG_PERF

static void perf_start() {}

static void perf_stop(uint64_t times, renode_time_t run_for)
{
    (void)times;
    (void)run_for;
}

static renode_time_t vt0;

static renode_time_t get_current_virtual_time(renode_t *renode)
{
    renode_error_t *error;
    renode_time_t current_time;
    if ((error = renode_get_current_time(renode, &current_time)) != NO_ERROR) {
        fprintf(stderr, "Get current time failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    return current_time;
}

static void start_virtual_time_check(renode_t *renode)
{
    vt0 = get_current_virtual_time(renode);
}

static void stop_virtual_time_check(renode_t *renode, renode_time_t expected_delta)
{
    renode_time_t vt1 = get_current_virtual_time(renode);
    renode_time_t vt_delta = vt1 - vt0;

    uint64_t microseconds_total = renode_time_to_time_unit(vt1, TU_MICROSECONDS);

    int microseconds = microseconds_total % 1000000;
    int seconds_total = microseconds_total / 1000000;
    int seconds = seconds_total % 60;
    int minutes_total = seconds_total / 60;
    int minutes = minutes_total % 60;
    int hours_total = minutes_total / 60;

    printf("Elapsed virtual time %02d:%02d:%02d.%06d\n", hours_total, minutes, seconds, microseconds);

    if (vt_delta != expected_delta) {
        fprintf(stderr, "Reported current virtual time doesn't match the expected virtual time after running for the requested interval\n");
        exit(EXIT_FAILURE);
    }
}

#endif

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

bool read_time_value(char *buffer, char **endptr, renode_time_t *time)
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

    renode_error_t *err = renode_create_time(new_value, unit, time);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to create Renode time: %s\n", err->message);
        renode_free_error(err);
        return false;
    }

    return true;
}

void run_options_prompt(renode_time_t *time, uint64_t *times)
{
    char option;
    bool retry;

    do {
        retry = false;
        printf("Continue running for %"PRIu64"ms %"PRIu64" times? [y/N/c] ", renode_time_to_time_unit(*time, TU_MICROSECONDS), *times);

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
                if (!read_time_value(buffer, &endptr, time)) {
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

    renode_time_t run_for_time;
    if (!read_time_value(argv[2], NULL, &run_for_time)) {
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

    perf_start();

    uint64_t i = times;
    while(i > 0)
    {
        start_virtual_time_check(renode);

        if ((error = renode_run_for(renode, run_for_time)) != NO_ERROR) {
            fprintf(stderr, "Run for failed with: %s\n", get_error_message(error));
            renode_free_error(error);
            exit(EXIT_FAILURE);
        }

        stop_virtual_time_check(renode, run_for_time);

        i -= 1;
        if (i == 0)
        {
            perf_stop(times, run_for_time);
#ifndef NON_INTERACTIVE
            run_options_prompt(&run_for_time, &times);
            i = times;
#endif
            perf_start();
        }
    }

    if ((error = renode_disconnect(&renode)) != NO_ERROR) {
        fprintf(stderr, "Disconnecting from Renode failed with: %s\n", get_error_message(error));
        renode_free_error(error);
        exit(EXIT_FAILURE);
    }

    exit(EXIT_SUCCESS);
}
