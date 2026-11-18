#pragma once

#include <cassert>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <functional>
#include <future>
#include <memory>
#include <utility>

#include "renode_api.h"

//  Parts shared by the native hosts of the tests in tests/native-interface. Most hosts are one
//  device model that serves the guest's accesses to sysbus.dut through the external control API.
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
    exit_runtime_error = 3,
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
    void operator()(void *handle) const
    {
        std::free(handle);
    }
};

//  A handle that the external control library allocates with malloc.
template <typename T> using handle = std::unique_ptr<T, free_handle>;

//  Calls an external control function that returns a new handle through its last parameter. The
//  handle is empty on failure.
template <typename T, typename Function, typename... Arguments>
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

    //  Starts Renode in this process, connects to it, runs the script, which creates the machines, and gets the
    //  named machine.
    bool connect(const char *script_path, const char *machine_name)
    {
        renode_in_process_options_t options = {};
        options.serialize_requests = true;
        if(!check("connect to Renode", renode_connect_in_process(connection_name, &options, &renode))) {
            return false;
        }
        if(!check("run the script", renode_run_script(renode, script_path))) {
            return false;
        }

        machine = get_handle<renode_machine_t>("get the machine", renode_get_machine, renode, machine_name);
        return machine != nullptr;
    }

    //  Connects to Renode and serves the guest's accesses to the named bus peripheral of the named
    //  machine with the given handlers. Each access is served on a thread of its own, the way
    //  another simulator runs its device models on threads of its own, while the Renode thread that
    //  makes the access waits for it.
    bool connect(const char *script_path, const char *machine_name, const char *peripheral_name, read_handler on_read,
                 write_handler on_write)
    {
        serve_read = std::move(on_read);
        serve_write = std::move(on_write);
        if(!connect(script_path, machine_name)) {
            return false;
        }

        proxy = get_handle<renode_bus_peripheral_t>("get the proxy", renode_get_bus_peripheral, machine.get(), peripheral_name);
        if(!proxy) {
            return false;
        }

        return check("register the access callback",
                     renode_register_sysbus_access_callback(proxy.get(), SYSBUS_CB_BOTH, AW_CB_ANY, this, serve_access));
    }

    handle<renode_gpio_t> get_gpio(const char *name)
    {
        return get_handle<renode_gpio_t>("get the GPIO", renode_get_gpio, machine.get(), name);
    }

    handle<renode_bus_context_t> get_sysbus()
    {
        return get_handle<renode_bus_context_t>("get the system bus", renode_get_sysbus, machine.get());
    }

    //  Starts the emulation, which then runs freely until the host quits.
    bool start()
    {
        return check("start the emulation", renode_start(renode));
    }

    //  Sets the virtual time between the synchronization points of the emulation.
    bool set_quantum(std::chrono::nanoseconds quantum)
    {
        renode_time_t time;
        if(!check("create the quantum", renode_create_time(quantum.count(), TU_NANOSECONDS, &time))) {
            return false;
        }
        return check("set the quantum", renode_set_quantum(renode, time));
    }

    //  Runs the emulation for `milliseconds` of virtual time and returns when the time has passed.
    bool run_for(uint64_t milliseconds)
    {
        renode_time_t time;
        if(!check("create the run time", renode_create_time(milliseconds, TU_MILLISECONDS, &time))) {
            return false;
        }
        return check("run the emulation", renode_run_for(renode, time));
    }

    //  Disconnects from Renode, which ends it.
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

        const auto serve = [&control, event] {
            if(event->access_type == SYSBUS_CB_READ) {
                return control.serve_read(event->address, event->data, event->byte_count);
            }
            return control.serve_write(event->address, event->data, event->byte_count);
        };

        event->access_succeeded = std::async(std::launch::async, serve).get();
    }

    renode_t *renode = nullptr;
    handle<renode_machine_t> machine;
    handle<renode_bus_peripheral_t> proxy;
    read_handler serve_read;
    write_handler serve_write;
};

//  Checks that the command line names the script, which the host passes to `external_control::connect`.
inline bool check_usage(int argc, char *argv[])
{
    if(argc != 2) {
        std::fprintf(stderr, "usage: %s <script.resc>\n", argv[0]);
        return false;
    }
    return true;
}

}  //  namespace native_host
