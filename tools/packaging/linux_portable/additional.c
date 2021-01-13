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

