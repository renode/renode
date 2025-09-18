#pragma once

#include <inttypes.h>
#include <stdbool.h>

/* Error handling */

/*
 * All the functions return a pointer to the renode_error_t structure in case of an error.
 * Its memory has to be freed in case it's handled. NULL returned indicates success.
 */

#define NO_ERROR NULL

typedef enum {
    ERR_CONNECTION_FAILED,
    ERR_FATAL,
    ERR_NOT_CONNECTED,
    ERR_PERIPHERAL_INIT_FAILED,
    ERR_TIMEOUT,
    ERR_COMMAND_FAILED,
    ERR_NO_ERROR = -1,
} renode_error_code;

typedef struct {
    renode_error_code code;
    int flags;
    char *message;
    void *data;
} renode_error_t;

/* General */

// Pointers to these structs must be obtained in `renode_get_X` functions (`connect` for renode_t)
// so that they can be later used in their related functions.
// Internals of these structs aren't part of the API.
typedef struct renode renode_t;
typedef struct renode_machine renode_machine_t;
typedef struct renode_adc renode_adc_t;
typedef struct renode_gpio renode_gpio_t;
typedef struct renode_bus_context renode_bus_context_t;

renode_error_t *renode_connect(const char *port, renode_t **renode);
renode_error_t *renode_disconnect(renode_t **renode);

renode_error_t *renode_get_machine(renode_t *renode_instance, const char *name, renode_machine_t **machine);

void renode_free_error(renode_error_t *error);

/* Time control */

typedef enum {
    TU_MICROSECONDS =       1,
    TU_MILLISECONDS =    1000,
    TU_SECONDS      = 1000000,
} renode_time_unit_t;

renode_error_t *renode_run_for(renode_t *renode, renode_time_unit_t unit, uint64_t value);
renode_error_t *renode_get_current_time(renode_t *renode_instance, renode_time_unit_t unit, uint64_t *current_time);

/* ADC */

renode_error_t *renode_get_adc(renode_machine_t *machine, const char *name, renode_adc_t **adc);
renode_error_t *renode_get_adc_channel_count(renode_adc_t *adc, int32_t *count);
renode_error_t *renode_get_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t *value);
renode_error_t *renode_set_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t value);

/* GPIO */

renode_error_t *renode_get_gpio(renode_machine_t *machine, const char *name, renode_gpio_t **gpio);
renode_error_t *renode_get_gpio_state(renode_gpio_t *gpio, int32_t id, bool *state);
renode_error_t *renode_set_gpio_state(renode_gpio_t *gpio, int32_t id, bool state);

typedef struct {
    uint64_t timestamp_us;
    bool state;
} renode_gpio_event_data_t;

renode_error_t *renode_register_gpio_state_change_callback(renode_gpio_t *gpio, int32_t id, void *user_data, void (*callback)(void *, renode_gpio_event_data_t *));

/* System bus */

typedef enum {
    AW_MULTI_BYTE  = 0,
    AW_BYTE        = 1,
    AW_WORD        = 2,
    AW_DOUBLE_WORD = 4,
    AW_QUAD_WORD   = 8,
} renode_access_width_t;

renode_error_t *renode_get_bus_context(renode_machine_t *machine, const char *name, renode_bus_context_t **ctx);
renode_error_t *renode_get_sysbus(renode_machine_t *machine, renode_bus_context_t **sysbus);
renode_error_t *renode_sysbus_read(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, void *buffer, uint32_t count);
renode_error_t *renode_sysbus_write(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, const void *buffer, uint32_t count);
