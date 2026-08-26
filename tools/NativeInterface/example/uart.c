#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

#include "librenode.h"

#define UART_BUFFER_SIZE 1024

typedef struct uart_data{
    char buffer[UART_BUFFER_SIZE];
    int pos;
    const char* name;
} uart_data;

static void uart_handler(void* opaque, char val)
{
    uart_data* data = opaque;
    data->buffer[data->pos] = val;
    data->pos++;
    if(data->pos == UART_BUFFER_SIZE - 1 || val == '\r' || val == '\n'){
        data->buffer[data->pos] = '\0';
        if(val != '\n' && val != '\r'){
            printf("%s: %s\n", data->name, data->buffer);
        }else{
            printf("%s: %s", data->name, data->buffer);
        }
        data->pos = 0;
    }
};

uart_data create_uart_data(const char* name){
    uart_data data = {
        .pos = 0,
        .name = name,
    };
    return data;
}

int main(int argc, char *argv[])
{
    const char* machine_name = "ARM Cortex-R52";
    int rc = renode_init(NULL, -1, -1);
    if(rc != 0) {
        fprintf(stderr, "renode_init failed with %d number\n", rc);
        return 1;
    }

    uart_data data1 = create_uart_data("sysbus.uart0");
    uart_data data2 = create_uart_data("sysbus.uart1");

    renode_exec_command("i @scripts/single-node/cortex-r52-hirtos.resc");

    renode_add_uart_analyzer(uart_handler, NULL, machine_name, data1.name, &data1, NULL);
    renode_add_uart_analyzer(uart_handler, NULL, machine_name, data2.name, &data2, NULL);

    // Disables logging to console completely
    renode_exec_command("python 'from Antmicro.Renode.Logging import Logger, ConsoleBackend; Logger.RemoveBackend(ConsoleBackend.Instance)'");
    renode_exec_command("start");

    while(getchar())
    return 0;
}
