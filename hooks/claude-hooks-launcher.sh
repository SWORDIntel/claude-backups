#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Unified Hook System Launcher v1.0
# Provides verbose feedback and monitoring dashboard integration
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Terminal colors
print_red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
print_blue() { printf "\033[0;34m%s\033[0m\n" "$1"; }
print_cyan() { printf "\033[0;36m%s\033[0m\n" "$1"; }
print_magenta() { printf "\033[0;35m%s\033[0m\n" "$1"; }
print_bold() { printf "\033[1m%s\033[0m\n" "$1"; }

# Status symbols
readonly SUCCESS="✓"
readonly ERROR="✗"
readonly WARNING="⚠"
readonly INFO="ℹ"
readonly ARROW="→"
readonly PROGRESS="⟳"

# Configuration
HOOKS_DIR="${HOOKS_DIR:-$(dirname "$0")}"
VENV_DIR="$HOOKS_DIR/.venv"
VERBOSE="${VERBOSE:-true}"
SHOW_DASHBOARD="${SHOW_DASHBOARD:-false}"
SHOW_MONITORING="${SHOW_MONITORING:-false}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            ACTION="status"
            shift
            ;;
        --test)
            ACTION="test"
            shift
            ;;
        --monitor)
            ACTION="monitor"
            SHOW_MONITORING="true"
            shift
            ;;
        --dashboard)
            ACTION="dashboard"
            SHOW_DASHBOARD="true"
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --quiet)
            VERBOSE="false"
            shift
            ;;
        --help)
            ACTION="help"
            shift
            ;;
        *)
            INPUT="$*"
            ACTION="process"
            break
            ;;
    esac
done

# Default action
ACTION="${ACTION:-status}"

# Helper functions
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "$@"
    fi
}

show_header() {
    print_bold "╭─────────────────────────────────────────────────────────────────────╮"
    print_bold "│        Claude Unified Hook System v3.1 - Enhanced Launcher         │"
    print_bold "╰─────────────────────────────────────────────────────────────────────╯"
    echo
}

check_dependencies() {
    log_verbose "${PROGRESS} Checking dependencies..."
    
    local missing=()
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi
    
    # Check virtual environment
    if [[ ! -d "$VENV_DIR" ]]; then
        log_verbose "${WARNING} Virtual environment not found at $VENV_DIR"
        log_verbose "${INFO} Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate"
        pip install -q pytest pytest-asyncio psutil 2>/dev/null || true
    else
        source "$VENV_DIR/bin/activate"
    fi
    
    # Check hook system files
    if [[ ! -f "$HOOKS_DIR/claude_unified_hook_system_v2.py" ]]; then
        missing+=("claude_unified_hook_system_v2.py")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_red "${ERROR} Missing dependencies: ${missing[*]}"
        return 1
    fi
    
    log_verbose "${SUCCESS} All dependencies satisfied"
    return 0
}

get_system_status() {
    python3 << 'EOF' 2>/dev/null
import sys
import json
import asyncio
import logging
from pathlib import Path

# Suppress logging output
logging.basicConfig(level=logging.CRITICAL)
logging.getLogger().setLevel(logging.CRITICAL)

# Add hooks directory to path
sys.path.insert(0, ".")

try:
    from claude_unified_hook_system_v2 import ClaudeUnifiedHooks
    
    async def check_status():
        hooks = ClaudeUnifiedHooks()
        status = hooks.get_status()
        
        # Add performance metrics
        test_input = "optimize performance"
        import time
        start = time.time()
        result = await hooks.process(test_input)
        elapsed = (time.time() - start) * 1000
        
        status['last_test'] = {
            'input': test_input,
            'response_time_ms': elapsed,
            'agents_matched': len(result.get('agents', [])),
            'categories': result.get('categories', [])
        }
        
        return status
    
    status = asyncio.run(check_status())
    print(json.dumps(status, indent=2))
    
except Exception as e:
    print(json.dumps({
        'error': str(e),
        'status': 'failed'
    }, indent=2))
    sys.exit(1)
EOF
}

run_tests() {
    print_cyan "${INFO} Running hook system tests..."
    echo
    
    # Run functional tests
    if python3 "$HOOKS_DIR/test_hook_system.py" 2>/dev/null; then
        print_green "${SUCCESS} Functional tests passed"
    else
        print_red "${ERROR} Functional tests failed"
        return 1
    fi
    
    echo
    
    # Run pattern matching debug
    if [[ "$VERBOSE" == "true" ]]; then
        print_cyan "${INFO} Testing pattern matching..."
        python3 "$HOOKS_DIR/debug_pattern_matching.py" 2>/dev/null || true
    fi
    
    return 0
}

show_monitoring() {
    print_cyan "${INFO} Starting monitoring dashboard..."
    echo
    
    # Check if monitoring setup exists
    if [[ ! -f "$HOOKS_DIR/monitoring_setup.py" ]]; then
        print_red "${ERROR} monitoring_setup.py not found"
        return 1
    fi
    
    # Run monitoring
    python3 "$HOOKS_DIR/monitoring_setup.py"
}

process_input() {
    local input="$1"
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_cyan "${INFO} Processing input: \"$input\""
        echo
    fi
    
    python3 << EOF
import sys
import json
import asyncio
from pathlib import Path

sys.path.insert(0, "$HOOKS_DIR")

try:
    from claude_unified_hook_system_v2 import ClaudeUnifiedHooks
    
    async def process():
        hooks = ClaudeUnifiedHooks()
        result = await hooks.process("$input")
        return result
    
    result = asyncio.run(process())
    
    # Format output
    print("═" * 70)
    print("HOOK SYSTEM RESULTS")
    print("═" * 70)
    
    if result.get('agents'):
        print(f"✓ Matched Agents ({len(result['agents'])}): {', '.join(result['agents'][:5])}")
    else:
        print("⚠ No agents matched")
    
    if result.get('categories'):
        print(f"✓ Categories: {', '.join(result['categories'])}")
    
    if result.get('confidence'):
        print(f"✓ Confidence: {result['confidence']:.1%}")
    
    if result.get('workflow'):
        print(f"✓ Workflow: {result['workflow']}")
    
    if result.get('execution_time_ms'):
        print(f"✓ Response Time: {result['execution_time_ms']:.2f}ms")
    
    if result.get('match_details'):
        print("\nMatch Details:")
        for agent, score in list(result['match_details'].items())[:3]:
            print(f"  • {agent}: {score:.2f}")
    
    print("═" * 70)
    
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [INPUT]

Options:
  --status       Show hook system status and configuration
  --test         Run comprehensive tests
  --monitor      Start monitoring dashboard
  --dashboard    Show TUI dashboard
  --verbose      Enable verbose output (default)
  --quiet        Disable verbose output
  --help         Show this help message

Examples:
  $0 --status                              # Check system status
  $0 --test                                # Run tests
  $0 --monitor                             # Start monitoring
  $0 "fix security vulnerability"         # Process input
  $0 "optimize database performance"      # Process another input

Environment Variables:
  HOOKS_DIR         Directory containing hook system files
  VERBOSE           Enable verbose output (true/false)
  SHOW_DASHBOARD    Show TUI dashboard (true/false)
  SHOW_MONITORING   Show monitoring output (true/false)

EOF
}

# Main execution
main() {
    cd "$HOOKS_DIR" 2>/dev/null || true
    
    if [[ "$ACTION" != "help" ]]; then
        show_header
        check_dependencies || exit 1
    fi
    
    case "$ACTION" in
        status)
            print_cyan "${INFO} Checking hook system status..."
            echo
            
            STATUS_JSON=$(get_system_status)
            
            if echo "$STATUS_JSON" | grep -q '"error"'; then
                print_red "${ERROR} Failed to get status"
                echo "$STATUS_JSON" | python3 -m json.tool
                exit 1
            fi
            
            # Parse and display status
            print_green "${SUCCESS} Hook System Status:"
            echo
            
            echo "$STATUS_JSON" | python3 << 'EOF'
import json
import sys

data = json.load(sys.stdin)

print(f"  Version: {data.get('version', 'Unknown')}")
print(f"  Agents Loaded: {data.get('agents_loaded', 0)}")
print(f"  Optimizations: {len(data.get('optimizations', []))}")
print(f"  Security Features: {len(data.get('security_features', []))}")

if 'last_test' in data:
    test = data['last_test']
    print(f"\n  Last Test:")
    print(f"    Input: '{test['input']}'")
    print(f"    Response Time: {test['response_time_ms']:.2f}ms")
    print(f"    Agents Matched: {test['agents_matched']}")
    print(f"    Categories: {', '.join(test['categories'])}")

if 'performance' in data:
    perf = data['performance']
    print(f"\n  Performance:")
    print(f"    Worker Count: {perf.get('worker_count', 'N/A')}")
    print(f"    Cache Size: {perf.get('cache_size', 0)}")
    print(f"    Cache Hits: {perf.get('cache_hits', 0)}")
    print(f"    Cache Misses: {perf.get('cache_misses', 0)}")
EOF
            ;;
            
        test)
            run_tests || exit 1
            ;;
            
        monitor)
            show_monitoring || exit 1
            ;;
            
        dashboard)
            print_yellow "${WARNING} TUI Dashboard not yet implemented"
            print_cyan "${INFO} Use --monitor for monitoring dashboard"
            ;;
            
        process)
            if [[ -z "${INPUT:-}" ]]; then
                print_red "${ERROR} No input provided"
                show_help
                exit 1
            fi
            process_input "$INPUT"
            ;;
            
        help)
            show_help
            ;;
            
        *)
            print_red "${ERROR} Unknown action: $ACTION"
            show_help
            exit 1
            ;;
    esac
    
    echo
    
    if [[ "$VERBOSE" == "true" && "$ACTION" != "help" ]]; then
        print_dim "For more options, run: $0 --help"
    fi
}

# Utility function for dim text (not all terminals support it)
print_dim() { 
    if command -v tput &> /dev/null; then
        tput dim
        echo "$1"
        tput sgr0
    else
        print_cyan "$1"
    fi
}

# Run main function
main "$@"