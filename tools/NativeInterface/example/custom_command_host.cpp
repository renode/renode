#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "librenode.h"
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

//  `connect` registers a bus access callback first, so the custom command callback gets another
//  event descriptor. The host then sends a custom command from the Monitor and checks the reply.
int main(int argc, char *argv[])
{
    char reply[] = "pong";
    external_control control;
    const auto no_access = [](auto...) { return false; };
    if(!check_usage(argc, argv)) {
        return exit_setup_error;
    }
    if(!control.connect(argv[1], machine_name, peripheral_name, no_access, no_access)) {
        return exit_setup_error;
    }
    if(!control.register_custom_command_callback(reply, answer)) {
        return exit_setup_error;
    }

    char output[256] = "";
    char error[256] = "";
    renode_exec_command_ex("nativeHost SendCustomCommand \"ping\"", output, sizeof(output), error, sizeof(error));
    control.disconnect();

    if(std::strstr(output, reply) == nullptr) {
        std::fprintf(stderr, "expected '%s', got output '%s' and error '%s'\n", reply, output, error);
        return exit_mismatch;
    }
    return exit_pass;
}
