#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>  // size_t

/* Error handling */

/*
 * All the functions return a pointer to the error_t structure in case of an error.
 * It's memory has to be freed in case it's handled. NULL returned indicates success.
 */

#define NO_ERROR NULL

typedef enum {
    ERR_CONNECTION_FAILED,
    ERR_FATAL,
    ERR_NOT_CONNECTED,
    ERR_PERIPHERAL_INIT_FAILED,
    ERR_TIMEOUT,
} error_code;

typedef struct {
    error_code code;
    char *message;
    size_t message_length;
    void *data;
} error_t;

/* General */

// Pointers to these structs must be obtained in `X_get` functions (`connect` for renode_t)
// so that they can be later used in their related functions.
// Internals of these structs aren't part of the API.
typedef struct adc adc_t;
typedef struct can can_t;
typedef struct gpio gpio_t;
typedef struct machine machine_t;
typedef struct renode renode_t;
typedef struct uart uart_t;

error_t *renode_connect(const char *port, renode_t **renode);
error_t *renode_disconnect(renode_t **renode);

error_t *machine_get(renode_t *renode, const char *machine_name, machine_t **machine);

typedef struct {
    machine_t *machine;
} command_params_t;

error_t *execute_command(const char *command, command_params_t params);

/* Time control */

typedef enum {
    TU_MICROSECONDS =       1,
    TU_MILLISECONDS =    1000,
    TU_SECONDS      = 1000000,
} time_unit_t;

error_t *set_global_timeout(time_unit_t unit, uint64_t value);

error_t *get_current_time(renode_t *renode, time_unit_t unit, uint64_t *current_time);
error_t *run_for(renode_t *renode, time_unit_t unit, uint64_t value);

/* UART */

error_t *uart_get(machine_t *machine, char *peripheral_name, uart_t **uart);

typedef void (*UARTByteReceivedCb)(uint8_t value, void *callback_args);
error_t *uart_byte_received_callback_set(uart_t *uart, UARTByteReceivedCb callback, void *callback_args);
error_t *uart_byte_received_callback_unset(uart_t *uart);

error_t *uart_receive_bytes(uart_t *uart, void *buffer, size_t size, size_t *bytes_received);
error_t *uart_send_bytes(uart_t *uart, void *buffer, size_t size);

/* ADC */

error_t *adc_get(machine_t *machine, char *peripheral_name, adc_t **adc);
error_t *adc_set_channel_voltage(adc_t *adc, uint32_t channel, uint64_t microvolts);

/* CAN */

error_t *can_get(machine_t *machine, char *peripheral_name, can_t **can);

typedef struct {
    uint32_t id;
    uint8_t data_bytes_count;
    uint8_t data[8];
    bool extended_format;
    bool remote_frame;
    bool fd_format;
    bool bit_rate_switch;
} can_frame_t;

typedef void (*CANFrameReceivedCb)(can_frame_t frame, void *callback_args);
error_t *can_frame_received_callback_set(can_t *can, CANFrameReceivedCb callback, void *callback_args);
error_t *can_frame_received_callback_unset(can_t *can);

error_t *can_frame_send(can_t *can, can_frame_t frame);

/* GPIO */

error_t *gpio_get(machine_t *machine, char *peripheral_name, gpio_t **gpio);

typedef void (*GPIOStateChangedCb)(uint32_t id, bool state, void *callback_args);
error_t *gpio_state_changed_callback_set(gpio_t *gpio, GPIOStateChangedCb callback, void *callback_args);
error_t *gpio_state_changed_callback_unset(gpio_t *gpio);

error_t *gpio_get_state(gpio_t *gpio, uint32_t id, bool *state);
error_t *gpio_set_state(gpio_t *gpio, uint32_t id, bool state);
