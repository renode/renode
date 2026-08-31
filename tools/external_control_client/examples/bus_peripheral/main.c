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

#define MEMORY_ADDRESS 0x1000
#define MEMORY_SIZE 0x1000

#define COUNTER_ADDRESS 0x2000

static void sysbus_callback_memory(void *user_data, renode_sysbus_event_data_t* event_data) {
  uint8_t *peripheral_buffer = user_data;

  if (event_data->address < MEMORY_ADDRESS || event_data->address > MEMORY_ADDRESS + MEMORY_SIZE) {
    return;
  }

  uint64_t memory_offset = event_data->address - MEMORY_ADDRESS;
  uint32_t byte_count;
  renode_get_byte_count(event_data->width, event_data->transfer_count, &byte_count);
  if (event_data->access_type == SYSBUS_CB_READ) {
    for (uint32_t i = 0; i < byte_count; i++) {
      event_data->data[i] = *(peripheral_buffer+i+memory_offset);
    }
  } else if (event_data->access_type == SYSBUS_CB_WRITE) {
    for (uint32_t i = 0; i < byte_count; i++) {
      *(peripheral_buffer+i+memory_offset) = event_data->data[i];
    }
  }

  event_data->access_succeeded = true;
}

static void sysbus_callback_counter(void *user_data, renode_sysbus_event_data_t* event_data) {
  if (event_data->address != COUNTER_ADDRESS) {
    return;
  }

  uint32_t *counter = (uint32_t *)user_data;
  if (event_data->access_type == SYSBUS_CB_READ) {
    *(uint32_t *)event_data->data = *counter;
  } else if (event_data->access_type == SYSBUS_CB_WRITE) {
    *counter += *(uint32_t *)event_data->data;
  }

  event_data->access_succeeded = true;
}

static void exit_with_usage_info(const char *argv0)
{
  fprintf(stderr,
    "Usage:\n"
    "  %s <PORT> <MACHINE> <MEMORY_PERIPHERAL_NAME> <COUNTER_PERIPHERAL_NAME>\n",
    argv0);
  exit(EXIT_FAILURE);
}

int main(int argc, char **argv) {
  if(argc != 5) {
    exit_with_usage_info(argv[0]);
  }

  renode_error_t *err;
  renode_t *renode;
  renode_machine_t *machine;
  renode_bus_peripheral_t *memory_bus_peripheral = NULL;
  renode_bus_peripheral_t *counter_bus_peripheral = NULL;
  uint32_t counter = 0;

  void* peripheral_buffer = malloc(0x1000);

  if ((err = renode_connect(argv[1], &renode))) {
    goto fail;
  }
  if ((err = renode_get_machine(renode, argv[2], &machine))) {
    goto fail_renode;
  }
  if ((err = renode_get_bus_peripheral(machine, argv[3], &memory_bus_peripheral))) {
    goto fail_machine;
  }
  if ((err = renode_get_bus_peripheral(machine, argv[4], &counter_bus_peripheral))) {
    goto fail_memory_peripheral;
  }
  if ((err = renode_register_sysbus_access_callback(memory_bus_peripheral, SYSBUS_CB_BOTH, AW_CB_ANY, peripheral_buffer, sysbus_callback_memory))) {
    goto fail_counter_peripheral;
  }
  if ((err = renode_register_sysbus_access_callback(counter_bus_peripheral, SYSBUS_CB_BOTH, AW_DOUBLE_WORD, &counter, sysbus_callback_counter))) {
    goto fail_counter_peripheral;
  }

  // Loop forever, Renode connection thread will handle callbacks
  while(1){};

fail_counter_peripheral:
  free(counter_bus_peripheral);
fail_memory_peripheral:
  free(memory_bus_peripheral);
fail_machine:
  free(machine);
fail_renode:
  renode_disconnect(&renode);
fail:
  fprintf(stderr, "%s\n", err && err->message ? err->message : "<no message>");
  renode_free_error(err);
  return EXIT_FAILURE;
}
