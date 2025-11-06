#!/bin/bash
# Quick Benchmark Script - Test performance of acceleration modules

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Claude Framework v7.0 - Quick Benchmark${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Crypto-POW Benchmark
CRYPTO_POW_BIN="$PROJECT_ROOT/hooks/crypto-pow/crypto-pow-enhanced/target/release/crypto-pow"
if [ -f "$CRYPTO_POW_BIN" ]; then
    echo -e "${BOLD}Crypto-POW Performance${NC}"
    echo "────────────────────────────────────────"
    echo "Testing POW solving (difficulty 12)..."
    "$CRYPTO_POW_BIN" solve --data 48656c6c6f --difficulty 12 2>&1 | grep -E "Solution found|Nonce|Time"
    echo ""
else
    echo -e "${YELLOW}⚠ Crypto-POW not compiled - skipping${NC}"
    echo ""
fi

# Shadowgit Benchmark
SHADOWGIT_BIN="$PROJECT_ROOT/hooks/shadowgit/shadowgit_phase3_test"
if [ -f "$SHADOWGIT_BIN" ]; then
    echo -e "${BOLD}Shadowgit Performance${NC}"
    echo "────────────────────────────────────────"
    echo "Testing line processing (10 tasks)..."
    "$SHADOWGIT_BIN" 10 2>&1 | grep -E "Total Time|Lines Processed|Processing Time|Throughput"
    echo ""
else
    echo -e "${YELLOW}⚠ Shadowgit not compiled - skipping${NC}"
    echo ""
fi

# Hardware Info
echo -e "${BOLD}Hardware Configuration${NC}"
echo "────────────────────────────────────────"
echo "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
echo "Cores: $(nproc)"
echo "Features: $(grep flags /proc/cpuinfo | head -1 | grep -oE 'avx2|avx512f|aes|fma' | tr '\n' ' ')"
echo ""

echo -e "${GREEN}${BOLD}Benchmark complete!${NC}"
