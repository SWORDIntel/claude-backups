#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE UNIFIED WRAPPER v9.0 - ADVANCED INTELLIGENCE
# 
# Features:
# • Intelligent task analysis and routing
# • Multi-mode execution (Solo, Orchestrated, Hybrid)
# • Permission bypass for LiveCD compatibility
# • Agent discovery and management
# • Task complexity scoring
# • Metrics tracking
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
export CLAUDE_HOME="$HOME/.claude-home"
export CLAUDE_PROJECT_ROOT="PROJECT_ROOT_PLACEHOLDER"

# Check if running from project with .claude directory
if [[ -d "$CLAUDE_PROJECT_ROOT/.claude" ]]; then
    export CLAUDE_DIR="$CLAUDE_PROJECT_ROOT/.claude"
    export CLAUDE_AGENTS_DIR="$CLAUDE_DIR/agents"
    export CLAUDE_CONFIG_DIR="$CLAUDE_DIR/config"
    export CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
    export CLAUDE_ORCHESTRATION_DIR="$CLAUDE_DIR/orchestration"
else
    export CLAUDE_AGENTS_DIR="$HOME/agents"
    export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
    export CLAUDE_HOOKS_DIR="$HOME/.config/claude/hooks"
    export CLAUDE_ORCHESTRATION_DIR="$CLAUDE_PROJECT_ROOT/orchestration"
fi

# Cache and metrics directories
CACHE_DIR="$HOME/.cache/claude"
METRICS_FILE="$CACHE_DIR/metrics.json"
mkdir -p "$CACHE_DIR"

# Binary location
CLAUDE_BINARY="BINARY_PLACEHOLDER"

# Orchestration paths
ORCHESTRATOR_PATH="$CLAUDE_PROJECT_ROOT/agents/src/python/production_orchestrator.py"
TANDEM_ORCHESTRATOR="$CLAUDE_PROJECT_ROOT/agents/src/python/tandem_orchestrator.py"

# Feature flags
PERMISSION_BYPASS="${CLAUDE_PERMISSION_BYPASS:-true}"
ORCHESTRATION_ENABLED="${CLAUDE_ORCHESTRATION:-true}"
DEBUG_MODE="${CLAUDE_DEBUG:-false}"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Find binary if needed
find_claude_binary() {
    if [[ -f "$CLAUDE_BINARY" ]]; then
        echo "$CLAUDE_BINARY"
        return
    fi
    
    for path in \
        "$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js" \
        "$HOME/.npm-global/bin/claude" \
        "/usr/local/bin/claude" \
        "$(which claude 2>/dev/null)" \
        "$(which claude-code 2>/dev/null)"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return
        fi
    done
    
    echo ""
}

# Task complexity analysis
analyze_task_complexity() {
    local task="$1"
    local score=0
    
    # Check for complexity indicators
    [[ "$task" =~ (create|build|develop|implement) ]] && score=$((score + 10))
    [[ "$task" =~ (test|verify|validate) ]] && score=$((score + 8))
    [[ "$task" =~ (security|audit|vulnerability) ]] && score=$((score + 15))
    [[ "$task" =~ (document|docs|readme) ]] && score=$((score + 5))
    [[ "$task" =~ (deploy|release|publish) ]] && score=$((score + 12))
    [[ "$task" =~ (optimize|improve|refactor) ]] && score=$((score + 10))
    [[ "$task" =~ (and|then|with|also) ]] && score=$((score + 15))
    [[ "$task" =~ (pipeline|workflow|multi) ]] && score=$((score + 20))
    
    echo "$score"
}

# Update metrics
update_metrics() {
    local mode="$1"
    
    if [[ ! -f "$METRICS_FILE" ]]; then
        echo '{"executions": 0, "orchestrated": 0}' > "$METRICS_FILE"
    fi
    
    # Simple JSON update (without python dependency)
    local executions=$(grep -o '"executions": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
    local orchestrated=$(grep -o '"orchestrated": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
    
    executions=$((executions + 1))
    [[ "$mode" == "orchestrated" ]] && orchestrated=$((orchestrated + 1))
    
    echo "{\"executions\": $executions, \"orchestrated\": $orchestrated}" > "$METRICS_FILE"
}

# Discover available agents
discover_agents() {
    if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
        find "$CLAUDE_AGENTS_DIR" -maxdepth 1 -name "*.md" -o -name "*.MD" 2>/dev/null | \
            while read -r agent; do
                basename "$agent" | sed 's/\.[mM][dD]$//'
            done | sort
    fi
}

# Show enhanced status
show_status() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              Claude Unified System Status${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    local binary=$(find_claude_binary)
    echo "Binary: ${binary:-Not found}"
    echo "Project Root: $CLAUDE_PROJECT_ROOT"
    echo "Agents Directory: $CLAUDE_AGENTS_DIR"
    echo "Permission Bypass: $PERMISSION_BYPASS"
    echo "Orchestration: $ORCHESTRATION_ENABLED"
    
    if [[ -d "$CLAUDE_AGENTS_DIR" ]]; then
        local count=$(discover_agents | wc -l)
        echo "Available Agents: $count"
    fi
    
    if [[ -f "$ORCHESTRATOR_PATH" ]]; then
        echo -e "Orchestrator: ${GREEN}✓ Installed${NC}"
    else
        echo -e "Orchestrator: ${YELLOW}✗ Not found${NC}"
    fi
    
    if [[ -f "$METRICS_FILE" ]]; then
        echo
        echo "Metrics:"
        cat "$METRICS_FILE" | sed 's/[{},]//g' | sed 's/": /: /g' | sed 's/^/  /'
    fi
}

# Main execution
main() {
    local binary=$(find_claude_binary)
    
    if [[ -z "$binary" ]]; then
        echo "Error: Claude binary not found!"
        echo "Install with: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    
    case "${1:-}" in
        --status|--unified-status)
            show_status
            exit 0
            ;;
            
        --list-agents|--agents)
            echo -e "${CYAN}${BOLD}Available Agents:${NC}"
            discover_agents | while read agent; do
                echo "  • $agent"
            done
            exit 0
            ;;
            
        --metrics)
            if [[ -f "$METRICS_FILE" ]]; then
                echo "Execution Metrics:"
                cat "$METRICS_FILE" | python3 -m json.tool 2>/dev/null || cat "$METRICS_FILE"
            else
                echo "No metrics available"
            fi
            exit 0
            ;;
            
        --help|--unified-help)
            echo -e "${CYAN}${BOLD}Claude Unified Wrapper v9.0${NC}"
            echo
            echo "Usage: claude [options] [command]"
            echo
            echo "Options:"
            echo "  --status           Show system status"
            echo "  --list-agents      List available agents"
            echo "  --metrics          Show execution metrics"
            echo "  --safe             Run without permission bypass"
            echo "  --help             Show this help"
            echo
            echo "Task Commands:"
            echo "  /task \"description\"  Analyze and route task intelligently"
            echo
            echo "Environment Variables:"
            echo "  CLAUDE_PERMISSION_BYPASS=false  Disable permission bypass"
            echo "  CLAUDE_ORCHESTRATION=false      Disable orchestration"
            echo "  CLAUDE_DEBUG=true               Enable debug output"
            exit 0
            ;;
            
        --safe)
            shift
            exec "$binary" "$@"
            ;;
            
        /task|task)
            shift
            local task_text="$*"
            
            if [[ "$ORCHESTRATION_ENABLED" == "true" ]]; then
                # Analyze task complexity
                local complexity=$(analyze_task_complexity "$task_text")
                
                if [[ $complexity -ge 20 ]]; then
                    echo -e "${CYAN}Task complexity: High ($complexity)${NC}"
                    echo -e "${GREEN}Routing to orchestrator...${NC}"
                    
                    if [[ -f "$ORCHESTRATOR_PATH" ]]; then
                        update_metrics "orchestrated"
                        cd "$(dirname "$ORCHESTRATOR_PATH")"
                        export PYTHONPATH="$CLAUDE_PROJECT_ROOT/agents/src/python${PYTHONPATH:+:$PYTHONPATH}"
                        exec python3 "$(basename "$ORCHESTRATOR_PATH")" --task "$task_text"
                    else
                        echo -e "${YELLOW}Orchestrator not found, falling back to direct execution${NC}"
                    fi
                fi
            fi
            
            # Execute with Claude directly
            update_metrics "solo"
            if [[ "$PERMISSION_BYPASS" == "true" ]]; then
                exec "$binary" --dangerously-skip-permissions /task "$task_text"
            else
                exec "$binary" /task "$task_text"
            fi
            ;;
            
        *)
            # Default execution
            update_metrics "solo"
            if [[ "$PERMISSION_BYPASS" == "true" ]]; then
                exec "$binary" --dangerously-skip-permissions "$@"
            else
                exec "$binary" "$@"
            fi
            ;;
    esac
}

# Run main
main "$@"