#include <stdio.h>
#include <string.h>
#include <dlfcn.h>

int main() {
    void *handle = dlopen("./c_diff_engine.so", RTLD_LAZY);
    if (!handle) {
        printf("✗ Cannot load library: %s\n", dlerror());
        return 1;
    }
    
    printf("✓ Library loaded successfully\n");
    
    // Test function existence and functionality
    int (*init_func)() = dlsym(handle, "diff_engine_init");
    if (init_func) {
        printf("✓ diff_engine_init found\n");
        init_func();
    }
    
    size_t (*count_func)(const void*, const void*, size_t) = dlsym(handle, "diff_count_bytes");
    if (count_func) {
        printf("✓ diff_count_bytes found\n");
        
        // Test with different strings
        const char *a = "hello world";
        const char *b = "hello earth";
        size_t diffs = count_func(a, b, strlen(a));
        printf("✓ Test result: %zu differences detected (expected 4)\n", diffs);
        
        if (diffs == 4) {
            printf("✓ SIMD diff engine is working correctly!\n");
            dlclose(handle);
            return 0;
        } else {
            printf("✗ Test failed - unexpected result\n");
        }
    } else {
        printf("✗ diff_count_bytes not found\n");
    }
    
    dlclose(handle);
    return 1;
}
