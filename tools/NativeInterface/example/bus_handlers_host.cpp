#include <algorithm>
#include <cassert>
#include <cinttypes>
#include <condition_variable>
#include <cstdint>
#include <cstdio>
#include <mutex>
#include <string>
#include <tuple>
#include <vector>

#include "librenode.h"

constexpr const char *machine_name = "bus-handlers";
constexpr const char *peripheral_name = "sysbus.dut";

constexpr uint64_t scratch_address = 0x10000000;
constexpr uint64_t test_end_address = 0x10000004;
constexpr uint64_t test_passed = 1;

enum exit_code {
    exit_pass = 0,
    exit_mismatch = 1,
    exit_setup_error = 2,
};

enum class access_type {
    read,
    write,
};

struct bus_access {
    access_type type;
    uint64_t address;
    uint32_t size;
    uint64_t value;

    bool operator==(const bus_access &other) const
    {
        return std::tie(type, address, size, value) == std::tie(other.type, other.address, other.size, other.value);
    }
};

const std::vector<bus_access> expected_accesses = {
    { access_type::write, scratch_address,  sizeof(uint32_t), 0xdeadbeef  },
    { access_type::read,  scratch_address,  sizeof(uint32_t), 0xdeadbeef  },
    { access_type::write, test_end_address, sizeof(uint32_t), test_passed },
};

struct dut_state {
    std::mutex mutex;
    std::condition_variable test_ended;
    bool ended = false;
    uint64_t scratch = 0;
    std::vector<bus_access> accesses;
};

static uint64_t load_little_endian(const uint8_t *data, uint32_t size)
{
    uint64_t value = 0;
    assert(size <= sizeof(value));
    for(uint32_t i = 0; i < size; i++) {
        value |= static_cast<uint64_t>(data[i]) << (8 * i);
    }
    return value;
}

static void store_little_endian(uint8_t *data, uint32_t size, uint64_t value)
{
    assert(size <= sizeof(value));
    for(uint32_t i = 0; i < size; i++) {
        data[i] = static_cast<uint8_t>(value >> (8 * i));
    }
}

static void print_access(FILE *stream, const char *prefix, const bus_access &access)
{
    std::fprintf(stream, "%s%s 0x%08" PRIx64 " size %" PRIu32 " value 0x%" PRIx64 "\n", prefix,
                 access.type == access_type::write ? "write" : "read ", access.address, access.size, access.value);
}

static void record(dut_state &state, const bus_access &entry)
{
    print_access(stdout, "", entry);
    //  The test runner reads stdout through a pipe, which is fully buffered by default.
    //  Flushing sends each access to the pipe as it is recorded, so the trace
    //  survives when the runner kills a hung host.
    std::fflush(stdout);
    state.accesses.push_back(entry);
}

static RenodeBusStatus dut_read(void *context, uint64_t address, uint8_t *data, uint32_t size)
{
    auto &state = *static_cast<dut_state *>(context);
    std::scoped_lock lock(state.mutex);

    const uint64_t value = address == scratch_address ? state.scratch : 0;
    store_little_endian(data, size, value);
    record(state, { access_type::read, address, size, value });
    return RENODE_BUS_SUCCESS;
}

static RenodeBusStatus dut_write(void *context, uint64_t address, const uint8_t *data, uint32_t size)
{
    auto &state = *static_cast<dut_state *>(context);
    std::scoped_lock lock(state.mutex);

    const uint64_t value = load_little_endian(data, size);
    record(state, { access_type::write, address, size, value });
    if(address == scratch_address) {
        state.scratch = value;
    } else if(address == test_end_address) {
        state.ended = true;
        state.test_ended.notify_one();
    }
    return RENODE_BUS_SUCCESS;
}

static void print_optional_access(const char *prefix, const std::vector<bus_access> &accesses, size_t index)
{
    if(index < accesses.size()) {
        print_access(stderr, prefix, accesses[index]);
    } else {
        std::fprintf(stderr, "%snone\n", prefix);
    }
}

static bool check_accesses(const std::vector<bus_access> &accesses)
{
    bool matched = true;
    const size_t count = std::max(accesses.size(), expected_accesses.size());
    for(size_t i = 0; i < count; i++) {
        if(i < accesses.size() && i < expected_accesses.size() && accesses[i] == expected_accesses[i]) {
            continue;
        }
        matched = false;
        std::fprintf(stderr, "access %u differs\n", static_cast<unsigned>(i));
        print_optional_access("  expected: ", expected_accesses, i);
        print_optional_access("    actual: ", accesses, i);
    }
    return matched;
}

static bool execute_command(const std::string &command)
{
    const RenodeStatus status = renode_exec_command(command.c_str());
    if(status != RENODE_SUCCESS) {
        std::fprintf(stderr, "'%s' failed with status %d\n", command.c_str(), status);
        return false;
    }
    return true;
}

int main(int argc, char *argv[])
{
    if(argc != 2) {
        std::fprintf(stderr, "usage: %s <script.resc>\n", argv[0]);
        return exit_setup_error;
    }

    if(renode_init(nullptr, -1, -1) != RENODE_SUCCESS) {
        std::fprintf(stderr, "renode_init failed\n");
        return exit_setup_error;
    }

    if(!execute_command(std::string("include @") + argv[1])) {
        return exit_setup_error;
    }

    dut_state state;
    if(renode_bus_set_handlers(machine_name, peripheral_name, dut_read, dut_write, &state) != RENODE_SUCCESS) {
        std::fprintf(stderr, "renode_bus_set_handlers failed\n");
        return exit_setup_error;
    }

    if(!execute_command("start")) {
        return exit_setup_error;
    }

    std::vector<bus_access> accesses;
    {
        std::unique_lock lock(state.mutex);
        state.test_ended.wait(lock, [&state] { return state.ended; });
        accesses = state.accesses;
    }

    renode_exec_command("quit");

    if(!check_accesses(accesses)) {
        return exit_mismatch;
    }
    return exit_pass;
}
