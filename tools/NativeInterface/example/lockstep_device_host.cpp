#include <cinttypes>
#include <cstdint>
#include <cstdio>
#include <mutex>

#include "native_host.hpp"

using namespace native_host;

//  A host that runs in lockstep with Renode by calling renode_run_for() on the main thread, while
//  the device serves the guest's accesses on threads of its own. The device serves the guest's
//  write to its start register by writing a word into guest RAM, so it calls Renode during a
//  renode_run_for() call.

constexpr uint64_t start_address = 0x10000008;
constexpr uint64_t data_address = 0x40100000;
constexpr uint32_t data_word = 0xcafe0001;

constexpr const char *machine_name = "lockstep";
constexpr const char *peripheral_name = "sysbus.dut";
constexpr uint64_t step_milliseconds = 1;

struct dut_state {
    std::mutex mutex;
    bool ended = false;
    uint64_t result = 0;
    handle<renode_bus_context_t> bus;
};

static bool dut_read(uint64_t address, uint8_t *data, uint32_t size)
{
    store_little_endian(data, size, 0);
    return true;
}

static bool dut_write(dut_state &state, uint64_t address, const uint8_t *data, uint32_t size)
{
    if(address == start_address) {
        return check("write the data", renode_sysbus_write(state.bus.get(), data_address, AW_DOUBLE_WORD, &data_word, 1));
    } else if(address == test_end_address) {
        std::scoped_lock lock(state.mutex);
        state.result = load_little_endian(data, size);
        state.ended = true;
    }

    return true;
}

static bool test_running(dut_state &state)
{
    std::scoped_lock lock(state.mutex);
    return !state.ended;
}

int main(int argc, char *argv[])
{
    dut_state state;
    external_control control;

    if(!check_usage(argc, argv)) {
        return exit_setup_error;
    }

    const auto on_write = [&state](auto... access) { return dut_write(state, access...); };
    if(!control.connect(argv[1], machine_name, peripheral_name, dut_read, on_write)) {
        return exit_setup_error;
    }

    state.bus = control.get_sysbus();
    if(!state.bus) {
        return exit_setup_error;
    }

    while(test_running(state)) {
        if(!control.run_for(step_milliseconds)) {
            return exit_runtime_error;
        }
    }

    control.disconnect();

    if(state.result != test_passed) {
        std::fprintf(stderr, "the guest reported result 0x%" PRIx64 "\n", state.result);
        return exit_mismatch;
    }
    return exit_pass;
}
