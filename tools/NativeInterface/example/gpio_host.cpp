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

constexpr const char *gpio_peripheral_name = "sysbus.gpio";
constexpr int gpio_input = 0;

struct dut_state {
    std::mutex mutex;
    std::condition_variable test_ended;
    bool ended = false;
    uint64_t result = 0;
    RenodeGpio *gpio = nullptr;
};

static bool set_gpio_input(RenodeGpio *gpio, bool state)
{
    if(renode_set_gpio_state(gpio, gpio_input, state) != RENODE_SUCCESS) {
        std::fprintf(stderr, "renode_set_gpio_state failed\n");
        return false;
    }
    return true;
}

static RenodeBusStatus dut_read(void *context, uint64_t address, uint8_t *data, uint32_t size)
{
    store_little_endian(data, size, 0);
    return RENODE_BUS_SUCCESS;
}

static RenodeBusStatus dut_write(void *context, uint64_t address, const uint8_t *data, uint32_t size)
{
    auto &state = *static_cast<dut_state *>(context);
    const uint64_t value = load_little_endian(data, size);
    if(address == start_address) {
        if(!set_gpio_input(state.gpio, true)) {
            return RENODE_BUS_ERROR;
        }
    } else if(address == clear_address) {
        if(!set_gpio_input(state.gpio, false)) {
            return RENODE_BUS_ERROR;
        }
    } else if(address == test_end_address) {
        std::scoped_lock lock(state.mutex);
        state.result = value;
        state.ended = true;
        state.test_ended.notify_one();
    }
    return RENODE_BUS_SUCCESS;
}

int main(int argc, char *argv[])
{
    dut_state state;
    RenodeMachine *machine;
    if(!load(argc, argv, dut_read, dut_write, &state, &machine)) {
        return exit_setup_error;
    }

    if(renode_get_gpio(machine, gpio_peripheral_name, &state.gpio) != RENODE_SUCCESS) {
        std::fprintf(stderr, "renode_get_gpio failed\n");
        return exit_setup_error;
    }

    if(!execute_command("start")) {
        return exit_setup_error;
    }

    uint64_t result;
    {
        std::unique_lock lock(state.mutex);
        state.test_ended.wait(lock, [&state] { return state.ended; });
        result = state.result;
    }

    quit();
    renode_free_gpio(state.gpio);
    renode_free_machine(machine);

    if(result != test_passed) {
        std::fprintf(stderr, "the guest reported result 0x%" PRIx64 "\n", result);
        return exit_mismatch;
    }
    return exit_pass;
}
