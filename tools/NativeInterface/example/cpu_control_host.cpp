#include <algorithm>
#include <cinttypes>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <exception>
#include <iterator>
#include <stdexcept>

#include "native_host.hpp"

using namespace native_host;

//  A host that controls the guest's CPU through the external control API.
//  The guest counts its loop iterations in RAM, and a routine outside its
//  loop sets a marker. The scenario named on the command line checks one
//  behavior of the CPU functions and reports the result through the exit code.

constexpr const char *machine_name = "cpu-control";
constexpr const char *cpu_name = "sysbus.cpu";
constexpr const char *uart_name = "sysbus.uart0";
constexpr const char *peripheral_name = "sysbus.dut";

constexpr uint64_t loop_start = 0x40000004;
constexpr uint64_t loop_end = 0x40000028;
constexpr uint64_t marker_routine_address = 0x40000028;
constexpr uint64_t iteration_count_address = 0x40100000;
constexpr uint64_t access_request_address = 0x40100008;
constexpr uint64_t marker_address = 0x40100010;
constexpr uint64_t step_milliseconds = 1;

//  Thrown when an operation fails, after the operation has reported its error.
struct operation_failed : std::exception { };

//  Thrown when the CPU does not behave as a scenario expects.
struct mismatch : std::runtime_error {
    using std::runtime_error::runtime_error;
};

static void require_success(bool succeeded)
{
    if(!succeeded) {
        throw operation_failed();
    }
}

static void expect(bool condition, const char *message)
{
    if(!condition) {
        throw mismatch(message);
    }
}

//  The host's connection to Renode and the handles that the scenarios use.
//  Each operation reports its own errors. The operations that a scenario
//  can't go on without also throw `operation_failed`, which ends the scenario.
class cpu_host {
public:
    bool connect(const char *script_path)
    {
        const auto on_read = [](uint64_t, uint8_t *data, uint32_t size) {
            store_little_endian(data, size, 0);
            return true;
        };
        //  Sets the PC during the guest's write, which only the set-pc-from-access scenario requests.
        //  Returns whether it succeeded, because Renode calls it and an exception can't pass through Renode.
        const auto on_write = [this](uint64_t, const uint8_t *, uint32_t) {
            return check("set the PC", renode_set_cpu_pc(cpu.get(), marker_routine_address));
        };
        if(!control.connect(script_path, machine_name, peripheral_name, on_read, on_write)) {
            return false;
        }

        cpu = control.get_cpu(cpu_name);
        bus = control.get_sysbus();
        return cpu && bus;
    }

    void disconnect()
    {
        control.disconnect();
    }

    void run()
    {
        require_success(control.run_for(step_milliseconds));
    }

    bool has_cpu(const char *name)
    {
        return control.get_cpu(name) != nullptr;
    }

    uint64_t get_pc()
    {
        uint64_t pc = 0;
        require_success(check("get the PC", renode_get_cpu_pc(cpu.get(), &pc)));
        return pc;
    }

    void set_pc(uint64_t pc)
    {
        require_success(check("set the PC", renode_set_cpu_pc(cpu.get(), pc)));
    }

    bool is_halted()
    {
        bool halted = false;
        require_success(check("get the halted state", renode_is_cpu_halted(cpu.get(), &halted)));
        return halted;
    }

    void set_halted(bool halted)
    {
        require_success(check("set the halted state", renode_set_cpu_halted(cpu.get(), halted)));
    }

    uint64_t read_quad(uint64_t address)
    {
        uint64_t value = 0;
        require_success(check("read the memory", renode_sysbus_read(bus.get(), address, AW_QUAD_WORD, &value, 1)));
        return value;
    }

    void write_quad(uint64_t address, uint64_t value)
    {
        require_success(check("write the memory", renode_sysbus_write(bus.get(), address, AW_QUAD_WORD, &value, 1)));
    }

private:
    external_control control;
    handle<renode_cpu_t> cpu;
    handle<renode_bus_context_t> bus;
};

//  Renode gives no CPU handle for a peripheral that is not a CPU.
static void check_not_a_cpu(cpu_host &host)
{
    expect(!host.has_cpu(uart_name), "Renode should give no CPU handle for the UART, but it did");
}

//  The PC of the running guest is inside the guest's loop.
static void check_pc(cpu_host &host)
{
    host.run();
    const uint64_t pc = host.get_pc();

    std::fprintf(stderr, "PC: 0x%" PRIx64 "\n", pc);
    expect(loop_start <= pc && pc < loop_end, "the PC should be inside the guest's loop, but it is not");
}

//  The guest runs its marker routine after the host sets the PC to it.
static void check_set_pc(cpu_host &host)
{
    host.run();
    host.set_pc(marker_routine_address);
    host.run();

    expect(host.read_quad(marker_address) == 1, "the guest should have run the code at the PC that the host set, but it did not");
}

//  The halted state follows the host's calls of renode_set_cpu_halted().
static void check_halted_state(cpu_host &host)
{
    host.run();
    const bool halted_before = host.is_halted();

    host.set_halted(true);
    const bool halted_after = host.is_halted();

    expect(!halted_before && halted_after, "the halted state should follow renode_set_cpu_halted(), but it does not");
}

//  A halted CPU executes no instructions while virtual time passes.
static void check_halt(cpu_host &host)
{
    host.run();
    host.set_halted(true);
    const uint64_t iterations_before = host.read_quad(iteration_count_address);

    host.run();
    const uint64_t iterations_after = host.read_quad(iteration_count_address);

    expect(iterations_after == iterations_before, "the halted CPU should not have executed the guest's loop, but it did");
}

//  A CPU that is no longer halted executes the guest's loop again.
static void check_resume(cpu_host &host)
{
    host.run();
    host.set_halted(true);
    const uint64_t iterations_halted = host.read_quad(iteration_count_address);

    host.set_halted(false);
    host.run();
    const uint64_t iterations_after = host.read_quad(iteration_count_address);

    expect(iterations_after > iterations_halted, "the CPU should have run again after the halt, but it did not");
}

//  The device sets the PC to the marker routine while it serves the guest's write.
static void check_set_pc_from_access(cpu_host &host)
{
    host.run();
    host.write_quad(access_request_address, 1);
    host.run();

    //  Runs once more, because the PC changes at the next synchronization
    //  point, which can be the end of the run that made the write.
    host.run();

    expect(host.read_quad(marker_address) == 1,
           "the guest should have run the code at the PC that the device set, but it did not");
}

struct scenario {
    const char *name;
    void (*run)(cpu_host &host);
};

constexpr scenario scenarios[] = {
    { "not-a-cpu",          check_not_a_cpu          },
    { "pc",                 check_pc                 },
    { "set-pc",             check_set_pc             },
    { "halted-state",       check_halted_state       },
    { "halt",               check_halt               },
    { "resume",             check_resume             },
    { "set-pc-from-access", check_set_pc_from_access },
};

static exit_code run_scenario(const scenario &selected, cpu_host &host)
{
    try {
        selected.run(host);
        return exit_pass;
    } catch(const mismatch &error) {
        std::fprintf(stderr, "%s\n", error.what());
        return exit_mismatch;
    } catch(const operation_failed &) {
        return exit_runtime_error;
    }
}

int main(int argc, char *argv[])
{
    const auto named = [argc, argv](const scenario &candidate) { return argc == 3 && std::strcmp(candidate.name, argv[2]) == 0; };
    const auto selected = std::find_if(std::begin(scenarios), std::end(scenarios), named);
    if(selected == std::end(scenarios)) {
        std::fprintf(stderr, "usage: %s <script.resc> <scenario>\n", argv[0]);
        return exit_setup_error;
    }

    cpu_host host;
    if(!host.connect(argv[1])) {
        return exit_setup_error;
    }

    const exit_code result = run_scenario(*selected, host);
    host.disconnect();
    return result;
}
