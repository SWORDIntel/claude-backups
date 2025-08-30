#!/bin/bash

echo "Testing AVX-512 support on each CPU core..."
echo "Core | Status"
echo "-----|--------"

for cpu in $(seq 0 21); do
    result=$(taskset -c $cpu ./test_avx512 2>&1)
    if [ $? -eq 0 ]; then
        echo "CPU$cpu | ✓ AVX-512 SUPPORTED (P-core)"
    else
        echo "CPU$cpu | ✗ No AVX-512 (E-core)"
    fi
done

echo ""
echo "P-cores detected:"
for cpu in $(seq 0 21); do
    taskset -c $cpu ./test_avx512 2>/dev/null && echo "  CPU$cpu"
done