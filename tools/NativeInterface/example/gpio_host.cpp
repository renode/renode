#include <cinttypes>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <mutex>

#include "native_host.hpp"

using namespace native_host;

//  The device serves the guest's write to its start register by writing a word into guest RAM and
//  then pulsing the GPIO input high and back to low, so that the GPIO controller latches an
//  interrupt for the data. The device also watches a GPIO output that the guest drives, and its
//  output state register returns the last state that the state change callback reported. Each
//  change takes effect at the next synchronization point, so the guest waits for each change and
//  reports when it has seen all of them.

constexpr uint64_t start_address = 0x10000008;
constexpr uint64_t output_state_address = 0x10000010;
constexpr uint64_t data_address = 0x40100000;
constexpr uint32_t data_word = 0xcafe0001;

constexpr const char *machine_name = "bus-handlers";
constexpr const char *peripheral_name = "sysbus.dut";
constexpr const char *gpio_peripheral_name = "sysbus.gpio";
constexpr int gpio_input = 0;
constexpr int gpio_output = 1;

struct dut_state {
    std::mutex mutex;
    std::condition_variable test_ended;
    bool ended = false;
    uint64_t result = 0;
    handle<renode_gpio_t> gpio;
    handle<renode_bus_context_t> bus;
    bool output_state = false;
};

static bool set_gpio_input(renode_gpio_t *gpio, bool state)
{
    return check("set the GPIO input", renode_set_gpio_state(gpio, gpio_input, state));
}

static void on_gpio_output_change(void *user_data, renode_gpio_event_data_t *event)
{
    auto &state = *static_cast<dut_state *>(user_data);
    std::scoped_lock lock(state.mutex);
    state.output_state = event->state;
}

static bool dut_read(dut_state &state, uint64_t address, uint8_t *data, uint32_t size)
{
    uint64_t value = 0;
    if(address == output_state_address) {
        std::scoped_lock lock(state.mutex);
        value = state.output_state;
    }

    store_little_endian(data, size, value);
    return true;
}

static bool dut_write(dut_state &state, uint64_t address, const uint8_t *data, uint32_t size)
{
    const uint64_t value = load_little_endian(data, size);

    if(address == start_address) {
        if(!check("write the data", renode_sysbus_write(state.bus.get(), data_address, AW_DOUBLE_WORD, &data_word, 1))) {
            return false;
        }
        if(!set_gpio_input(state.gpio.get(), true)) {
            return false;
        }
        return set_gpio_input(state.gpio.get(), false);
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

    if(!check_usage(argc, argv)) {
        return exit_setup_error;
    }

    const auto on_read = [&state](auto... access) { return dut_read(state, access...); };
    const auto on_write = [&state](auto... access) { return dut_write(state, access...); };
    if(!control.connect(argv[1], machine_name, peripheral_name, on_read, on_write)) {
        return exit_setup_error;
    }

    state.gpio = control.get_gpio(gpio_peripheral_name);
    state.bus = control.get_sysbus();
    if(!state.gpio || !state.bus) {
        return exit_setup_error;
    }

    if(!check("register the GPIO output callback",
              renode_register_gpio_state_change_callback(state.gpio.get(), gpio_output, &state, on_gpio_output_change))) {
        return exit_setup_error;
    }

    if(!control.start()) {
        return exit_setup_error;
    }

    uint64_t result;
    {
        std::unique_lock lock(state.mutex);
        state.test_ended.wait(lock, [&state] { return state.ended; });
        result = state.result;
    }

    control.disconnect();

    if(result != test_passed) {
        std::fprintf(stderr, "the guest reported result 0x%" PRIx64 "\n", result);
        return exit_mismatch;
    }
    return exit_pass;
}
