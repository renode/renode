#include <atomic>
#include <cstdint>
#include <cstdio>

#include "native_host.hpp"

using namespace native_host;

//  A host that runs in lockstep with Renode, the way a simulator on one thread advances its own
//  simulation and Renode in turn. The guest CPU keeps copying the GPIO input to the GPIO output.
//  One step:
//
//                    paused                one quantum                  paused
//                 |<-------->|<------------------------------------>|<----------->|
//  host           set input  renode_run_for() .....................   returns, checks the output
//  GPIO input     __/--------------------------------------------------------------
//  GPIO output    ___________________/---------------------------------------------
//  output event                      |- waits for the sync point -->* callback
//  virtual time              --------------------------------------->
//  real time      ---------------------------------------------------------------->

constexpr const char *machine_name = "lockstep";
constexpr const char *gpio_peripheral_name = "sysbus.gpio";
constexpr int gpio_input = 0;
constexpr int gpio_output = 1;
constexpr int step_count = 100;

//  Each step is one quantum, so that the end of the step is the only synchronization point in it.
constexpr uint64_t step_milliseconds = 1;

static void on_gpio_output_change(void *user_data, renode_gpio_event_data_t *event)
{
    static_cast<std::atomic<bool> *>(user_data)->store(event->state);
}

int main(int argc, char *argv[])
{
    std::atomic<bool> output_state = false;
    external_control control;

    if(!check_usage(argc, argv)) {
        return exit_setup_error;
    }
    if(!control.connect(argv[1], machine_name) || !control.set_quantum(std::chrono::milliseconds(step_milliseconds))) {
        return exit_setup_error;
    }

    const auto gpio = control.get_gpio(gpio_peripheral_name);
    if(!gpio) {
        return exit_setup_error;
    }

    if(!check("register the GPIO output callback",
              renode_register_gpio_state_change_callback(gpio.get(), gpio_output, &output_state, on_gpio_output_change))) {
        return exit_setup_error;
    }

    for(int step = 0; step < step_count; step++) {
        //  The input toggles in every step, so that every step changes the output. A state
        //  change callback that arrived a step late would leave the previous state, which the
        //  check catches.
        const bool input_state = step % 2 == 0;
        if(!check("set the GPIO input", renode_set_gpio_state(gpio.get(), gpio_input, input_state))) {
            return exit_runtime_error;
        }

        if(!control.run_for(step_milliseconds)) {
            return exit_runtime_error;
        }

        const bool reported_output_state = output_state;
        if(reported_output_state != input_state) {
            std::fprintf(stderr, "after step %d, the GPIO output is %d, but the input is %d\n", step, reported_output_state,
                         input_state);
            control.disconnect();
            return exit_mismatch;
        }
    }

    control.disconnect();
    return exit_pass;
}
