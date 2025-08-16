#include <stdatomic.h>
#include <stdint.h>

int main() {
    atomic_int_fast32_t x = 0;
    int32_t expected = 0;
    atomic_compare_exchange_strong(&x, &expected, 1);
    return 0;
}
