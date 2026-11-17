#include <cstdio>
#include <string>
#include <thread>

#include "native_host.hpp"

using namespace native_host;

constexpr const char *machine_name = "custom-commands";
constexpr int repeats = 500;

//  Writes `value` to `address` with a Monitor command, then reads it
//  back `repeats` times and returns how many outputs lack `value`.
static int count_wrong_outputs(external_control &control, const char *address, const char *value)
{
    const std::string write_command = std::string("sysbus WriteDoubleWord ") + address + " " + value;
    const std::string read_command = std::string("sysbus ReadDoubleWord ") + address;
    std::string output;
    int wrong = 0;

    if(!control.run_monitor_command(write_command.c_str(), output)) {
        return repeats;
    }

    for(int repeat = 0; repeat < repeats; repeat++) {
        const bool succeeded = control.run_monitor_command(read_command.c_str(), output);

        if(!succeeded || output.find(value) == std::string::npos) {
            wrong++;
        }
    }

    return wrong;
}

//  Runs Monitor commands from two threads through one connection at
//  the same time and checks that each thread gets its own output.
int main(int argc, char *argv[])
{
    external_control control;
    if(!check_usage(argc, argv)) {
        return exit_setup_error;
    }

    if(!control.connect(argv[1], machine_name)) {
        return exit_setup_error;
    }

    int other_wrong = 0;
    std::thread other([&] { other_wrong = count_wrong_outputs(control, "0x40100004", "0x22222222"); });
    const int wrong = count_wrong_outputs(control, "0x40100000", "0x11111111");
    other.join();
    control.disconnect();

    if(wrong != 0 || other_wrong != 0) {
        std::fprintf(stderr, "each thread should have got %d correct outputs, but %d and %d were wrong\n", repeats, wrong,
                     other_wrong);
        return exit_mismatch;
    }

    return exit_pass;
}
