//
// reimplement some libc stuff not present in older versions
// but possibly used by libmono
//

void __wrap_powf() {
	printf("!!!! powf!\n"); // TODO
}

void __wrap_logf() {
	printf("!!!! logf!\n"); // TODO
}

void __wrap_expf() {
	printf("!!!! expf!\n"); // TODO
}

#include <syscall.h>
ssize_t __wrap_getrandom (void *buffer, size_t length, unsigned int flags) {
 return syscall(__NR_getrandom, buffer, length, flags);
}

extern void* __libc_dlopen_mode(const char* filename, int flag);
extern void* __libc_dlsym(void* handle, const char* symbol);

#define LIST_LENGTH 2048
#define MAX_FILENAME_LENGTH 4096

char binary_path[MAX_FILENAME_LENGTH];

void* list_ptrs[LIST_LENGTH];
char* list_names[LIST_LENGTH];
int list_counter = 0;

static char* get_name(void* ptr) {
       for (int i = 0; i < list_counter; i++) {
            if (list_ptrs[i] == ptr) {
                return list_names[i];
            }
       }
       return "(unknown)";
}

#include <dlfcn.h>
#include <string.h>
#include <stdio.h>
#include <libgen.h>

#ifdef DEBUG_PRINT
  #define debug_print printf
  #define error_print printf
#else
  #define debug_print(...)
  #define error_print(...)
#endif

void* __wrap_dlopen(const char* _filename, int flag) {
        if (_filename == NULL) {
            return NULL;
        }

	char filename[MAX_FILENAME_LENGTH];
	int l = snprintf(filename, MAX_FILENAME_LENGTH, "%s", _filename);
	if (l < 0 || l >= MAX_FILENAME_LENGTH)
	{
    	       error_print(">>> dlopen: error while configuring the filename: %s\n", filename);
    	       return NULL;
	}

	debug_print(">>> dlopen: %s\n", filename);

        // skip .dll.so calls.
	if (strstr(filename, ".dll.so") != 0) {
            debug_print(">>> dlopen: ignoring %s as it is .dll.so\n", filename);
    	    return NULL;
	}

	// patch current directory
	if (strlen(filename) >= 2
    	    && filename[0] == '.'
    	    && filename[1] == '/') {
               // +2 to skip the initial './'
               int l = snprintf(filename, MAX_FILENAME_LENGTH, "%s%s", binary_path, _filename + 2);
               if (l < 0 || l >= MAX_FILENAME_LENGTH) {
        	       error_print(">>> dlopen: error while patching the filename\n");
        	       return NULL;
               }
	       debug_print(">>> dlopen: filename patched to %s\n", filename);
	}

	void* result = __libc_dlopen_mode(
           	(strcmp(filename, "__Internal") == 0) ? "" : filename,
        	flag);

        debug_print(">>> dlopen: result is %p; filename was %s, flag was %d\n", result, filename, flag);
        if (result != NULL) {
            list_ptrs[list_counter] = result;
            list_names[list_counter] = strdup(basename(filename));

            debug_print(">>> dlopen: %s returns %p\n", list_names[list_counter], result);
            list_counter = (list_counter + 1) % LIST_LENGTH;
        } else {
            debug_print(">>> dlopen: result is null: %s\n", dlerror());
        }

	return result;
}

void* __wrap_dlsym(void* ptr, char* symbol_name) {
    debug_print(">>> dlsym: looking for symbol '%s' in %p [%s]\n", symbol_name, ptr, get_name(ptr));

    if (strcmp(symbol_name, "dlopen") == 0) {
        return (void*)__wrap_dlopen;
    }
    if (strcmp(symbol_name, "dlsym") == 0) {
        return (void*)__wrap_dlsym;
    }
    if (strcmp(symbol_name, "memset") == 0) {
        // the `memset` symbol returned from `__libc_dlsym` is in fact an indirect function
        // so it cannot be used directly and must be treated in a special way
        return (void*)memset;
    }

    return __libc_dlsym(ptr, symbol_name);
}

// import MonoPosixHelper functions so that they're exported
extern void Mono_Posix_Syscall_get_at_fdcwd();
extern void Mono_Posix_Syscall_L_ctermid();
extern void Mono_Posix_Syscall_get_utime_now();
extern void Mono_Posix_Syscall_readlink();
extern void Mono_Posix_Stdlib_SIG_DFL();
extern void Mono_Posix_Stdlib_EXIT_FAILURE();
extern void CreateZStream();
extern void CloseZStream();
extern void ReadZStream();
extern void WriteZStream();

// dummy function so that they're used
#define ATTR __attribute__ ((__visibility__ ("default"))) __attribute__((noinline))
ATTR void DO_NOT_RUN_dummy_callback(void) {
        // the section below contains a list of all
        // symbols that are to be remapped in the dllmap
        // by the tools/packaging/make_linux_portable.sh script;
        // they are extracted automatically, so please
        // add all new items between markers and
        // *DO NOT* modify markers themselves
        
        // --- REMAPPED SYMBOLS SECTION STARTS ---
        Mono_Posix_Syscall_get_at_fdcwd();
        Mono_Posix_Syscall_L_ctermid();
        Mono_Posix_Syscall_get_utime_now();
        Mono_Posix_Syscall_readlink();
        Mono_Posix_Stdlib_SIG_DFL();
        Mono_Posix_Stdlib_EXIT_FAILURE();
        CreateZStream();
        CloseZStream();
        ReadZStream();
        WriteZStream();
        // --- REMAPPED SYMBOLS SECTION ENDS ---
}

//
// end of reimplement
//

//
// helper methods
//
ATTR int GetBundlesCount(void) {
	static int bundle_count = -1;
	if (bundle_count != -1) return bundle_count;
        MonoBundledAssembly **ptr = (MonoBundledAssembly **) compressed;
        int nbundles = 0;
        while (*ptr++ != NULL) {
                nbundles++;
        }
	bundle_count = nbundles;
        return bundle_count;
}

static MonoBundledAssembly *get_bundle(int id) {
        return (id >= GetBundlesCount()) ? NULL : bundled[id];
}

ATTR char* GetBundleName(int id) {
	MonoBundledAssembly *bundle = get_bundle(id);
	return bundle ? (char*)(bundle->name) : "";
}

ATTR uint32_t GetBundleDataSize(int id) {
        MonoBundledAssembly *bundle = get_bundle(id);
        return bundle ? bundle->size : 0;
}

ATTR void* GetBundleDataPointer(int id) {
	MonoBundledAssembly *bundle = get_bundle(id);
	return bundle ? (void*)bundle->data : NULL;
}

//
// end of helper methods
//

#include <mono/jit/jit.h>
int main (int argc, char* argv[]) {
        char **newargs;
        int i, k = 0;

        // dirname might modify the content, so let's keep
        // the link in a separate buffer first
        char tmp[MAX_FILENAME_LENGTH];
        ssize_t l = readlink("/proc/self/exe", tmp, MAX_FILENAME_LENGTH);
        // adding 2 to the size to make room for `/` and the final NULL character
        // in theory 1 should be enough as we call `dirname`, but let's be safe
        if (l < 0 || l >= MAX_FILENAME_LENGTH - 2)
        {
            printf("ERROR: Could read the link to self and determine the binary path. Exiting");
            return 1;
        }
	sprintf(binary_path, "%s/", dirname(tmp));

        newargs = (char **) malloc (sizeof (char *) * (argc + 2));
        newargs [k++] = image_name;

        for (i = 1; i < argc; i++) {
                newargs [k++] = argv [i];
        }
        newargs [k] = NULL;

        if (config_dir != NULL && getenv ("MONO_CFG_DIR") == NULL) {
                mono_set_dirs (getenv ("MONO_PATH"), config_dir);
        }

        mono_mkbundle_init();

        MonoDomain *domain = mono_jit_init ("Renode.exe");
        MonoAssembly *assembly;
        assembly = mono_domain_assembly_open (domain, "Renode.exe");

        mono_jit_exec (domain, assembly, k, newargs);
        int retval = mono_environment_exitcode_get ();
        mono_jit_cleanup (domain);

        return retval;
}

