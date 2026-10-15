#pragma once

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <memory>
#include <string>
#include <utility>

// librenode declares functions with the same names as renode_api.h but with other signatures.
#define renode_get_machine librenode_get_machine
#define renode_get_gpio librenode_get_gpio
#define renode_set_gpio_state librenode_set_gpio_state
#include "librenode.h"
#undef renode_get_machine
#undef renode_get_gpio
#undef renode_set_gpio_state
#include "renode_api.h"

//  Parts shared by the hosts of tests/native-interface/bus-handlers.robot. Each host is one device
//  model that serves the guest's accesses to sysbus.dut through the external control API.
namespace native_host {

//  The guest ends each test by writing its result to this register of the device.
constexpr uint64_t test_end_address = 0x10000004;
constexpr uint64_t test_passed = 1;

//  The name of the host's connection among the externals of the emulation.
constexpr const char *connection_name = "nativeHost";

enum exit_code {
    exit_pass = 0,
    exit_mismatch = 1,
    exit_setup_error = 2,
};

inline uint64_t load_little_endian(const uint8_t *data, uint32_t size)
{
    uint64_t value = 0;
    assert(size <= sizeof(value));
    for(uint32_t i = 0; i < size; i++) {
        value |= static_cast<uint64_t>(data[i]) << (8 * i);
    }
    return value;
}

inline void store_little_endian(uint8_t *data, uint32_t size, uint64_t value)
{
    assert(size <= sizeof(value));
    for(uint32_t i = 0; i < size; i++) {
        data[i] = static_cast<uint8_t>(value >> (8 * i));
    }
}

inline bool execute_command(const std::string &command)
{
    const RenodeStatus status = renode_exec_command(command.c_str());
    if(status != RENODE_SUCCESS) {
        std::fprintf(stderr, "'%s' failed with status %d\n", command.c_str(), status);
        return false;
    }
    return true;
}

inline bool check(const char *operation, renode_error_t *error)
{
    if(error == NO_ERROR) {
        return true;
    }
    std::fprintf(stderr, "failed to %s: %s\n", operation, error->message ? error->message : "<no message>");
    renode_free_error(error);
    return false;
}

struct free_handle {
    void operator()(void *handle) const { std::free(handle); }
};

//  A handle that the external control library allocates with malloc.
template<typename T>
using handle = std::unique_ptr<T, free_handle>;

//  Calls an external control function that returns a new handle through its last parameter. The
//  handle is empty on failure.
template<typename T, typename Function, typename... Arguments>
handle<T> get_handle(const char *operation, Function function, Arguments... arguments)
{
    T *result = nullptr;
    if(!check(operation, function(arguments..., &result))) {
        return nullptr;
    }
    return handle<T>(result);
}

//  Serves the guest's read of `size` bytes at `address` by filling `data`. Returns whether the
//  access succeeded.
using read_handler = std::function<bool(uint64_t address, uint8_t *data, uint32_t size)>;

//  Serves the guest's write of the `size` bytes in `data` to `address`. Returns whether the access
//  succeeded.
using write_handler = std::function<bool(uint64_t address, const uint8_t *data, uint32_t size)>;

//  The external control handles that a host holds until it quits. Each operation reports its own
//  errors and returns whether it succeeded.
class external_control {
public:
    external_control() = default;
    //  Renode holds a pointer to this object once it is connected,
    //  so the object can't be copied or moved.
    external_control(const external_control &) = delete;
    external_control &operator=(const external_control &) = delete;

    //  Connects to Renode and serves the guest's accesses to the named bus peripheral of the named
    //  machine with the given handlers, which run on the Renode thread that makes the access.
    bool connect(const char *machine_name, const char *peripheral_name, read_handler on_read,
                 write_handler on_write)
    {
        serve_read = std::move(on_read);
        serve_write = std::move(on_write);

        if(!check("connect to Renode", renode_connect_in_process(connection_name, &renode))) {
            return false;
        }

        machine = get_handle<renode_machine_t>("get the machine", renode_get_machine, renode, machine_name);
        if(!machine) {
            return false;
        }

        proxy = get_handle<renode_bus_peripheral_t>("get the proxy", renode_get_bus_peripheral,
                                                    machine.get(), peripheral_name);
        if(!proxy) {
            return false;
        }

        return check("register the access callback",
                     renode_register_sysbus_access_callback(proxy.get(), SYSBUS_CB_BOTH, AW_CB_ANY,
                                                            this, serve_access));
    }

    handle<renode_gpio_t> get_gpio(const char *name)
    {
        return get_handle<renode_gpio_t>("get the GPIO", renode_get_gpio, machine.get(), name);
    }

    void disconnect()
    {
        if(renode != nullptr) {
            check("disconnect from Renode", renode_disconnect(&renode));
        }
        proxy.reset();
        machine.reset();
    }

private:
    static void serve_access(void *user_data, renode_sysbus_event_data_t *event)
    {
        auto &control = *static_cast<external_control *>(user_data);
        if(event->access_type == SYSBUS_CB_READ) {
            event->access_succeeded = control.serve_read(event->address, event->data, event->byte_count);
        } else {
            event->access_succeeded = control.serve_write(event->address, event->data, event->byte_count);
        }
    }

    renode_t *renode = nullptr;
    handle<renode_machine_t> machine;
    handle<renode_bus_peripheral_t> proxy;
    read_handler serve_read;
    write_handler serve_write;
};

//  Starts Renode in this process and loads the script named on the command line. The host then
//  connects and starts the emulation after any further setup.
inline bool load(int argc, char *argv[])
{
    if(argc != 2) {
        std::fprintf(stderr, "usage: %s <script.resc>\n", argv[0]);
        return false;
    }

    if(renode_init(nullptr, -1, -1) != RENODE_SUCCESS) {
        std::fprintf(stderr, "failed to start Renode\n");
        return false;
    }

    return execute_command(std::string("include @") + argv[1]);
}

inline void quit(external_control &control)
{
    control.disconnect();
    renode_exec_command("quit");
}

} // namespace native_host
