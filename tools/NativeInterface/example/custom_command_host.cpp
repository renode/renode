#include <atomic>
#include <cinttypes>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#include "native_host.hpp"

using namespace native_host;

constexpr const char *machine_name = "custom-commands";
constexpr const char *peripheral_name = "sysbus.dut";

//  Answers each custom command with the reply that `user_data` points to. The reply comes through
//  `user_data` so that the test also fails when the callback doesn't get its user data.
static renode_custom_command_response_data_t *answer(void *user_data, renode_custom_command_event_data_t * /* event */)
{
    const char *reply = static_cast<const char *>(user_data);
    //  `response_string` is a flexible array member, so the allocation adds room for the reply and its null terminator.
    const std::size_t reply_size = std::strlen(reply) + 1;
    auto *response = static_cast<renode_custom_command_response_data_t *>(
        std::malloc(sizeof(renode_custom_command_response_data_t) + reply_size));
    response->command_valid = true;
    std::memcpy(response->response_string, reply, reply_size);
    return response;
}

//  Adds a hook that sends a custom command when the guest starts
//  and writes to the test end register whether the reply is "pong".
constexpr const char *add_hook = R"(sysbus.cpu AddHook 0x40000000 """
_, host = emulationManager.CurrentEmulation.TryGetEmulationElementByName('nativeHost', None)
self.Bus.WriteDoubleWord(0x10000004, int(host.SendCustomCommand('ping') == 'pong'))
""")";

//  `connect` registers a bus access callback first, so the custom command callback gets another
//  event descriptor. Renode then sends a custom command while it runs the guest.
int main(int argc, char *argv[])
{
    char reply[] = "pong";
    std::atomic<uint64_t> result = 0;
    external_control control;
    const auto on_read = [](auto...) { return false; };
    const auto on_write = [&result](uint64_t address, const uint8_t *data, uint32_t size) {
        if(address != test_end_address) {
            return false;
        }

        result = load_little_endian(data, size);
        return true;
    };

    if(!check_usage(argc, argv)) {
        return exit_setup_error;
    }
    if(!control.connect(argv[1], machine_name, peripheral_name, on_read, on_write)) {
        return exit_setup_error;
    }
    if(!control.register_custom_command_callback(reply, answer)) {
        return exit_setup_error;
    }

    std::string output;
    if(!control.run_monitor_command(add_hook, output)) {
        return exit_setup_error;
    }

    if(!control.run_for(1)) {
        return exit_runtime_error;
    }

    control.disconnect();

    if(result != test_passed) {
        std::fprintf(stderr, "the hook should have reported result 0x%" PRIx64 ", but it reported 0x%" PRIx64 "\n", test_passed,
                     result.load());
        return exit_mismatch;
    }
    return exit_pass;
}
