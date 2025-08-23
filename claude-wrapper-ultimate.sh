#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE ULTIMATE WRAPPER v10.0 - INTELLIGENT ORCHESTRATION
# 
# Features:
# • Smart task analysis with pattern learning
# • Confidence scoring and visual feedback
# • Quick access shortcuts for common tasks
# • Task history and preference learning
# • Interactive suggestion with timeout
# • Metrics and performance tracking
# • Permission bypass for LiveCD
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

# Cache and data directories
CACHE_DIR="$HOME/.cache/claude"
METRICS_FILE="$CACHE_DIR/metrics.json"
PATTERNS_FILE="$CACHE_DIR/patterns.json"
HISTORY_FILE="$CACHE_DIR/history.json"
QUICK_ACCESS_FILE="$CACHE_DIR/quick_access.txt"
mkdir -p "$CACHE_DIR"

# Binary location
CLAUDE_BINARY="BINARY_PLACEHOLDER"

# Orchestration paths
ORCHESTRATOR_PATH="$CLAUDE_PROJECT_ROOT/agents/src/python/production_orchestrator.py"
TANDEM_ORCHESTRATOR="$CLAUDE_PROJECT_ROOT/agents/src/python/tandem_orchestrator.py"

# Feature flags
PERMISSION_BYPASS="${CLAUDE_PERMISSION_BYPASS:-true}"
ORCHESTRATION_ENABLED="${CLAUDE_ORCHESTRATION:-true}"
AUTO_SUGGEST="${CLAUDE_AUTO_SUGGEST:-true}"
LEARNING_MODE="${CLAUDE_LEARNING:-true}"
DEBUG_MODE="${CLAUDE_DEBUG:-false}"
SUGGESTION_TIMEOUT="${CLAUDE_TIMEOUT:-5}"

# Colors and icons
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Icons
readonly BRAIN="🧠"
readonly ROCKET="🚀"
readonly CHECK="✓"
readonly LIGHTBULB="💡"
readonly CHART="📊"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

initialize() {
    # Initialize patterns file
    if [[ ! -f "$PATTERNS_FILE" ]]; then
        cat > "$PATTERNS_FILE" << 'EOF'
{
  "patterns": {
    "simple": ["fix", "update", "change", "modify", "adjust", "tweak", "rename"],
    "moderate": ["implement", "add", "integrate", "setup", "configure", "install"],
    "complex": ["architect", "design", "refactor", "optimize", "migrate", "scale"],
    "multi_agent": ["test.*deploy", "review.*fix", "document.*code", "security.*audit", "create.*test", "build.*deploy"]
  },
  "learned_patterns": [],
  "user_preferences": {}
}
EOF
    fi
    
    # Initialize quick access commands
    if [[ ! -f "$QUICK_ACCESS_FILE" ]]; then
        cat > "$QUICK_ACCESS_FILE" << 'EOF'
# Quick Access Commands - Edit this file to customize
# Format: shortcut|command|description
qa|/task "run quality assurance tests"|Run QA tests
sec|/task "perform security audit"|Security audit
dev|/task "setup development environment"|Dev setup
doc|/task "generate comprehensive documentation"|Documentation
fix|/task "find and fix bugs"|Bug fixing
deploy|/task "deploy to production"|Deployment
test|/task "run all tests"|Run tests
EOF
    fi
    
    # Initialize history
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo '{"tasks": [], "preferences": {}}' > "$HISTORY_FILE"
    fi
    
    # Initialize metrics
    if [[ ! -f "$METRICS_FILE" ]]; then
        echo '{"executions": 0, "orchestrated": 0, "total_time": 0, "avg_complexity": 0}' > "$METRICS_FILE"
    fi
}

# Find Claude binary
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SMART TASK ANALYSIS WITH LEARNING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

analyze_task_smart() {
    local task="$1"
    
    python3 << EOF
import json
import re
from datetime import datetime

task = '''$task'''
patterns_file = '$PATTERNS_FILE'
history_file = '$HISTORY_FILE'

# Load patterns and history
with open(patterns_file, 'r') as f:
    patterns = json.load(f)
    
with open(history_file, 'r') as f:
    history = json.load(f)

# Initialize scoring
score = 0
confidence = 0
reasons = []
task_lower = task.lower()

# Check simple patterns (negative score)
for pattern in patterns['patterns'].get('simple', []):
    if pattern in task_lower:
        score -= 5
        reasons.append(f'Simple: {pattern}')

# Check moderate patterns
for pattern in patterns['patterns'].get('moderate', []):
    if pattern in task_lower:
        score += 10
        reasons.append(f'Moderate: {pattern}')

# Check complex patterns
for pattern in patterns['patterns'].get('complex', []):
    if pattern in task_lower:
        score += 20
        reasons.append(f'Complex: {pattern}')

# Check multi-agent patterns (regex)
for pattern in patterns['patterns'].get('multi_agent', []):
    if re.search(pattern, task_lower):
        score += 30
        reasons.append(f'Multi-agent: {pattern}')

# Check learned patterns
for pattern in patterns.get('learned_patterns', []):
    if pattern in task_lower:
        score += 15
        reasons.append(f'Learned: {pattern}')

# Task structure analysis
word_count = len(task.split())
if word_count > 20:
    score += 10
    reasons.append('Detailed requirements')

# Multi-step indicators
if any(word in task_lower for word in ['then', 'after', 'followed by', 'next', 'finally', 'and then']):
    score += 15
    reasons.append('Multi-step process')

# Check history for similar tasks
similar_tasks = [t for t in history.get('tasks', [])[-20:] 
                 if any(word in t.get('task', '').lower() 
                       for word in task_lower.split()[:3])]

if similar_tasks:
    recent = similar_tasks[-1]
    if recent.get('mode') == 'orchestrated':
        confidence += 20
        reasons.append('Similar to previous orchestrated task')

# Calculate confidence
if score >= 30:
    confidence = min(95, 60 + score)
    suggested_mode = 'orchestrate'
elif score >= 15:
    confidence = 40 + score
    suggested_mode = 'hybrid'
else:
    confidence = max(20, 70 - abs(score))
    suggested_mode = 'direct'

# Output result
result = {
    'score': score,
    'confidence': confidence,
    'mode': suggested_mode,
    'reasons': reasons[:3],
    'word_count': word_count
}

print(json.dumps(result))
EOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INTERACTIVE SUGGESTION UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_suggestion() {
    local task="$1"
    local analysis="$2"
    
    # Parse analysis
    local mode=$(echo "$analysis" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('mode','direct'))")
    local confidence=$(echo "$analysis" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('confidence',0))")
    local score=$(echo "$analysis" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('score',0))")
    local reasons=$(echo "$analysis" | python3 -c "import sys,json; r=json.loads(sys.stdin.read()).get('reasons',[]); print(' • '.join(r) if r else 'Standard task')")
    
    # Don't show suggestion for simple tasks unless forced
    if [[ "$mode" == "direct" ]] && [[ "$AUTO_SUGGEST" == "true" ]] && [[ $score -lt 10 ]]; then
        return 1  # Skip suggestion
    fi
    
    # Build confidence meter
    local conf_bar=""
    local conf_color="$GREEN"
    if [[ $confidence -lt 30 ]]; then
        conf_bar="▰▱▱▱▱"
        conf_color="$DIM"
    elif [[ $confidence -lt 50 ]]; then
        conf_bar="▰▰▱▱▱"
        conf_color="$YELLOW"
    elif [[ $confidence -lt 70 ]]; then
        conf_bar="▰▰▰▱▱"
        conf_color="$CYAN"
    elif [[ $confidence -lt 90 ]]; then
        conf_bar="▰▰▰▰▱"
        conf_color="$GREEN"
    else
        conf_bar="▰▰▰▰▰"
        conf_color="$GREEN"
    fi
    
    # Show analysis
    echo
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│ ${BRAIN} ${BOLD}Task Analysis Complete${NC}                              ${CYAN}│${NC}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────╯${NC}"
    echo
    echo -e "${LIGHTBULB} Analysis: ${DIM}$reasons${NC}"
    echo -e "${CHART} Confidence: ${conf_color}$conf_bar${NC} ${confidence}%"
    echo -e "📊 Complexity Score: $score"
    
    # Show recommendation
    case "$mode" in
        orchestrate)
            echo
            echo -e "${GREEN}${ROCKET} ${BOLD}Recommendation: Use Orchestration${NC}"
            echo -e "${DIM}Multiple specialized agents will collaborate on this task${NC}"
            echo
            echo -e "  ${GREEN}[Enter]${NC} ${CHECK} Accept orchestration"
            echo -e "  ${YELLOW}[c]${NC}     Continue with Claude"
            echo -e "  ${CYAN}[?]${NC}     More details"
            echo
            echo -n "Choice (auto-continue in ${SUGGESTION_TIMEOUT}s): "
            ;;
        hybrid)
            echo
            echo -e "${YELLOW}${BOLD}Suggestion: Consider Orchestration${NC}"
            echo -e "${DIM}This task might benefit from agent assistance${NC}"
            echo
            echo -e "  ${YELLOW}[Enter]${NC} Continue with Claude"
            echo -e "  ${GREEN}[o]${NC}     Use orchestration"
            echo -e "  ${CYAN}[?]${NC}     More details"
            echo
            echo -n "Choice (auto-continue in ${SUGGESTION_TIMEOUT}s): "
            ;;
        *)
            return 1
            ;;
    esac
    
    # Read choice with timeout
    local choice
    read -t "$SUGGESTION_TIMEOUT" -n 1 choice || choice=""
    echo
    
    case "$choice" in
        ""|$'\n')
            if [[ "$mode" == "orchestrate" ]]; then
                learn_from_choice "$task" "orchestrated" "accepted"
                return 0  # Use orchestration
            else
                learn_from_choice "$task" "direct" "default"
                return 1  # Use Claude
            fi
            ;;
        c|C)
            learn_from_choice "$task" "direct" "declined"
            return 1  # Use Claude
            ;;
        o|O)
            learn_from_choice "$task" "orchestrated" "requested"
            return 0  # Use orchestration
            ;;
        "?")
            show_detailed_analysis "$analysis"
            return $(show_suggestion "$task" "$analysis")
            ;;
        *)
            return 1  # Default to Claude
            ;;
    esac
}

show_detailed_analysis() {
    local analysis="$1"
    
    echo
    echo -e "${CYAN}${BOLD}Detailed Analysis:${NC}"
    echo "$analysis" | python3 -m json.tool 2>/dev/null || echo "$analysis"
    echo
    echo "Press any key to continue..."
    read -n 1 -s
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LEARNING SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

learn_from_choice() {
    local task="$1"
    local mode="$2"
    local choice="$3"
    
    [[ "$LEARNING_MODE" != "true" ]] && return
    
    python3 << EOF
import json
from datetime import datetime

task = '''$task'''
mode = '$mode'
choice = '$choice'

# Update history
with open('$HISTORY_FILE', 'r') as f:
    history = json.load(f)

history['tasks'].append({
    'task': task,
    'mode': mode,
    'choice': choice,
    'timestamp': datetime.now().isoformat()
})

# Keep last 100 tasks
history['tasks'] = history['tasks'][-100:]

with open('$HISTORY_FILE', 'w') as f:
    json.dump(history, f, indent=2)

# Learn patterns if user chose orchestration for simple task
if choice == 'requested' and mode == 'orchestrated':
    with open('$PATTERNS_FILE', 'r') as f:
        patterns = json.load(f)
    
    # Extract potential pattern
    words = task.lower().split()[:5]
    if len(words) >= 3:
        pattern = ' '.join(words[:3])
        if pattern not in patterns.get('learned_patterns', []):
            patterns.setdefault('learned_patterns', []).append(pattern)
            patterns['learned_patterns'] = patterns['learned_patterns'][-20:]  # Keep last 20
            
            with open('$PATTERNS_FILE', 'w') as f:
                json.dump(patterns, f, indent=2)
EOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# QUICK ACCESS HANDLER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

handle_quick_access() {
    local cmd="$1"
    
    if [[ -f "$QUICK_ACCESS_FILE" ]]; then
        while IFS='|' read -r shortcut command description; do
            [[ "$shortcut" =~ ^#.*$ ]] && continue
            [[ -z "$shortcut" ]] && continue
            
            if [[ "$cmd" == "$shortcut" ]]; then
                echo -e "${CYAN}Quick Access: ${NC}$description"
                shift
                set -- $command "$@"
                break
            fi
        done < "$QUICK_ACCESS_FILE"
    fi
    
    echo "$@"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# METRICS AND STATUS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

update_metrics() {
    local mode="$1"
    local complexity="${2:-0}"
    
    python3 << EOF
import json

with open('$METRICS_FILE', 'r') as f:
    metrics = json.load(f)

metrics['executions'] = metrics.get('executions', 0) + 1
if '$mode' == 'orchestrated':
    metrics['orchestrated'] = metrics.get('orchestrated', 0) + 1

# Update average complexity
current_avg = metrics.get('avg_complexity', 0)
total = metrics['executions']
new_avg = ((current_avg * (total - 1)) + $complexity) / total
metrics['avg_complexity'] = round(new_avg, 1)

with open('$METRICS_FILE', 'w') as f:
    json.dump(metrics, f, indent=2)
EOF
}

show_status() {
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}              Claude Ultimate System Status${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    local binary=$(find_claude_binary)
    echo "Binary: ${binary:-Not found}"
    echo "Project Root: $CLAUDE_PROJECT_ROOT"
    echo "Permission Bypass: $PERMISSION_BYPASS"
    echo "Orchestration: $ORCHESTRATION_ENABLED"
    echo "Learning Mode: $LEARNING_MODE"
    echo "Auto Suggest: $AUTO_SUGGEST"
    
    if [[ -f "$ORCHESTRATOR_PATH" ]]; then
        echo -e "Orchestrator: ${GREEN}✓ Installed${NC}"
    else
        echo -e "Orchestrator: ${YELLOW}✗ Not found${NC}"
    fi
    
    if [[ -f "$METRICS_FILE" ]]; then
        echo
        echo "Metrics:"
        cat "$METRICS_FILE" | python3 -m json.tool 2>/dev/null | sed 's/^/  /'
    fi
    
    if [[ -f "$PATTERNS_FILE" ]]; then
        local learned_count=$(python3 -c "import json; print(len(json.load(open('$PATTERNS_FILE')).get('learned_patterns', [])))")
        echo "  Learned Patterns: $learned_count"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Initialize on first run
    initialize
    
    local binary=$(find_claude_binary)
    if [[ -z "$binary" ]]; then
        echo "Error: Claude binary not found!"
        echo "Install with: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    
    # Handle quick access shortcuts
    if [[ $# -gt 0 ]]; then
        local expanded=$(handle_quick_access "$1")
        if [[ "$expanded" != "$1" ]]; then
            set -- $expanded
        fi
    fi
    
    # Handle special commands
    case "${1:-}" in
        --status|--unified-status)
            show_status
            exit 0
            ;;
        --metrics)
            if [[ -f "$METRICS_FILE" ]]; then
                echo "Detailed Metrics:"
                cat "$METRICS_FILE" | python3 -m json.tool
            fi
            exit 0
            ;;
        --patterns)
            if [[ -f "$PATTERNS_FILE" ]]; then
                echo "Pattern Configuration:"
                cat "$PATTERNS_FILE" | python3 -m json.tool
            fi
            exit 0
            ;;
        --quick-access)
            echo "Quick Access Commands:"
            cat "$QUICK_ACCESS_FILE" | grep -v '^#'
            exit 0
            ;;
        --help)
            echo -e "${CYAN}${BOLD}Claude Ultimate Wrapper v10.0${NC}"
            echo
            echo "Advanced features:"
            echo "  • Smart task analysis with learning"
            echo "  • Confidence scoring"
            echo "  • Quick access shortcuts"
            echo "  • Pattern-based routing"
            echo "  • Metrics tracking"
            echo
            echo "Commands:"
            echo "  --status         Show system status"
            echo "  --metrics        Show detailed metrics"
            echo "  --patterns       Show pattern configuration"
            echo "  --quick-access   Show quick access commands"
            echo "  --safe           Run without permission bypass"
            echo
            echo "Quick Access:"
            echo "  Type shortcuts like 'qa', 'sec', 'dev' for common tasks"
            echo
            echo "Environment Variables:"
            echo "  CLAUDE_ORCHESTRATION=false   Disable orchestration"
            echo "  CLAUDE_LEARNING=false        Disable learning"
            echo "  CLAUDE_AUTO_SUGGEST=false    Disable suggestions"
            echo "  CLAUDE_TIMEOUT=10            Suggestion timeout (seconds)"
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
                # Analyze task
                local analysis=$(analyze_task_smart "$task_text")
                local score=$(echo "$analysis" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('score',0))")
                
                # Show suggestion if appropriate
                if show_suggestion "$task_text" "$analysis"; then
                    # User chose orchestration
                    update_metrics "orchestrated" "$score"
                    
                    if [[ -f "$ORCHESTRATOR_PATH" ]]; then
                        echo -e "${GREEN}${ROCKET} Launching orchestrator...${NC}"
                        cd "$(dirname "$ORCHESTRATOR_PATH")"
                        export PYTHONPATH="$CLAUDE_PROJECT_ROOT/agents/src/python${PYTHONPATH:+:$PYTHONPATH}"
                        exec python3 "$(basename "$ORCHESTRATOR_PATH")" --task "$task_text"
                    else
                        echo -e "${YELLOW}Orchestrator not found, using Claude directly${NC}"
                    fi
                fi
                
                update_metrics "direct" "$score"
            fi
            
            # Execute with Claude
            if [[ "$PERMISSION_BYPASS" == "true" ]]; then
                exec "$binary" --dangerously-skip-permissions /task "$task_text"
            else
                exec "$binary" /task "$task_text"
            fi
            ;;
        *)
            # Default execution
            update_metrics "direct" "0"
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