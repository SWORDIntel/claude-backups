#!/usr/bin/env bash
################################################################################
# Central Environment Configuration for Claude Project
# Auto-detects paths and creates XDG-compliant directory structure
################################################################################

# Project structure (auto-detect)
export CLAUDE_PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLAUDE_AGENTS_ROOT="${CLAUDE_AGENTS_ROOT:-$CLAUDE_PROJECT_ROOT/agents}"

# Source directories
export CLAUDE_SRC_PYTHON="$CLAUDE_AGENTS_ROOT/src/python"
export CLAUDE_SRC_C="$CLAUDE_AGENTS_ROOT/src/c"
export CLAUDE_SRC_RUST="$CLAUDE_AGENTS_ROOT/src/rust"

# XDG-compliant directories
xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}"
xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
xdg_state="${XDG_STATE_HOME:-$HOME/.local/state}"

export CLAUDE_DATA_HOME="${CLAUDE_DATA_HOME:-$xdg_data/claude}"
export CLAUDE_CONFIG_HOME="${CLAUDE_CONFIG_HOME:-$xdg_config/claude}"
export CLAUDE_STATE_HOME="${CLAUDE_STATE_HOME:-$xdg_state/claude}"
export CLAUDE_CACHE_HOME="${CLAUDE_CACHE_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/claude}"

# Module-specific
export SHADOWGIT_ROOT="$CLAUDE_PROJECT_ROOT/tests/shadowgit"
export DATABASE_ROOT="$CLAUDE_PROJECT_ROOT/database"
export NPU_BRIDGE_ROOT="$CLAUDE_SRC_RUST/npu_coordination_bridge"
export HOOKS_ROOT="$CLAUDE_PROJECT_ROOT/hooks"

# External tools (auto-detect)
export OPENVINO_ROOT="${OPENVINO_ROOT:-$(find /opt -maxdepth 2 -name "openvino*" -type d 2>/dev/null | head -1)}"
export GHIDRA_ROOT="${GHIDRA_ROOT:-$CLAUDE_DATA_HOME/ghidra-workspace}"

# Create all directories
for dir in "$CLAUDE_DATA_HOME" "$CLAUDE_CONFIG_HOME" "$CLAUDE_STATE_HOME" "$CLAUDE_CACHE_HOME" "$GHIDRA_ROOT"; do
    mkdir -p "$dir" 2>/dev/null || true
done

# Subdirectories for security executor
mkdir -p "$CLAUDE_DATA_HOME"/{ghidra-workspace/scripts,hostile-samples,quarantine,analysis-reports} 2>/dev/null || true
mkdir -p "$CLAUDE_CONFIG_HOME/yara-rules" 2>/dev/null || true
mkdir -p "$CLAUDE_DATA_HOME"/{datascience,c-toolchain} 2>/dev/null || true
