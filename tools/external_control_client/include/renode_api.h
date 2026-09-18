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
 * Possible error codes.
 */
typedef enum {
    ERR_INVALID_CODE = -1, /**< Invalid error code */
    ERR_FATAL, /**< Fatal error */
    ERR_COMMAND_FAILED, /**< Command failed */
    ERR_INVALID_COMMAND, /**< Invalid command */
    ERR_INVALID_ARGUMENT, /**< Function called with invalid argument */
    ERR_CONNECTION_BUSY, /**< The Renode connection is busy and cannot be closed */
} renode_error_code_t;

/**
 * The structure describing the status of a finished operation.
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
 * @brief The API handle for the Renode connection.
 *
 * Renode handles are pointers to structs that are implemented internally, which must be prepared by calling
 * `renode_get_X` functions (renode_connect() for `renode_t`) so that they can be later used in their
 * related functions.
 *
 * The internal structs are not a part of the API.
 *
 * @note The memory that the handles point to is dynamically allocated, and should be freed when the handles are no longer needed.
 * That can be achieved by calling `free(*handle)` with the exception of the Renode connection API handle, which should be closed
 * by calling renode_disconnect().
 */
typedef struct renode renode_t;

/**
 * @brief The API handle for the Renode machine.
 *
 * @copydetails renode_t
 */
typedef struct renode_machine renode_machine_t;

/**
 * @brief The API handle for a Renode ADC peripheral.
 *
 * @copydetails renode_t
 */
typedef struct renode_adc renode_adc_t;

/**
 * @brief The API handle for a Renode GPIO controller.
 *
 * @copydetails renode_t
 */
typedef struct renode_gpio renode_gpio_t;

/**
 * @brief The API handle for a Renode CAN bus.
 *
 * @copydetails renode_t
 */
typedef struct renode_can renode_can_t;

/**
 * @brief The API handle for a Renode bus manager.
 *
 * @copydetails renode_t
 */
typedef struct renode_bus_context renode_bus_context_t;

/**
 * @brief A type of the Renode fatal error callback.
 */
typedef void (*renode_fatal_error_callback_t)(void *ud, renode_error_t *error);

/**
 * @brief The API handle for a Renode SPI peripheral.
 *
 * @copydetails renode_t
 */
typedef struct renode_spi renode_spi_t;

/**
 * @brief The API handle for a Renode External Bus peripheral.
 *
 * @copydetails renode_t
 */
typedef struct renode_bus_peripheral renode_bus_peripheral_t;

/**
 * @brief The function initializing the Renode connection.
 *
 * @note The connection should be closed using renode_disconnect() before the client app exits.
 *
 * @param[in] port - the TCP port
 * @param[out] renode - the Renode connection handle pointer
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_connect(const char *port, renode_t **renode);

/**
 * @brief The function closing the Renode connection and freeing the internal handle memory.
 *
 * @note After using this function, the internal handle memory is freed, so calling `free(*renode)` afterwards is invalid.
 *
 * @param[in] renode - the Renode connection handle pointer
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_disconnect(renode_t **renode);

/**
 * @brief The extended variant of the function to close the Renode connection and free the internal handle memory.
 *
 * @note After using this function, the internal handle memory is freed, so calling `free(*renode)` afterwards is invalid.
 *
 * @param[in] renode - the Renode connection handle pointer
 * @param[in] blocking - if false, the function may return an error with the code `ERR_CONNECTION_BUSY` to indicate
 * that the connection cannot be closed at this momment due to the command handlers currently running.
 * If true, this function will block in case of `ERR_CONNECTION_BUSY` being returned.
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_disconnect_ex(renode_t **renode, bool blocking);

/**
 * @brief The function preparing the machine handle.
 *
 * @note The handle's internal memory is dynamically allocated, so `*machine` should be freed when it's no longer used.
 *
 * @param[in] renode - the Renode connection handle
 * @param[in] name - the name of the machine to fetch
 * @param[out] machine - the Renode machine handle
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_machine(renode_t *renode, const char *name, renode_machine_t **machine);

/**
 * @brief The function deallocating an error structure's memory.
 *
 * The function should be run every time any of the functions return a valid error structure pointer.
 * By default, those functions return `NULL`.
 *
 * @param[in] error - the error structure
 */
void renode_free_error(renode_error_t *error);

/**
 * @brief The function setting a callback to be called when the library encounters an unrecoverable error.
 *
 * The callback can be used to perform any application-specific cleanup routines before the application terminates.
 *
 * @param[in] renode - the Renode connection handle
 * @param[in] user_data - the pointer to the data passed to the callback when invoked
 * @param[in] callback - the callback to be invoked when an unrecoverable error occurs
 */
void renode_set_fatal_error_callback(renode_t *renode, void *user_data, renode_fatal_error_callback_t callback);


/* Time control */

/**
 * The supported time units.
 */
typedef enum {
    TU_NANOSECONDS  =          1, /**< Nanoseconds */
    TU_MICROSECONDS =       1000, /**< Microseconds */
    TU_MILLISECONDS =    1000000, /**< Milliseconds */
    TU_SECONDS      = 1000000000, /**< Seconds */
} renode_time_unit_t;

/**
 * @brief Renode's virtual time.
 *
 * The virtual time is represented by an unsigned integer in an unspecified time unit.
 * It is safe to perform comparision (<, >, <=, >=, !=, ==), addition (+, +=) and subtraction (-, -=) operations
 * between two instances of `renode_time_t`.
 *
 * Use renode_create_time(), renode_time_to_time_unit() or renode_time_to_seconds()
 * to create or convert the virtual time.
 */
typedef uint64_t renode_time_t;

/**
 * @brief The function creating Renode's virtual time value.
 *
 * @param[in] value - the time, expressed in the given unit
 * @param[in] unit - the unit in which the given time is expressed
 * @param[out] time - the Renode time instance
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_create_time(uint64_t value, renode_time_unit_t unit, renode_time_t *time);

/**
 * @brief The function converting Renode's virtual time to an integer time value expressed in a specified unit.
 *
 * @note The function floors the result of the conversion.
 *
 * @param[in] time - the Renode time instance
 * @param[in] unit - the unit in which the given time is expressed (see renode_time_unit_t); the caller is responsible for ensuring that the passed unit is valid
 * @return A time value in a given unit.
 */
uint64_t renode_time_to_time_unit(renode_time_t time, renode_time_unit_t unit);

/**
 * @brief The function converting Renode's timestamp into seconds.
 *
 * @param[in] time - the Renode time instance
 * @return A floating-point timestamp equivalent in seconds.
 * @note The result is precise down to one nanosecond.
 * Decimal places smaller than 10E-9 are conversion arifacts.
 * The result keeps the nanosecond-precison up to around 93 days of virtual time - 
 * for higher values, precision gradually degradates.
 */
double renode_time_to_seconds(renode_time_t time);

/**
 * @brief The function specifying that the emulation should run for a given amount of time.
 *
 * @param[in] renode - the Renode connection handle
 * @param[in] time - the duration of virtual time that the emulation should execute for
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_run_for(renode_t *renode, renode_time_t time);

/**
 * @brief The function fetching the current virtual time of the emulation.
 *
 * @param[in] renode - the Renode connection handle
 * @param[out] current_time - the current virtual time of the emulation
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_current_time(renode_t *renode, renode_time_t *current_time);

/**
 * @brief The type of the Renode time-elapsed callback.
 */
typedef void (*renode_time_elapsed_callback_t)(void *ud, renode_time_t *timestamp);

/**
 * @brief The function registering a callback that will be called after a quantum of time elapses in Renode.
 *
 * @param[in] renode - the Renode connection handle
 * @param[in] user_data - the pointer to the data passed to the callback when invoked
 * @param[in] callback - the callback to be invoked when a quantum of time elapses in Renode
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_register_time_elapsed_callback(renode_t *renode, void *user_data, renode_time_elapsed_callback_t callback);
/* ADC */

/**
 * @brief The function preparing the ADC handle.
 *
 * @note The handle's internal memory is dynamically allocated, so `*adc` should be freed when it's no longer used.
 *
 * @param[in] machine - the machine handle
 * @param[in] name - the ADC peripheral's name
 * @param[out] adc - the handle associated with the requested ADC peripheral
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_adc(renode_machine_t *machine, const char *name, renode_adc_t **adc);


/**
 * @brief The function fetching the number of channels of the ADC.
 *
 * @param[in] adc - the ADC handle
 * @param[out] count - the number of the ADC channels
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_adc_channel_count(renode_adc_t *adc, int32_t *count);

/**
 * @brief The function fetching an ADC channel's value.
 *
 * @param[in] adc - the ADC handle
 * @param[in] channel - the ADC channel index
 * @param[out] value - the current ADC channel value
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t *value);

/**
 * @brief The function setting an ADC channel's value.
 *
 * @param[in] adc - the ADC handle
 * @param[in] channel - the ADC channel index
 * @param[in] value - the requested ADC channel value
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_set_adc_channel_value(renode_adc_t *adc, int32_t channel, uint32_t value);

/* GPIO */

/**
 * @brief The function preparing the GPIO controller handle.
 *
 * @note The handle's internal memory is dynamically allocated, so `*gpio` should be freed when it's no longer used.
 *
 * @param[in] machine - the machine handle
 * @param[in] name - the name of the GPIO controller
 * @param[out] gpio - the handle associated with the requested GPIO controller
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_gpio(renode_machine_t *machine, const char *name, renode_gpio_t **gpio);

/**
 * @brief The function fetching the GPIO state.
 *
 * @param[in] gpio - the GPIO controller handle
 * @param[in] id - the GPIO's index in the given GPIO controller
 * @param[out] state - the current GPIO state
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_gpio_state(renode_gpio_t *gpio, int32_t id, bool *state);

/**
 * @brief The function setting the GPIO state.
 *
 * @param[in] gpio - the GPIO controller handle
 * @param[in] id - the GPIO's index in the given GPIO controller
 * @param[in] state - the requested GPIO state
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_set_gpio_state(renode_gpio_t *gpio, int32_t id, bool state);

/**
 * The GPIO state-change event data.
 */
typedef struct __attribute__((packed)) {
    /** The virtual time at which the event occured */
    renode_time_t time;
    /** The new GPIO state */
    bool state;
} renode_gpio_event_data_t;

/**
 * @brief The function registering the callback when the GPIO state changes.
 *
 * @param[in] gpio - the GPIO controller handle
 * @param[in] id - the GPIO's index in the given GPIO controller
 * @param[in] user_data - the pointer to the data passed to the callback when invoked
 * @param[in] callback - the callback to be invoked when the GPIO state with the given index changes
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_register_gpio_state_change_callback(renode_gpio_t *gpio, int32_t id, void *user_data, void (*callback)(void *, renode_gpio_event_data_t *));

/**
 * The custom command event data.
 */
 typedef struct {
    /** The virtual time at which the event occured */
    renode_time_t time;
    /** The command string */
    char command[];
} renode_custom_command_event_data_t;

/**
 * The custom command user data
 */
typedef struct {
    /** The command valid flag */
    bool command_valid;
    /** The pointer to response string */
    char response_string[];
} renode_custom_command_response_data_t;

typedef renode_custom_command_response_data_t * (*renode_custom_command_callback_t)(void *ud, renode_custom_command_event_data_t *event_data);

/**
 * @brief The function registering callback on custom command. The callback function returns a pointer to the `renode_custom_command_callback_t` struct which it allocates.
 *  This pointer is freed in the `invoke_callback` function.
 *
 * @param[in] renode - the Renode handle
 * @param[in] user_data - the pointer to the data passed to the callback when invoked
 * @param[in] callback - the callback to be invoked when a custom command is issued
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_register_custom_command_callback(renode_t *renode, void *user_data, renode_custom_command_callback_t callback);


/* CAN */
/**
 * Maximum size of the CAN Frame in bytes, that the client can handle.
 */
#define MAX_CAN_FRAME_SIZE 64

/**
 * The CAN bus event data.
 */
typedef struct {
    /** The timestamp of when the packet was sent  */
    renode_time_t time;
    /** The length of the CAN frame in bytes */
    int32_t packet_length;
    /** The ID of the CAN frame */
    uint32_t packet_id;
    /** The payload of the CAN frame */
    uint8_t packet[];
} renode_can_event_data_t;

typedef void (*renode_can_event_callback_t)(void *user_data, renode_can_event_data_t *event_data);

/**
 * @brief The function preparing the CAN handle.
 *
 * @note The handle's internal memory is dynamically allocated, so `*can` should be freed when no longer used.
 *
 * @param[in] machine - the machine handle
 * @param[in] name - the CAN Bus peripheral name
 * @param[out] can - the handle associated with the requested CAN instance
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_can(renode_machine_t *machine, const char *name, renode_can_t **can);

/**
 * @brief The function registering the callback when a CAN message is received.
 *
 * @param[in] can - the CAN instance handle
 * @param[in] user_data - the pointer to the data passed to the callback when invoked
 * @param[in] callback - the callback to be invoked when a message is received
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_register_can_callback(renode_can_t *can, void *user_data, renode_can_event_callback_t callback);

/**
 * @brief The function sending a CAN message.
 *
 * @param[in] can - the CAN instance handle
 * @param[in] packet - the pointer to the CAN packet payload
 * @param[in] packet_length - the length of the packet to be sent
 * @param[in] packet_id - the packet ID
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_send_can_message(renode_can_t *can, void *packet, int packet_length, uint32_t packet_id);
 

/* System bus */

/**
 * The supported access width options.
 */
typedef enum {
    AW_BYTE        = 1, /**< Byte access */
    AW_WORD        = 2, /**< Word (2B) access */
    AW_DOUBLE_WORD = 4, /**< Double word (4B) access */
    AW_QUAD_WORD   = 8, /**< Quad word (8B) access */
    AW_MULTI_BYTE  = 128, /**< Multibyte access (number of bytes defined by `count`) */

    /** Any access width for the purpose of callback filtering */
    AW_CB_ANY      = (AW_BYTE | AW_WORD | AW_DOUBLE_WORD | AW_QUAD_WORD | AW_MULTI_BYTE),
} renode_access_width_t;

/**
 * The supported accesses to the Renode system bus.
 */
typedef enum {
    /** Read on the bus */
    SYSBUS_CB_READ  = (1 << 0),
    /** Write on the bus */
    SYSBUS_CB_WRITE = (1 << 1),
    /** Any access type for the purpose of callback filtering */
    SYSBUS_CB_BOTH  = (SYSBUS_CB_WRITE | SYSBUS_CB_READ),
} renode_access_type_t;

/**
 * @brief The function preparing the bus handle with the emulation element context.
 *
 * The context is used to imitate bus access made by specific bus managers like CPU, DMA, etc.
 * `"sysbus"` can be passed as `name` if bus accesses should be made with global context.
 *
 * Please note that access made using a handle with the emulation element context still needs to
 * use absolute addresses so they are equivalent to Renode's `sysbus Read<width> <address> context=<name>`
 * rather than `<name> Read<width> <address>`, which treats addresses as relative to `<name>` peripheral's
 * registration base address.
 *
 * @note The handle's internal memory is dynamically allocated, so `*ctx` should be freed when no longer used.
 *
 * @param[in] machine - the machine handle
 * @param[in] name - the emulation element's name in which the context bus accesses should be made
 * @param[out] ctx - the handle for performing the bus access with the context of the specified emulation element
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_bus_context(renode_machine_t *machine, const char *name, renode_bus_context_t **ctx);

/**
 * @brief The function fetching the name of the bus context.
 *
 * @param[in] ctx - the bus context
 * @param[out] name - fully qualified name of the bus context in the format "<machine name>.<context name>", must be freed
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_bus_context_name(renode_bus_context_t *ctx, char **name);

/**
 * @brief The function preparing the bus handle with global context.
 *
 * This is a convenience wrapper, equivalent to renode_get_bus_context() with `name="sysbus"`.
 *
 * @note The handle's internal memory is dynamically allocated, so `*sysbus` should be freed when no longer used.
 *
 * @param[in] machine - the machine handle
 * @param[out] sysbus - the handle for performing bus access with global context
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_sysbus(renode_machine_t *machine, renode_bus_context_t **sysbus);

/**
 * @brief The function calculating the byte count from the given access width and transfer count.
 *
 * @param[in] width - the width of the transfer
 * @param[in] count - the count of the transfers
 * @param[out] byte_count - the count of accessed bytes
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_byte_count(renode_access_width_t width, uint32_t count, uint32_t *byte_count);

/**
 * @brief The function reading data from the system bus.
 *
 * @param[in] ctx - the bus handle
 * @param[in] address - the absolute address of the read
 * @param[in] width - the width of the read
 * @param[in] buffer - the buffer for the read data
 * @param[in] count - the number of requested reads (total data size will be `width * count`)
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_sysbus_read(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, void *buffer, uint32_t count);

/**
 * @brief The function writing data to the system bus.
 *
 * @param[in] ctx - the bus handle
 * @param[in] address - the absolute address of the access
 * @param[in] width - the access width
 * @param[in] buffer - the buffer with the data to write to the bus
 * @param[in] count - the number of requested writes (total data size is `width * count`)
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_sysbus_write(renode_bus_context_t *ctx, uint64_t address, renode_access_width_t width, const void *buffer, uint32_t count);

/**
 * @brief The structure storing information about an access event to Renode's system bus.
 */
typedef struct {
    /** The timestamp of when the event occured */
    renode_time_t timestamp;
    /** The read or write transaction */
    renode_access_type_t access_type;
    /** The access address */
    uint64_t address;
    /** The access width of a transfer */
    renode_access_width_t width;
    /**
      * The count of transfers of the width specified by renode_sysbus_event_data_t::width.
      *
      * Use renode_get_byte_count() to calculate byte count.
      */
    uint32_t transfer_count;
    /** The flag indicating that the access was successful */
    bool access_succeeded;
    /** The bytes that are written or will be read, allocated and freed by the library */
    _Alignas(uint64_t) uint8_t data[];
} renode_sysbus_event_data_t;

typedef void (*renode_sysbus_event_callback_t)(void *user_data, renode_sysbus_event_data_t *event_data);

/**
 * @brief The function preparing the Bus peripheral handle.
 *
 * The peripheral must be a `Bus.ExternalControlBusPeripheral`.
 *
 * @note The internals of the handle are dynamically allocated, so `*bus_peripheral` should be freed when no longer used.
 *
 * @param[in] machine - the machine handle
 * @param[in] name - the Bus peripheral's name
 * @param[out] bus_peripheral - the handle associated with the requested External Bus peripheral
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_bus_peripheral(renode_machine_t *machine, const char *name, renode_bus_peripheral_t **bus_peripheral);

/**
 * @brief The function registering a callback when Renode's system bus is accessed.
 *
 * @param[in] bus_peripheral - the platform peripheral handle
 * @param[in] access_type - the access types for which the callback will be invoked
 * @param[in] width - the widths for which the callback will be invoked
 * @param[in] user_data - the pointer to the data passed to the callback when invoked
 * @param[in] callback - the callback to be invoked when Renode's system bus is accessed for the given access types and widths.
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 *
 * All callbacks should set renode_sysbus_event_data_t::access_succeeded to true.
 * By default, it is false.
 * If renode_sysbus_event_data_t::access_type is ::SYSBUS_READ, then the callback should set renode_sysbus_event_data_t::data to true.
 * By default, it is all zeros, and can be ommited if the access doesn't succeed.
 */
renode_error_t *renode_register_sysbus_access_callback(renode_bus_peripheral_t *bus_peripheral, renode_access_type_t access_type, renode_access_width_t width, void *user_data, renode_sysbus_event_callback_t callback);


/* SPI */

/**
 * @brief The function preparing the SPI peripheral handle.
 *
 * The peripheral must be a `SPI.ExternalControlSPIPeripheral`
 *
 * @note The handle's internal memory is dynamically allocated, so `*spi` should be freed when no longer used.
 *
 * @param[in] machine -the machine handle
 * @param[in] name - the SPI peripheral name
 * @param[out] spi - the handle associated with the requested SPI peripheral
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_get_spi(renode_machine_t *machine, const char *name, renode_spi_t **spi);

/**
 * The SPI transmit callback is invoked for every byte the master sends to the slave (MOSI).
 * It returns the byte that the slave transmits on the bus in exchange (MISO).
 *
 * @param[in] user_data - the pointer passed at registration
 * @param[in] mosi - the byte received from the master
 * @return - the MISO byte to return to the master
 */
typedef uint8_t (*renode_spi_transmit_callback_t)(void *user_data, uint8_t mosi);

/**
 * The SPI finish-transmission callback is invoked when the master ends the transfer (CS deasserted).
 *
 * @param[in] user_data - the pointer passed at registration
 */
typedef void (*renode_spi_finish_callback_t)(void *user_data);

/**
 * @brief The function registering live callbacks for an ExternalControlSPIPeripheral slave.
 *
 * After registration, the callbacks fire, while the emulation advances (i.e. during
 * renode_run_for()). `on_transmit` supplies the MISO byte for each master beat, and
 * `on_finish` is notified at the end of a transfer.
 *
 * @param[in] spi - the SPI handle
 * @param[in] user_data - the pointer passed to both callbacks when invoked
 * @param[in] on_transmit - the callback returning the MISO byte for each received MOSI byte
 * @param[in] on_finish - the callback invoked when the transfer finishes (may be NULL)
 * @return A pointer to the error structure if an error occurred, otherwise NULL.
 */
renode_error_t *renode_spi_register_callbacks(renode_spi_t *spi, void *user_data,
    renode_spi_transmit_callback_t on_transmit, renode_spi_finish_callback_t on_finish);
