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

static int run_demo(renode_t *renode, renode_error_t *err, const char *machine_name, const char *peripheral_name, uint64_t address)
{
    renode_machine_t *machine;
    err = renode_get_machine(renode, machine_name, &machine);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain machine '%s' (%s)\n", machine_name, err->message);
        return EXIT_FAILURE;
    }

    // Perform a bus transaction

    renode_bus_context_t *sysbus;
    err = renode_get_sysbus(machine, &sysbus);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain the system bus '%s' (%s)\n", machine_name, err->message);
        return EXIT_FAILURE;
    }

    uint32_t bus_data_write = 0xDDCCBBAA;
    err = renode_sysbus_write(sysbus, address, AW_MULTI_BYTE, &bus_data_write, sizeof(bus_data_write));
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus write failed (%s)\n", err->message);
        return EXIT_FAILURE;
    }

    uint32_t bus_data_read;
    err = renode_sysbus_read(sysbus, address, AW_BYTE, &bus_data_read, sizeof(bus_data_read));
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus read failed (%s)\n", err->message);
        return EXIT_FAILURE;
    }

    fprintf(stderr, "(BUS @ 0x%"PRIx64") %s: written = 0x%"PRIx32", read = 0x%"PRIx32" to 0x%"PRIx64"\n", address, bus_data_read == bus_data_write ? "SUCCESS" : "FAILURE", bus_data_write, bus_data_read, address);
    if (bus_data_read != bus_data_write) {
        return EXIT_FAILURE;
    }

    // Perform a bus transaction with a peripheral context (seeing the bus from the perspective of the provided peripheral)

    renode_bus_context_t *ctx;
    err = renode_get_bus_context(machine, peripheral_name, &ctx);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain peripheral '%s' (%s)\n", peripheral_name, err->message);
        return EXIT_FAILURE;
    }

    uint64_t context_data_write = 0xAABBCCDDEEFF8899;
    err = renode_sysbus_write(ctx, address, AW_DOUBLE_WORD, &context_data_write, 2);
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus write failed (%s)\n", err->message);
        return EXIT_FAILURE;
    }

    uint64_t context_data_read;
    err = renode_sysbus_read(ctx, address, AW_QUAD_WORD, &context_data_read, 1);
    if (err != NO_ERROR) {
        fprintf(stderr, "System bus read failed (%s)\n", err->message);
        return EXIT_FAILURE;
    }

    char *name;
    err = renode_get_bus_context_name(ctx, &name);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to obtain the name of the access context (%s)\n", err->message);
        return EXIT_FAILURE;
    }

    fprintf(stderr, "(CONTEXT '%s' @ 0x%"PRIx64") %s: written = 0x%"PRIx64", read = 0x%"PRIx64"\n", name, address, context_data_read == context_data_write ? "SUCCESS" : "FAILURE", context_data_write, context_data_read);
    if (context_data_read != context_data_write) {
        return EXIT_FAILURE;
    }
    free(name);

    return EXIT_SUCCESS;
}

int main(int argc, char **argv)
{
    if (argc < 5) {
        print_usage(argv[0]);
    }

    const char *port = argv[1];
    const char *machine_name = argv[2];
    const char *peripheral_name = argv[3];
    uint64_t address = strtoll(argv[4], NULL, 16);

    renode_error_t *err;

    renode_t *renode;
    err = renode_connect(port, &renode);
    if (err != NO_ERROR) {
        fprintf(stderr, "Failed to connect to Renode on port %s (%s)\n", port, err->message);
        renode_disconnect(&renode);
        return EXIT_FAILURE;
    }


    int result = run_demo(renode, err, machine_name, peripheral_name, address);
    if (err != NO_ERROR) {
        renode_free_error(err);
    }

    renode_disconnect(&renode);
    return result;
}
