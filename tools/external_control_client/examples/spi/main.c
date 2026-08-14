//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under MIT License.
// Full license text is available in 'licenses/MIT.txt' file.
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "renode_api.h"

// MISO = MOSI + transfer number
static uint8_t on_transmit_spi0(void *user_data, uint8_t mosi)
{
    uint8_t *spi0_counter = (uint8_t *)user_data;

    uint8_t miso = mosi + *spi0_counter;
    *spi0_counter = *spi0_counter + 1;

    printf("spi0 on_transmit: MOSI 0x%02x -> MISO 0x%02x\n", mosi, miso);

    return miso;
}

static void on_finish_spi0(void *user_data)
{
    uint8_t *spi0_counter = (uint8_t *)user_data;

    *spi0_counter = 0;

    printf("spi0 on_finish: Finished\n");
}

// MISO = 128 + transfer number * 2
static uint8_t on_transmit_spi1(void *user_data, uint8_t mosi)
{
    uint8_t *spi1_counter = (uint8_t *)user_data;

    uint8_t miso = (uint8_t)(128 + *spi1_counter);
    *spi1_counter = *spi1_counter + 2;

    printf("spi1 on_transmit: MOSI 0x%02x -> MISO 0x%02x\n", mosi, miso);

    return miso;
}

static void on_finish_spi1(void *user_data)
{
    uint8_t *spi1_counter = (uint8_t *)user_data;

    *spi1_counter = 0;

    printf("spi1 on_finish: Finished\n");
}

static void exit_with_usage_info(const char *argv0)
{
    fprintf(stderr,
            "Usage:\n"
            "  %s <PORT> <MACHINE> <SPI_NAME>\n"
            "  %s <PORT> <MACHINE> <SPI_NAME_0> <SPI_NAME_1>\n",
            argv0, argv0);
    exit(EXIT_FAILURE);
}

static renode_error_t *run_for(renode_t *renode)
{
    renode_error_t *err = NO_ERROR;
    renode_time_t run_for_time;
    if ((err = renode_create_time(1, TU_MILLISECONDS, &run_for_time))) {
        fprintf(stderr, "%s\n",
                err && err->message ? err->message : "<no message>");
        return err;
    }
    if ((err = renode_run_for(renode, run_for_time))) {
        fprintf(stderr, "%s\n",
                err && err->message ? err->message : "<no message>");
        return err;
    }

    return NO_ERROR;
}

int main(int argc, char **argv)
{
    if (argc != 5 && argc != 6) {
        exit_with_usage_info(argv[0]);
    }

    const int use_second_spi = argc == 6;

    renode_error_t *err;
    renode_t *renode;
    renode_machine_t *machine;
    renode_spi_t *spi0 = NULL;
    renode_spi_t *spi1 = NULL;
    bool run_simulation;

    uint8_t spi0_counter = 0;
    uint8_t spi1_counter = 0;

    if (strcmp(argv[3], "client") == 0) {
        run_simulation = true;
    } else if (strcmp(argv[3], "server") == 0) {
        run_simulation = false;
    } else {
        exit_with_usage_info(argv[0]);
    }

    if ((err = renode_connect(argv[1], &renode))) {
        goto fail;
    }
    if ((err = renode_get_machine(renode, argv[2], &machine))) {
        goto fail_renode;
    }
    if ((err = renode_get_spi(machine, argv[4], &spi0))) {
        goto fail_machine;
    }
    if ((err = renode_spi_register_callbacks(
             spi0, &spi0_counter, on_transmit_spi0, on_finish_spi0))) {
        fprintf(stderr, "%s\n",
                err && err->message ? err->message : "<no message>");
        goto fail_spi;
    }

    if (use_second_spi) {
        if ((err = renode_get_spi(machine, argv[5], &spi1))) {
            goto fail_spi;
        }

        if ((err = renode_spi_register_callbacks(
                 spi1, &spi1_counter, on_transmit_spi1, on_finish_spi1))) {
            goto fail_spi;
        }
    }

    if (run_simulation) {
        if ((err = run_for(renode))) {
            fprintf(stderr, "%s\n",
                    err && err->message ? err->message : "<no message>");
            goto fail_spi;
        }
    } else {
        // Loop forever, Renode connection thread will handle callbacks
        while (1) {
        };
    }

    printf("RunFor finished\n");

    free(spi0);
    if (use_second_spi) {
        free(spi1);
    }
    free(machine);
    renode_disconnect(&renode);
    return EXIT_SUCCESS;

fail_spi:
    free(spi0);
    if (use_second_spi) {
        free(spi1);
    }
fail_machine:
    free(machine);
fail_renode:
    renode_disconnect(&renode);
fail:
    fprintf(stderr, "%s\n",
            err && err->message ? err->message : "<no message>");
    renode_free_error(err);
    return EXIT_FAILURE;
}
