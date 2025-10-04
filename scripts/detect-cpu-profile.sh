#!/usr/bin/env bash
# CPU Detection and Compiler Flag Generator
# Detects CPU capabilities and returns appropriate compilation flags
# Supports Intel Meteor Lake, AVX-512, AVX2, and generic x86-64

set -euo pipefail

# Script version
VERSION="1.0.0"

# Usage information
usage() {
    cat << EOF
CPU Detection and Compiler Flag Generator v${VERSION}

Usage: $0 [OPTION]

Options:
    --profile       Return CPU profile name (meteorlake, avx512, avx2, generic)
    --cflags        Return C compiler flags for detected CPU
    --rustflags     Return Rust compiler flags (RUSTFLAGS) for detected CPU
    --info          Display detailed CPU information
    --help          Display this help message
    --version       Display version information

Examples:
    $0 --profile           # Returns: meteorlake
    $0 --cflags            # Returns C compiler flags
    $0 --rustflags         # Returns Rust compiler flags
    $0 --info              # Display full CPU detection report

Supported Profiles:
    meteorlake  - Intel Meteor Lake (AVX2+AVX-VNNI+FMA)
    avx512      - Intel Ice/Tiger/Sapphire Rapids (AVX-512)
    avx2        - Generic AVX2 (Raptor/Alder Lake, AMD Zen)
    generic     - Portable fallback (SSE4.2 minimum)
EOF
    exit 0
}

# Check if running on Linux with /proc/cpuinfo
if [[ ! -f /proc/cpuinfo ]]; then
    echo "Error: /proc/cpuinfo not found. This script requires Linux." >&2
    exit 1
fi

# CPU feature detection functions
has_feature() {
    local feature="$1"
    grep -q "^flags.*\b${feature}\b" /proc/cpuinfo 2>/dev/null
}

get_cpu_vendor() {
    grep -m1 "^vendor_id" /proc/cpuinfo | awk -F': ' '{print $2}' | tr -d '[:space:]'
}

get_cpu_model_name() {
    grep -m1 "^model name" /proc/cpuinfo | awk -F': ' '{print $2}' | sed 's/^[[:space:]]*//'
}

# Detect Intel Meteor Lake specifically
is_meteor_lake() {
    local vendor=$(get_cpu_vendor)
    local model_name=$(get_cpu_model_name)

    # Intel vendor check
    if [[ "$vendor" != "GenuineIntel" ]]; then
        return 1
    fi

    # Check for "Ultra" in model name (Core Ultra series)
    if echo "$model_name" | grep -qi "ultra"; then
        return 0
    fi

    # Check feature combination: AVX-VNNI present, AVX-512 absent
    if has_feature "avx_vnni" && has_feature "avx2" && ! has_feature "avx512f"; then
        return 0
    fi

    return 1
}

# Detect CPU profile
detect_cpu_profile() {
    # Intel Meteor Lake detection (highest priority)
    if is_meteor_lake; then
        echo "meteorlake"
        return 0
    fi

    # AVX-512 detection (Intel Ice Lake, Tiger Lake, Sapphire Rapids, etc.)
    if has_feature "avx512f" && has_feature "avx512dq" && has_feature "avx512bw"; then
        echo "avx512"
        return 0
    fi

    # AVX2 detection (Intel Haswell+, AMD Zen+, etc.)
    if has_feature "avx2" && has_feature "fma"; then
        echo "avx2"
        return 0
    fi

    # Generic fallback (SSE4.2 minimum)
    if has_feature "sse4_2"; then
        echo "generic"
        return 0
    fi

    # Ultimate fallback
    echo "generic"
    return 0
}

# Get C compiler flags for detected profile
get_cflags() {
    local profile=$(detect_cpu_profile)

    case "$profile" in
        meteorlake)
            echo "-O2 -march=native -mtune=native -mavx2 -mfma -mavx-vnni -maes -msse4.2 -flto=thin"
            ;;
        avx512)
            echo "-O2 -march=native -mtune=native -mavx512f -mavx512dq -mavx512bw -mavx2 -mfma -maes -flto=thin"
            ;;
        avx2)
            echo "-O2 -march=native -mtune=native -mavx2 -mfma -msse4.2 -maes -flto=thin"
            ;;
        generic)
            echo "-O2 -march=x86-64 -mtune=generic -msse4.2"
            ;;
        *)
            echo "-O2 -march=x86-64 -mtune=generic"
            ;;
    esac
}

# Get Rust compiler flags for detected profile
get_rustflags() {
    local profile=$(detect_cpu_profile)

    case "$profile" in
        meteorlake|avx512|avx2)
            echo "-C target-cpu=native -C opt-level=2 -C lto=thin"
            ;;
        generic)
            echo "-C opt-level=2"
            ;;
        *)
            echo "-C opt-level=2"
            ;;
    esac
}

# Display detailed CPU information
show_cpu_info() {
    local vendor=$(get_cpu_vendor)
    local model_name=$(get_cpu_model_name)
    local profile=$(detect_cpu_profile)

    echo "=== CPU Detection Report ==="
    echo ""
    echo "CPU Information:"
    echo "  Vendor:       $vendor"
    echo "  Model Name:   $model_name"
    echo ""

    echo "Detected Profile:"
    echo "  Profile:      $profile"
    echo ""

    echo "SIMD Capabilities:"
    printf "  %-15s " "SSE4.2:"
    has_feature "sse4_2" && echo "✓" || echo "✗"

    printf "  %-15s " "AVX:"
    has_feature "avx" && echo "✓" || echo "✗"

    printf "  %-15s " "AVX2:"
    has_feature "avx2" && echo "✓" || echo "✗"

    printf "  %-15s " "AVX-VNNI:"
    has_feature "avx_vnni" && echo "✓" || echo "✗"

    printf "  %-15s " "FMA:"
    has_feature "fma" && echo "✓" || echo "✗"

    printf "  %-15s " "AVX-512F:"
    has_feature "avx512f" && echo "✓" || echo "✗"

    echo ""
    echo "Security Features:"
    printf "  %-15s " "AES-NI:"
    has_feature "aes" && echo "✓" || echo "✗"

    printf "  %-15s " "SHA-NI:"
    has_feature "sha_ni" && echo "✓" || echo "✗"

    echo ""
    echo "Compiler Flags:"
    echo "  CFLAGS:       $(get_cflags)"
    echo "  RUSTFLAGS:    $(get_rustflags)"
    echo ""
}

# Main script logic
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    case "$1" in
        --profile)
            detect_cpu_profile
            ;;
        --cflags)
            get_cflags
            ;;
        --rustflags)
            get_rustflags
            ;;
        --info)
            show_cpu_info
            ;;
        --version)
            echo "CPU Detection Script v${VERSION}"
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            echo "Run '$0 --help' for usage information" >&2
            exit 1
            ;;
    esac
}

main "$@"
