//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

#include "renode_api.h"

static void print_usage(const char *argv0)
{
    fprintf(stderr,
        "Usage:\n"
        "  %s <PORT> <MACHINE_NAME> <PERIPHERAL_NAME> <ADDRESS>\n",
        argv0);
    exit(EXIT_FAILURE);
}

static void gpio_callback(void *user_data, renode_gpio_event_data_t *event_data)
{
    (void)user_data;

    fprintf(stderr, "GPIO #0 %sset", event_data->state ? "" : "un");
    uint64_t microseconds = renode_time_to_time_unit(event_data->time, TU_MICROSECONDS);
    fprintf(stderr, " at %"PRIu64" us\n", microseconds);
}

static renode_error_t * register_gpio_callback(renode_t *renode, renode_error_t *err, const char *machine_name, const char *gpio_name)
{
    renode_machine_t *machine = NULL;
    renode_gpio_t *gpio = NULL;

    err = renode_get_machine(renode, machine_name, &machine);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain machine '%s' (%s)\n", machine_name, err->message);
        return err;
    }

    err = renode_get_gpio(machine, gpio_name, &gpio);
    if (err != NO_ERROR) {
        fprintf(stderr, "Getting '%s' ADC object failed with: %s\n", gpio_name, err->message);
        free(machine);
        return err;
    }

    err = renode_register_gpio_state_change_callback(gpio, 0, NULL, gpio_callback);
    if (err != NO_ERROR) {
        fprintf(stderr, "Registering event on pin #%"PRId32" for '%s' failed with: %s\n", 0, gpio_name, err->message);
    }

    free(machine);
    free(gpio);
    return err;
}

static int run_demo(renode_t *renode, renode_error_t *err, const char *machine_name, const char *peripheral_name, uint64_t address)
{
    renode_machine_t *machine = NULL;
    renode_bus_context_t *sysbus = NULL;
    renode_bus_context_t *ctx = NULL;
    char *name = NULL;
    int ret = EXIT_FAILURE;

    err = renode_get_machine(renode, machine_name, &machine);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain machine '%s' (%s)\n", machine_name, err->message);
        goto end;
    }

    // Perform a bus transaction

    err = renode_get_sysbus(machine, &sysbus);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain the system bus '%s' (%s)\n", machine_name, err->message);
        goto end;
    }

    uint32_t bus_data_write = 0xDDCCBBAA;
    err = renode_sysbus_write(sysbus, address, AW_MULTI_BYTE, &bus_data_write, sizeof(bus_data_write));
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus write failed (%s)\n", err->message);
        goto end;
    }

    uint32_t bus_data_read;
    err = renode_sysbus_read(sysbus, address, AW_BYTE, &bus_data_read, sizeof(bus_data_read));
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus read failed (%s)\n", err->message);
        goto end;
    }

    fprintf(stderr, "(BUS @ 0x%"PRIx64") %s: written = 0x%"PRIx32", read = 0x%"PRIx32" to 0x%"PRIx64"\n", address, bus_data_read == bus_data_write ? "SUCCESS" : "FAILURE", bus_data_write, bus_data_read, address);
    if (bus_data_read != bus_data_write) {
        goto end;
    }

    // Perform a bus transaction with a peripheral context (seeing the bus from the perspective of the provided peripheral)

    err = renode_get_bus_context(machine, peripheral_name, &ctx);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain peripheral '%s' (%s)\n", peripheral_name, err->message);
        goto end;
    }

    uint64_t context_data_write = 0xAABBCCDDEEFF8899;
    err = renode_sysbus_write(ctx, address, AW_DOUBLE_WORD, &context_data_write, 2);
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus write failed (%s)\n", err->message);
        goto end;
    }

    uint64_t context_data_read;
    err = renode_sysbus_read(ctx, address, AW_QUAD_WORD, &context_data_read, 1);
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus read failed (%s)\n", err->message);
        goto end;
    }

    err = renode_get_bus_context_name(ctx, &name);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain the name of the access context (%s)\n", err->message);
        goto end;
    }

    fprintf(stderr, "(CONTEXT '%s' @ 0x%"PRIx64") %s: written = 0x%"PRIx64", read = 0x%"PRIx64"\n", name, address, context_data_read == context_data_write ? "SUCCESS" : "FAILURE", context_data_write, context_data_read);
    if (context_data_read != context_data_write) {
        goto end;
    }

    ret = EXIT_SUCCESS;

end:
    free(name);
    free(ctx);
    free(sysbus);
    free(machine);

    return ret;
}

int main(int argc, char **argv)
{
    if (argc < 5) {
        print_usage(argv[0]);
    }

    const char *port = argv[1];
    const char *machine_name = argv[2];
    const char *peripheral_name = argv[3];
    const char *gpio_name = NULL;
    uint64_t address = strtoll(argv[4], NULL, 16);
    if (argc == 6) {
        gpio_name = argv[5];
    }

    renode_error_t *err;

    renode_t *renode;
    err = renode_connect(port, &renode);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to connect to Renode on port %s (%s)\n", port, err->message);
        renode_disconnect(&renode);
        return EXIT_FAILURE;
    }

    // Optionally register a simple GPIO state change callback
    // used for veryfing correctness of nested request handling
    if (gpio_name) {
        err = register_gpio_callback(renode, err, machine_name, gpio_name);
        if (err != NO_ERROR) {
            renode_free_error(err);
        }
    }

    int result = run_demo(renode, err, machine_name, peripheral_name, address);
    if (err != NO_ERROR) {
        renode_free_error(err);
    }

    renode_disconnect(&renode);
    return result;
}
