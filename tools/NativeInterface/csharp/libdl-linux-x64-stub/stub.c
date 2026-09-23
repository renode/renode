// Stubs of dl* functions used in librenode.so needed for backwards compatibility with GLIBC older than v2.34.
// See build.sh for more details.

// _GNU_SOURCE definition is required to include `Dl_info` from `dlfcn.h`.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>

int dladdr(const void *addr, Dl_info *info)
{
    return 0;
}

int dlclose(void *handle)
{
    return 0;
}

char *dlerror(void)
{
    return NULL;
}

void *dlopen(const char *filename, int flags)
{
    return NULL;
}

void *dlsym(void *restrict handle, const char *restrict symbol)
{
    return NULL;
}
