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
        "  %s <PORT> <MACHINE_NAME> <ADC_NAME> <VALUE_WITH_UNIT>\n"
        "  where:\n"
        "  * <VALUE_WITH_UNIT> is an unsigned integer with a voltage unit, e.g.: '100mV'\n"
        "  * accepted voltage units are 'V', 'mV' and 'uV' (for microvolts)\n",
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

char *voltage_string(uint32_t value)
{
    static char buffer[32];
    uint32_t integer, fraction;

    if ((integer = (value / 1000000))) {
        fraction = value % 1000000;
        snprintf(buffer, 32, "%u.%06uV", integer, fraction);
    }
    else if ((integer = (value / 1000))) {
        fraction = value % 1000;
        snprintf(buffer, 32, "%u.%03umV", integer, fraction);
    }
    else {
        snprintf(buffer, 32, "%uuV", value);
    }

    return buffer;
}

int main(int argc, char **argv)
{
    if (argc != 5) {
        exit_with_usage_info(argv[0]);
    }
    char *machine_name = argv[2];
    char *adc_name = argv[3];

    char *endptr;
    // base=0 tries to figure out the number's base automatically.
    uint64_t value = strtoul(argv[4], &endptr, /* base: */ 0);
    if (errno != 0) {
        perror("conversion to uint32_t value");
        exit(EXIT_FAILURE);
    }

    if (endptr == argv[4]) {
        exit_with_usage_info(argv[0]);
    }

    switch (*endptr) {
        case 'u':
            // the unit used with the API
            break;
        case 'm':
            value *= 1000;
            break;
        case 'V':
            value *= 1000000;
            break;
        default:
            exit_with_usage_info(argv[0]);
    }

    if (value > UINT32_MAX) {
        fprintf(stderr, "Voltage value too big\n");
        exit(EXIT_FAILURE);
    }

    // get Renode, machine and ADC instances

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

    renode_adc_t *adc;
    if ((error = renode_get_adc(machine, adc_name, &adc)) != NO_ERROR) {
        fprintf(stderr, "Getting '%s' ADC object failed with: %s\n", adc_name, get_error_message(error));
        goto fail_machine;
    }

    // assert that at least one channel exists

    int32_t ch_count;
    if ((error = renode_get_adc_channel_count(adc, &ch_count)) != NO_ERROR) {
        fprintf(stderr, "Getting channel count for '%s' failed with: %s\n", adc_name, get_error_message(error));
        goto fail_adc;
    }

    if (ch_count < 1) {
        fprintf(stderr, "Expected at least one ADC channel\n");
        goto fail_adc;
    }
    printf("[INFO] # of channels: %d\n", ch_count);

    // get current value, set the new value and assert that new current value is set

    uint32_t val0;
    if ((error = renode_get_adc_channel_value(adc, 0, &val0)) != NO_ERROR) {
        fprintf(stderr, "Getting channel #0 value for '%s' failed with: %s\n", adc_name, get_error_message(error));
        goto fail_adc;
    }

    printf("ADC value: %s\n", voltage_string(val0));

    uint32_t val1 = value;
    if ((error = renode_set_adc_channel_value(adc, 0, val1)) != NO_ERROR) {
        fprintf(stderr, "Setting channel #0 value for '%s' failed with: %s\n", adc_name, get_error_message(error));
        goto fail_adc;
    }

    printf("ADC value set to %s\n", voltage_string(val1));

    uint32_t val2;
    if ((error = renode_get_adc_channel_value(adc, 0, &val2)) != NO_ERROR) {
        fprintf(stderr, "Getting channel #0 value for '%s' failed with: %s\n", adc_name, get_error_message(error));
        goto fail_adc;
    }

    printf("ADC value: %s\n", voltage_string(val2));

    // clean up

    free(adc);
    free(machine);
    if (try_renode_disconnect(&renode)) {
        exit(EXIT_FAILURE);
    }

    if (val1 != val2) {
        fprintf(stderr, "ADC value doesn't match set value\n");
        exit(EXIT_FAILURE);
    }

    exit(EXIT_SUCCESS);

fail_adc:
    free(adc);
fail_machine:
    free(machine);
fail_renode:
    try_renode_disconnect(&renode);
    free(renode);
fail:
    renode_free_error(error);
    exit(EXIT_FAILURE);
}
