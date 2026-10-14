#pragma once

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <string>

#include "librenode.h"

//  Parts shared by the hosts of tests/native-interface/bus-handlers.robot. Each host is one device
//  model that serves the guest's accesses to sysbus.dut through bus handlers.
namespace native_host {

constexpr const char *machine_name = "bus-handlers";
constexpr const char *peripheral_name = "sysbus.dut";

//  The guest ends each test by writing its result to this register of the device.
constexpr uint64_t test_end_address = 0x10000004;
constexpr uint64_t test_passed = 1;

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

//  Loads the script named on the command line, gets a handle to the machine and attaches the
//  handlers to the device. The host starts the emulation after any further setup, and frees the
//  machine handle.
inline bool load(int argc, char *argv[], RenodeBusReadHandler read, RenodeBusWriteHandler write, void *context,
                 RenodeMachine **machine)
{
    if(argc != 2) {
        std::fprintf(stderr, "usage: %s <script.resc>\n", argv[0]);
        return false;
    }

    if(renode_init(nullptr, -1, -1) != RENODE_SUCCESS) {
        std::fprintf(stderr, "renode_init failed\n");
        return false;
    }

    if(!execute_command(std::string("include @") + argv[1])) {
        return false;
    }

    if(renode_get_machine(machine_name, machine) != RENODE_SUCCESS) {
        std::fprintf(stderr, "renode_get_machine failed\n");
        return false;
    }

    if(renode_bus_set_handlers(*machine, peripheral_name, read, write, context) != RENODE_SUCCESS) {
        std::fprintf(stderr, "renode_bus_set_handlers failed\n");
        return false;
    }

    return true;
}

inline void quit()
{
    renode_exec_command("quit");
}

} // namespace native_host
