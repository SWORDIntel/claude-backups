# Claude Voice System Shortcuts (Auto-generated)
claude-voice() {
    if [ -f "/home/ubuntu/Documents/Claude/agents/voice_config.json" ]; then
        ENABLED=$(python3 -c "import json; print(json.load(open('/home/ubuntu/Documents/Claude/agents/voice_config.json'))['enabled'])" 2>/dev/null || echo "false")
        if [ "$ENABLED" = "True" ]; then
            echo "🎤 Starting Claude Voice Interface..."
            python3 /home/ubuntu/Documents/Claude/agents/basic_voice_interface.py
        else
            echo "🔇 Voice system disabled. Enable with: voice-toggle on"
        fi
    else
        echo "⚠️ Voice system not configured. Run: voice-toggle on"
    fi
}

claude-voice-help() {
    if [ -f "/home/ubuntu/Documents/Claude/agents/voice_config.json" ]; then
        ENABLED=$(python3 -c "import json; print(json.load(open('/home/ubuntu/Documents/Claude/agents/voice_config.json'))['enabled'])" 2>/dev/null || echo "false")
        if [ "$ENABLED" = "True" ]; then
            python3 /home/ubuntu/Documents/Claude/agents/basic_voice_interface.py examples
        else
            echo "🔇 Voice system disabled. Enable with: voice-toggle on"
        fi
    else
        echo "⚠️ Voice system not configured. Run: voice-toggle on"
    fi
}

claude-say() {
    if [ $# -eq 0 ]; then
        echo "Usage: claude-say 'your voice command'"
        echo "Example: claude-say 'Claude, ask the director to plan my project'"
        return
    fi
    
    if [ -f "/home/ubuntu/Documents/Claude/agents/voice_config.json" ]; then
        ENABLED=$(python3 -c "import json; print(json.load(open('/home/ubuntu/Documents/Claude/agents/voice_config.json'))['enabled'])" 2>/dev/null || echo "false")
        if [ "$ENABLED" = "True" ]; then
            echo "🎤 Processing: $1"
            python3 /home/ubuntu/Documents/Claude/agents/quick_voice.py "$1"
        else
            echo "🔇 Voice system disabled. Enable with: voice-toggle on"
        fi
    else
        echo "⚠️ Voice system not configured. Run: voice-toggle on"
    fi
}

voice-toggle() {
    python3 /home/ubuntu/Documents/Claude/agents/VOICE_TOGGLE.py "$@"
}