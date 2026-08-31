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
    ERR_INVALID_ARGUMENT, /**< function called with invalid argument */
    ERR_CONNECTION_BUSY, /**< Renode connection is busy and cannot be closed */
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
 * @brief Renode CAN bus API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_can renode_can_t;

/**
 * @brief Renode bus manager API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_bus_context renode_bus_context_t;

/**
 * @brief Type of the Renode fatal error callback
 */
typedef void (*renode_fatal_error_callback_t)(void *ud, renode_error_t *error);

/**
 * @brief Renode SPI peripheral API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_spi renode_spi_t;

/**
 * @brief Renode External Bus peripheral API handle
 *
 * @copydetails renode_t
 */
typedef struct renode_bus_peripheral renode_bus_peripheral_t;

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
 * @brief Extended variant of the function closing Renode connection and freeing internal handle memory
 *
 * @note The internal handle memory is freed so calling `free(*renode)` after calling this function is invalid.
 *
 * @param[in] renode Renode connection handle pointer
 * @param[in] blocking if false the function may return an error with code `ERR_CONNECTION_BUSY` to indicate
 * that connection cannot be closed at this momment due to the fact that command handlers are currently running.
 * if true this function will block in case where `ERR_CONNECTION_BUSY` would be returned.
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_disconnect_ex(renode_t **renode, bool blocking);

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

/**
 * @brief Function setting a callback, which will be called when the library encounters a unrecoverable error
 *
 * The callback can be used to perform any application specific cleanup routines, before the application terminates.
 *
 * @param[in] renode Renode connection handle
 * @param[in] user_data pointer to data passed to the callback when it's invoked
 * @param[in] callback callback to be invoked when a unrecoverable error occures
 */
void renode_set_fatal_error_callback(renode_t *renode, void *user_data, renode_fatal_error_callback_t callback);


/* Time control */

/**
 * Supported time units
 */
typedef enum {
    TU_NANOSECONDS  =          1, /**< nanoseconds */
    TU_MICROSECONDS =       1000, /**< microseconds */
    TU_MILLISECONDS =    1000000, /**< milliseconds */
    TU_SECONDS      = 1000000000, /**< seconds */
} renode_time_unit_t;

/**
 * @brief Renode virtual time
 *
 * Represented by an unsigned integer in an unspecified time unit.
 * It is safe to perform comparision (<, >, <=, >=, !=, ==), addition (+, +=) and subtraction (-, -=) operations
 * between two instances of renode_time_t.
 *
 * Use renode_create_time(), renode_time_to_time_unit() or renode_time_to_seconds()
 * to convert in a preferred way
 */
typedef uint64_t renode_time_t;

/**
 * @brief Function creating Renode time value
 *
 * @param[in] value time expressed in the given unit
 * @param[in] unit unit in which the given time is expressed
 * @param[out] time Renode time instance
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_create_time(uint64_t value, renode_time_unit_t unit, renode_time_t *time);

/**
 * @brief Function converting Renode's time to an integer time value expressed in a specified unit
 *
 * The function floors the result of calculation.
 *
 * @param[in] time Renode's time
 * @param[in] unit a unit the given time value is expressed in (see renode_time_unit_t), caller is responsible for ensuring that the passed unit is valid
 * @return time value in a give unit
 */
uint64_t renode_time_to_time_unit(renode_time_t time, renode_time_unit_t unit);

/**
 * @brief Function converting Renode timestamp to seconds
 *
 * @param[in] time Renode's time
 * @return floating point timestamp equivalent in seconds
 * @note Result is precise up to one nanosecond.
 * Decimal places smaller than 10E-9 are conversion arifacts.
 * Result keeps nanosecond-precison up to around 93 days of virtual time,
 * for higher values precision gradually degradates.
 */
double renode_time_to_seconds(renode_time_t time);

/**
 * @brief Function ordering emulation to run for a specified time
 *
 * @param[in] renode Renode connection handle
 * @param[in] time amout of virtual time that the emulation should execute for
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_run_for(renode_t *renode, renode_time_t time);

/**
 * @brief Function getting current emulation virtual time
 *
 * @param[in] renode Renode connection handle
 * @param[out] current_time current emulation virtual time
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_current_time(renode_t *renode, renode_time_t *current_time);

/**
 * @brief Type of the Renode time elapsed callback
 */
typedef void (*renode_time_elapsed_callback_t)(void *ud, renode_time_t *timestamp);

/**
 * @brief Function registering a callback, that will be called after a quantum of time elapses in Renode
 *
 * @param[in] renode Renode connection handle
 * @param[in] user_data pointer to data passed to the callback when it's invoked
 * @param[in] callback callback to be invoked when a quantum of time elapses in Renode
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_register_time_elapsed_callback(renode_t *renode, void *user_data, renode_time_elapsed_callback_t callback);
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
    /** Virtual time at which the event occured */
    renode_time_t time;
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


/* CAN */

#define MAX_CAN_FRAME_SIZE 64

/**
 * CAN bus event data
 */
typedef struct {
    renode_time_t time;
    int32_t packet_length;
    uint32_t packet_id;
    uint8_t packet[];
} renode_can_event_data_t;

/**
 * @brief Function preparing CAN handle
 *
 * @note Handle's internal memory is dynamically allocated so `*can` should be freed when it's no longer used.
 *
 * @param[in] machine machine handle
 * @param[in] name CANBus name
 * @param[out] can handle associated with the requested CAN instance
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_can(renode_machine_t *machine, const char *name, renode_can_t **can);

/**
 * @brief Function registering callback when CAN message is received
 *
 * @param[in] can CAN instance handle
 * @param[in] user_data pointer to data passed to the callback when it's invoked
 * @param[in] callback callback to be invoked when message is received
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_register_can_callback(renode_can_t *can, void *user_data, void (*callback)(void *, renode_can_event_data_t *));

/**
 * @brief Function sending CAN message
 *
 * @param[in] can CAN instance handle
 * @param[in] packet pointer to fixed size, 64 byte can packet array
 * @param[in] packet_length length of send packet
 * @param[in] packet_id packet_id
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_send_can_message(renode_can_t *can, void *packet, int packet_length, uint32_t packet_id);
 

/* System bus */

/**
 * Supported access width options
 */
typedef enum {
    AW_BYTE        = 1, /**< byte access */
    AW_WORD        = 2, /**< word (2B) access */
    AW_DOUBLE_WORD = 4, /**< double word (4B) access */
    AW_QUAD_WORD   = 8, /**< quad word (8B) access */
    AW_MULTI_BYTE  = 128, /**< multibyte access (number of bytes defined by `count`) */

    /** Any access width for the purpose of callback filtering */
    AW_CB_ANY      = (AW_BYTE | AW_WORD | AW_DOUBLE_WORD | AW_QUAD_WORD | AW_MULTI_BYTE),
} renode_access_width_t;

/**
 * Supported accesses to Renode system bus
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
 * @brief Function giving a name of bus context
 *
 * @param[in] ctx bus context
 * @param[out] name fully qualified name of the bus context in format "<machine name>.<context name>", must be freed
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_bus_context_name(renode_bus_context_t *ctx, char **name);

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
 * @brief Function calculating the byte count from the given access width and transfer count
 *
 * @param[in] width width of transfer
 * @param[in] count count of transfers
 * @param[out] byte_count count of accessed bytes
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_byte_count(renode_access_width_t width, uint32_t count, uint32_t *byte_count);

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

/**
 * @brief Structure storing information about an event of access to Renode system bus
 */
typedef struct {
    /** Timestamp when the event occured */
    renode_time_t timestamp;
    /** Read or write transaction */
    renode_access_type_t access_type;
    /** Address of the access */
    uint64_t address;
    /** Access width of a transfer */
    renode_access_width_t width;
    /**
      * Count of transfers of the width specified by renode_sysbus_event_data_t::width
      *
      * Use renode_get_byte_count() to calculate byte count
      */
    uint32_t transfer_count;
    /** Flag indicating that the access was successful */
    bool access_succeeded;
    /** Bytes that are written or will be read, allocated and freed by the library */
    _Alignas(uint64_t) uint8_t data[];
} renode_sysbus_event_data_t;

typedef void (*renode_sysbus_event_callback_t)(void *user_data, renode_sysbus_event_data_t *event_data);

/**
 * @brief Function preparing Bus peripheral handle
 *
 * The peripheral must be a `Bus.ExternalControlBusPeripheral`
 *
 * @note Internals of the handle are dynamically allocated so `*bus_peripheral` should be freed when it's no longer used.
 *
 * @param[in] machine machine handle
 * @param[in] name Bus peripheral's name
 * @param[out] peripheral handle associated with the requested External Bus peripheral
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_bus_peripheral(renode_machine_t *machine, const char *name, renode_bus_peripheral_t **bus_peripheral);

/**
 * @brief Function registering callback when Renode system bus is accessed
 *
 * @param[in] bus_peripheral platform peripheral handle
 * @param[in] access_type access types for which the callback will be invoked
 * @param[in] width widths for which the callback will be invoked
 * @param[in] user_data pointer to data passed to the callback when it's invoked
 * @param[in] callback callback to be invoked when Renode system bus is accessed for the given access types and widths
 * @return a pointer to error structure if error occurred, otherwise NULL
 *
 * All callbacks should set renode_sysbus_event_data_t::access_succeeded,
 * by default it is false.
 * If renode_sysbus_event_data_t::access_type is ::SYSBUS_READ then the callback should set renode_sysbus_event_data_t::data,
 * by default it is all zeros and can be ommited if the access doesn't succeed.
 */
renode_error_t *renode_register_sysbus_access_callback(renode_bus_peripheral_t *bus_peripheral, renode_access_type_t access_type, renode_access_width_t width, void *user_data, renode_sysbus_event_callback_t callback);


/* SPI */

/**
 * @brief Function preparing SPI peripheral handle
 *
 * The peripheral must be a `SPI.ExternalControlSPIPeripheral`
 *
 * @note Handle's internal memory is dynamically allocated so `*spi` should be freed when it's no longer used.
 *
 * @param[in] machine machine handle
 * @param[in] name SPI peripheral's name
 * @param[out] spi handle associated with the requested SPI peripheral
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_get_spi(renode_machine_t *machine, const char *name, renode_spi_t **spi);

/**
 * SPI transmit callback: invoked for every byte the master sends to the slave (MOSI).
 * Returns the byte the slave puts on the bus in exchange (MISO) for that beat.
 *
 * @param[in] user_data pointer passed at registration
 * @param[in] mosi the byte received from the master
 * @return the MISO byte to return to the master
 */
typedef uint8_t (*renode_spi_transmit_callback_t)(void *user_data, uint8_t mosi);

/**
 * SPI finish-transmission callback: invoked when the master ends the transfer (CS deasserted).
 *
 * @param[in] user_data pointer passed at registration
 */
typedef void (*renode_spi_finish_callback_t)(void *user_data);

/**
 * @brief Function registering live callbacks for an ExternalControlSPIPeripheral slave
 *
 * After registration, the callbacks fire while the emulation advances (i.e. during
 * renode_run_for()): `on_transmit` supplies the MISO byte for each master beat, and
 * `on_finish` is notified at the end of a transfer.
 *
 * @param[in] spi SPI handle
 * @param[in] user_data pointer passed to both callbacks when invoked
 * @param[in] on_transmit callback returning the MISO byte for each received MOSI byte
 * @param[in] on_finish callback invoked when the transfer finishes (may be NULL)
 * @return a pointer to error structure if error occurred, otherwise NULL
 */
renode_error_t *renode_spi_register_callbacks(renode_spi_t *spi, void *user_data,
    renode_spi_transmit_callback_t on_transmit, renode_spi_finish_callback_t on_finish);
