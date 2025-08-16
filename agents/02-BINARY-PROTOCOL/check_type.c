#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>

int main() {
    printf("sizeof(atomic_int_fast32_t) = %zu\n", sizeof(atomic_int_fast32_t));
    printf("sizeof(int32_t) = %zu\n", sizeof(int32_t));
    printf("sizeof(int_fast32_t) = %zu\n", sizeof(int_fast32_t));
    return 0;
}
