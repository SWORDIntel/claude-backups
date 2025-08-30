#include <immintrin.h>
#include <stdio.h>

int main() {
    // Direct AVX-512 test without CPUID checks
    printf("Testing AVX-512 directly...\n");
    
    __m512i a = _mm512_set1_epi32(1);
    __m512i b = _mm512_set1_epi32(2);
    __m512i c = _mm512_add_epi32(a, b);
    
    int result[16];
    _mm512_storeu_si512((__m512i*)result, c);
    
    printf("AVX-512 SUCCESS! Result[0] = %d (expected 3)\n", result[0]);
    printf("This core supports AVX-512!\n");
    return 0;
}