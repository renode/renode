#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "librenode.h"

#define OUT_SIZE 4096
#define ERR_SIZE 1024

static int run(const char *cmd)
{
    char out[OUT_SIZE] = { 0 };
    char err[ERR_SIZE] = { 0 };

    int rc = renode_exec_command_ex(cmd, out, sizeof(out), err, sizeof(err));
    printf("exec: %s\n", cmd);
    if(*out) {
        printf("%s", out);
    }
    if(*err) {
        fprintf(stderr, "error: %s", err);
    }
    printf("\t-> %s (rc=%d)\n", rc == 0 ? "ok" : rc == 1 ? "command error" : rc == 2 ? "quitting" : "error", rc);
    return rc;
}

static int usage(int err, const char *progname)
{
    fprintf(err == 0 ? stdout : stderr, "Usage: %s [-P telnet_port] [-R robot_port] [script]\n", progname);
    return err;
}

int main(int argc, char *argv[])
{
    int telnet_port = -1;
    int robot_port = -1;
    int opt;

    while((opt = getopt(argc, argv, "hP:R:")) != -1) {
        switch(opt) {
            case 'h':
            default:
                return usage(opt == 'h' ? 0 : 1, argv[0]);
            case 'P': {
                char *end = NULL;
                long parsed = strtol(optarg, &end, 10);
                if(*optarg == '\0' || *end != '\0' || parsed < 1 || parsed > 65535) {
                    fprintf(stderr, "invalid telnet port: %s\n", optarg);
                    return 1;
                }
                telnet_port = (int)parsed;
                break;
            }
            case 'R': {
                char *end = NULL;
                long parsed = strtol(optarg, &end, 10);
                if(*optarg == '\0' || *end != '\0' || parsed < 1 || parsed > 65535) {
                    fprintf(stderr, "invalid robot port: %s\n", optarg);
                    return 1;
                }
                robot_port = (int)parsed;
                break;
            }
        }
    }

    if(argc > optind + 1) {
        fprintf(stderr, "too many positional arguments\n");
        return usage(1, argv[0]);
    }

    char *script = (optind < argc) ? argv[optind] : NULL;

    int rc = renode_init(script, telnet_port, robot_port);
    if(rc != 0) {
        fprintf(stderr, "renode_init(%s, %d, %d) failed (%d)\n", script, telnet_port, robot_port, rc);
        return 1;
    }

    char command[1024];
    for(;;) {
        printf("> ");
        if(!fgets(command, sizeof(command), stdin)) {
            /* Treat EOF as quit */
            strcpy(command, "quit");
        }
        command[strcspn(command, "\n")] = 0; /* Remove trailing newline */
        if(run(command) == 2) {
            break;
        }
    }

    return 0;
}
