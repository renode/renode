#pragma once

/**
 * @file
 * @brief Declares Renode API
 */

#include <inttypes.h>
#include <stdbool.h>


/* Error handling */

/**
 * All the functions return a pointer to the renode_error_t structure in case of an error.
 * Its memory has to be freed in case it's handled. NULL returned indicates success.
 */
#define NO_ERROR NULL

/**
 * Error codes
 */
typedef enum {
    ERR_INVALID_CODE = -1, /**< invalid error code */
    ERR_FATAL, /**< fatal error */
    ERR_COMMAND_FAILED, /**< command failed */
    ERR_INVALID_COMMAND, /**< invalid command */
} renode_error_code_t;

/**
 * Structure describing status of a finished operation
 */
typedef struct {
    /** Error code */
    renode_error_code_t code;
    /** Error flags, currently only used internally */
    int flags;
    /** Error message */
    char *message;
    /** Error data, currently unused */
    void *data;
} renode_error_t;


/* General */

/**
 * @brief Renode connection API handle
 *
 * Renode handles are pointers to structs implemented internally which must be prepared by calling
 * `renode_get_X` functions (renode_connect() for `renode_t`) so that they can be later used in their
 * related functions.
 *
 * Struct internals aren't part of the API.
 *
 * @note Memory the handles point to is dynamically allocated and should be freed when the handles are no longer needed.
 * It can be done by calling `free(*handle)` with the exception of Renode connection API handle which should be closed
 * by calling renode_disconnect().
 */
typedef struct renode renode_t;

/**
 * @brief Renode machine API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_machine renode_machine_t;

/**
 * @brief Renode ADC peripheral API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_adc renode_adc_t;

/**
 * @brief Renode GPIO controller API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_gpio renode_gpio_t;

/**
 * @brief Renode bus manager API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_bus_context renode_bus_context_t;

/**
 * @brief Function initializing Renode connection
 *
 * @note The connection should be closed using renode_disconnect() before a client app exits.
 *
 * @param[in] port TCP port
 * @param[out] renode Renode connection handle pointer
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_connect(const char *port, renode_t **renode);

/**
 * @brief Function closing Renode connection and freeing internal handle memory
 *
 * @note The internal handle memory is freed so calling `free(*renode)` after calling this function is invalid.
 *
 * @param[in] renode Renode connection handle pointer
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_disconnect(renode_t **renode);

/**
 * @brief Function preparing machine handle
 *
 * @note Handle's internal memory is dynamically allocated so `*machine` should be freed when it's no longer used.
 *
 * @param[in] renode Renode connection handle
 * @param[in] name name of the machine to fetch
 * @param[out] machine Renode machine handle
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_machine(renode_t *renode, const char *name, renode_machine_t **machine);

/**
 * @brief Function deallocating error structure's memory
 *
 * The function should be run every time any of the functions return a valid error structure pointer.
 * By default, those functions return `NULL`.
 *
 * @param[in] error error structure
 */
void renode_free_error(renode_error_t *error);


/* Time control */

/**
 * Supported time units
 */
typedef enum {
    TU_MICROSECONDS =       1, /**< microseconds */
    TU_MILLISECONDS =    1000, /**< milliseconds */
    TU_SECONDS      = 1000000, /**< seconds */
} renode_time_unit_t;

/**
 * @brief Function ordering emulation to run for a specified time
 *
 * @param[in] renode Renode connection handle
 * @param[in] unit value argument's time unit
 * @param[in] value virtual time the emulation should run for (in the specified unit)
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_run_for(renode_t *renode, renode_time_unit_t unit, uint64_t value);

/**
 * @brief Function getting current emulation virtual time
 *
 * @param[in] renode Renode connection handle
 * @param[in] unit requested time unit of the output value
 * @param[out] current_time current emulation virtual time (in the requested unit)
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_current_time(renode_t *renode, renode_time_unit_t unit, uint64_t *current_time);

/* ADC */

/**
 * @brief Function preparing ADC handle
 *
 * @note Handle's internal memory is dynamically allocated so `*adc` should be freed when it's no longer used.
 *
 * @param[in] machine machine handle
 * @param[in] name ADC peripheral's name
 * @param[out] adc handle associated with the requested ADC peripheral
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_adc(renode_machine_t *machine, const char *name, renode_adc_t **adc);


/**
 * @brief Function getting a number of channels ADC has
 *
 * @param[in] adc ADC handle
 * @param[out] count number of channels
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_adc_channel_count(renode_adc_t *adc, int32_t *count);

/**
 * @brief Function getting ADC channel's value
 *
 * @param[in] adc ADC handle
 * @param[in] channel ADC channel index
 * @param[out] value current ADC channel value
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t *value);

/**
 * @brief Function setting ADC channel's value
 *
 * @param[in] adc ADC handle
 * @param[in] channel ADC channel index
 * @param[in] value requested ADC channel value
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_set_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t value);

/* GPIO */

/**
 * @brief Function preparing GPIO controller handle
 *
 * @note Handle's internal memory is dynamically allocated so `*gpio` should be freed when it's no longer used.
 *
 * @param[in] machine machine handle
 * @param[in] name GPIO controller's name
 * @param[out] gpio handle associated with the requested GPIO controller
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_gpio(renode_machine_t *machine, const char *name, renode_gpio_t **gpio);

/**
 * @brief Function getting state of GPIO
 *
 * @param[in] gpio GPIO controller handle
 * @param[in] id GPIO's index in the given GPIO controller
 * @param[out] state current GPIO state
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_gpio_state(renode_gpio_t *gpio, int32_t id, bool *state);

/**
 * @brief Function setting state of GPIO
 *
 * @param[in] gpio GPIO controller handle
 * @param[in] id GPIO's index in the given GPIO controller
 * @param[in] state requested GPIO state
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_set_gpio_state(renode_gpio_t *gpio, int32_t id, bool state);

/**
 * GPIO state changed event data
 */
typedef struct {
    /** Virtual time in microseconds */
    uint64_t timestamp_us;
    /** New GPIO state */
    bool state;
} renode_gpio_event_data_t;

/**
 * @brief Function registering callback when GPIO state changes
 *
 * @param[in] gpio GPIO controller handle
 * @param[in] id GPIO's index in the given GPIO controller
 * @param[in] user_data pointer to data passed to the callback when it's invoked
 * @param[in] callback callback to be invoked when state of GPIO with the given index changes
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_register_gpio_state_change_callback(renode_gpio_t *gpio, int32_t id, void *user_data, void (*callback)(void *, renode_gpio_event_data_t *));


/* System bus */

/**
 * Supported access width options
 */
typedef enum {
    AW_MULTI_BYTE  = 0, /**< multibyte access (number of bytes defined by `count`) */
    AW_BYTE        = 1, /**< byte access */
    AW_WORD        = 2, /**< word (2B) access */
    AW_DOUBLE_WORD = 4, /**< double word (4B) access */
    AW_QUAD_WORD   = 8, /**< quad word (8B) access */
} renode_access_width_t;

/**
 * @brief Function preparing bus handle with emulation element context
 *
 * The context is used to imitate bus accesses made by specific bus managers like CPU, DMA, etc.
 * `"sysbus"` can be passed as `name` if bus accesses should be made with global context.
 *
 * Please note that accesses made using a handle with emulation element context still need to
 * use absolute addresses so they're equivalent to Renode's `sysbus Read<width> <address> context=<name>`
 * rather than `<name> Read<width> <address>` which treates addresses as relative to `<name>` peripheral's
 * registration base address.
 *
 * @note Handle's internal memory is dynamically allocated so `*ctx` should be freed when it's no longer used.
 *
 * @param[in] machine machine handle
 * @param[in] name emulation element's name in which context bus accesses should be made
 * @param[out] ctx handle for making bus accesses with context of the specified emulation element
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_bus_context(renode_machine_t *machine, const char *name, renode_bus_context_t **ctx);

/**
 * @brief Function preparing bus handle with global context
 *
 * This is just a convenience wrapper equivalent to renode_get_bus_context() with `name="sysbus"`.
 *
 * @note Handle's internal memory is dynamically allocated so `*sysbus` should be freed when it's no longer used.
 *
 * @param[in] machine machine handle
 * @param[out] sysbus handle for making bus accesses with global context
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_sysbus(renode_machine_t *machine, renode_bus_context_t **sysbus);

/**
 * @brief Function reading data from bus
 *
 * @param[in] ctx bus handle
 * @param[in] address read's absolute address
 * @param[in] width read's width
 * @param[in] buffer buffer for the read data
 * @param[in] count number of requested reads (total data size will be `width * count`)
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_sysbus_read(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, void *buffer, uint32_t count);

/**
 * @brief Function writing data to bus
 *
 * @param[in] ctx bus handle
 * @param[in] address access absolute address
 * @param[in] width access width
 * @param[in] buffer buffer with data to write to bus
 * @param[in] count number of requested writes (total data size is `width * count`)
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_sysbus_write(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, const void *buffer, uint32_t count);
