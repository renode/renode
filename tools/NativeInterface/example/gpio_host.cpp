#include <cinttypes>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <mutex>

#include "native_host.hpp"

using namespace native_host;

//  A device that sets the GPIO input when the guest writes its start register and clears it when
//  the guest writes its clear register, both from inside the write handler. The guest reports
//  whether it read each change right after its write.

constexpr uint64_t start_address = 0x10000008;
constexpr uint64_t clear_address = 0x1000000c;

constexpr const char *machine_name = "bus-handlers";
constexpr const char *peripheral_name = "sysbus.dut";
constexpr const char *gpio_peripheral_name = "sysbus.gpio";
constexpr int gpio_input = 0;

struct dut_state {
    std::mutex mutex;
    std::condition_variable test_ended;
    bool ended = false;
    uint64_t result = 0;
    handle<renode_gpio_t> gpio;
};

static bool set_gpio_input(renode_gpio_t *gpio, bool state)
{
    return check("set the GPIO input", renode_set_gpio_state(gpio, gpio_input, state));
}

static bool dut_read(uint64_t, uint8_t *data, uint32_t size)
{
    store_little_endian(data, size, 0);
    return true;
}

static bool dut_write(dut_state &state, uint64_t address, const uint8_t *data, uint32_t size)
{
    const uint64_t value = load_little_endian(data, size);
    if(address == start_address) {
        if(!set_gpio_input(state.gpio.get(), true)) {
            return false;
        }
    } else if(address == clear_address) {
        if(!set_gpio_input(state.gpio.get(), false)) {
            return false;
        }
    } else if(address == test_end_address) {
        std::scoped_lock lock(state.mutex);
        state.result = value;
        state.ended = true;
        state.test_ended.notify_one();
    }
    return true;
}

int main(int argc, char *argv[])
{
    dut_state state;
    external_control control;
    if(!load(argc, argv)) {
        return exit_setup_error;
    }

    const auto on_write = [&state](auto... access) { return dut_write(state, access...); };
    if(!control.connect(machine_name, peripheral_name, dut_read, on_write)) {
        return exit_setup_error;
    }

    state.gpio = control.get_gpio(gpio_peripheral_name);
    if(!state.gpio || !execute_command("start")) {
        return exit_setup_error;
    }

    uint64_t result;
    {
        std::unique_lock lock(state.mutex);
        state.test_ended.wait(lock, [&state] { return state.ended; });
        result = state.result;
    }

    quit(control);

    if(result != test_passed) {
        std::fprintf(stderr, "the guest reported result 0x%" PRIx64 "\n", result);
        return exit_mismatch;
    }
    return exit_pass;
}
