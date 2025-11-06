#!/bin/bash
# Quick Validation Script - Verify Claude Framework v7.0 Installation
# Tests all core components and provides instant feedback

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Claude Framework v7.0 - Quick Validation${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Counters
PASS=0
FAIL=0
WARN=0

check_status() {
    local name="$1"
    local command="$2"
    local critical="${3:-false}"

    printf "%-40s " "$name"

    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((PASS++))
        return 0
    else
        if [ "$critical" = "true" ]; then
            echo -e "${RED}✗${NC}"
            ((FAIL++))
        else
            echo -e "${YELLOW}⚠${NC}"
            ((WARN++))
        fi
        return 1
    fi
}

check_with_output() {
    local name="$1"
    local command="$2"
    local expected="$3"

    printf "%-40s " "$name"

    local output=$(eval "$command" 2>&1)
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓${NC} ($output)"
        ((PASS++))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} ($output)"
        ((WARN++))
        return 1
    fi
}

echo -e "${BOLD}Core System${NC}"
echo "────────────────────────────────────────"
check_status "Python 3 installed" "command -v python3" true
check_status "Rust toolchain installed" "command -v cargo"
check_status "GCC compiler installed" "command -v gcc" true
check_status "Git installed" "command -v git" true
check_status "Docker installed" "command -v docker"
check_status "Make installed" "command -v make" true
echo ""

echo -e "${BOLD}Claude Installation${NC}"
echo "────────────────────────────────────────"
check_status "Claude command available" "command -v claude" true
check_status "Claude wrapper exists" "test -f ~/.local/bin/claude"
check_status "NPM global bin in PATH" "echo \$PATH | grep -q npm-global"
echo ""

echo -e "${BOLD}Python Dependencies${NC}"
echo "────────────────────────────────────────"
check_status "asyncpg installed" "python3 -c 'import asyncpg'" false
check_status "cryptography installed" "python3 -c 'import cryptography'" false
check_status "OpenVINO installed" "python3 -c 'import openvino'" false
check_status "psycopg2 installed" "python3 -c 'import psycopg2'" false
check_status "numpy installed" "python3 -c 'import numpy'" false
echo ""

echo -e "${BOLD}Crypto-POW Module${NC}"
echo "────────────────────────────────────────"
check_status "Cargo.toml exists" "test -f $PROJECT_ROOT/hooks/crypto-pow/crypto-pow-enhanced/Cargo.toml"
check_status "Rust source present" "test -d $PROJECT_ROOT/hooks/crypto-pow/crypto-pow-enhanced/src"
if [ -f "$PROJECT_ROOT/hooks/crypto-pow/crypto-pow-enhanced/target/release/crypto-pow" ]; then
    check_with_output "Crypto-POW binary" "$PROJECT_ROOT/hooks/crypto-pow/crypto-pow-enhanced/target/release/crypto-pow --version" "crypto-pow"
else
    printf "%-40s ${YELLOW}⚠${NC} (not compiled)\n" "Crypto-POW binary"
    ((WARN++))
fi
echo ""

echo -e "${BOLD}Shadowgit Module${NC}"
echo "────────────────────────────────────────"
check_status "Shadowgit Makefile exists" "test -f $PROJECT_ROOT/hooks/shadowgit/Makefile"
check_status "Shadowgit source exists" "test -f $PROJECT_ROOT/hooks/shadowgit/src/shadowgit_avx2_diff.c"
if [ -f "$PROJECT_ROOT/hooks/shadowgit/shadowgit_phase3_test" ]; then
    printf "%-40s ${GREEN}✓${NC} (27KB)\n" "Shadowgit binary"
    ((PASS++))
else
    printf "%-40s ${YELLOW}⚠${NC} (not compiled)\n" "Shadowgit binary"
    ((WARN++))
fi
echo ""

echo -e "${BOLD}Hardware Capabilities${NC}"
echo "────────────────────────────────────────"
check_status "AVX2 support" "grep -q avx2 /proc/cpuinfo"
check_status "AVX-512 support" "grep -q avx512f /proc/cpuinfo"
check_status "AES-NI support" "grep -q aes /proc/cpuinfo"
check_status "FMA support" "grep -q fma /proc/cpuinfo"
echo ""

echo -e "${BOLD}Directory Structure${NC}"
echo "────────────────────────────────────────"
check_status "CLAUDE.md exists" "test -f $PROJECT_ROOT/CLAUDE.md" true
check_status "Agents directory exists" "test -d $PROJECT_ROOT/agents" true
check_status "Hooks directory exists" "test -d $PROJECT_ROOT/hooks" true
check_status "Installers directory exists" "test -d $PROJECT_ROOT/installers" true
echo ""

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Validation Summary${NC}"
echo "────────────────────────────────────────"
echo -e "  ${GREEN}✓ Passed:  $PASS${NC}"
echo -e "  ${YELLOW}⚠ Warnings: $WARN${NC}"
echo -e "  ${RED}✗ Failed:  $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    if [ $WARN -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 Perfect! All checks passed!${NC}"
        exit 0
    else
        echo -e "${YELLOW}${BOLD}✓ System functional with minor warnings${NC}"
        exit 0
    fi
else
    echo -e "${RED}${BOLD}✗ Critical issues detected - please run installer${NC}"
    exit 1
fi
