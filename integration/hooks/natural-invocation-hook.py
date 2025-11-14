#!/usr/bin/env python3
"""Minimal Natural Agent Invocation Hook"""

import os
import sys
from pathlib import Path

# Add paths
sys.path.insert(
    0, os.environ.get("CLAUDE_BASE_PATH", str(Path.home() / ".config/claude"))
)


def hook_pre_task(context):
    """Pre-task hook"""
    return context


def hook_post_edit(context):
    """Post-edit hook"""
    return context


def hook_conversation_analysis(messages):
    """Conversation analysis hook"""
    return None


print("Minimal hook installed - please install full version for complete functionality")
