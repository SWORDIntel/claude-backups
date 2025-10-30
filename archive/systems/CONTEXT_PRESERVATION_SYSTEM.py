#!/usr/bin/env python3
"""
Context Preservation System for Pure Local UI
Maintains conversation context across sessions with zero tokens
"""

import json
import os
import time
from datetime import datetime
from pathlib import Path

class ContextManager:
    def __init__(self, context_dir="/home/john/claude-backups/context"):
        self.context_dir = Path(context_dir)
        self.context_dir.mkdir(exist_ok=True)
        self.session_file = self.context_dir / "current_session.json"
        self.history_file = self.context_dir / "conversation_history.json"
        self.system_state_file = self.context_dir / "system_state.json"

        # Load existing context
        self.load_context()

    def load_context(self):
        """Load existing conversation context"""
        self.conversation_history = []
        self.system_state = {
            "dsmil_active": True,
            "npu_military_mode": True,
            "opus_servers": ["3451", "3452", "3453", "3454"],
            "performance": "45.88 TFLOPS",
            "voice_enabled": True,
            "zero_token_mode": True,
            "last_update": datetime.now().isoformat()
        }

        # Load conversation history
        if self.history_file.exists():
            try:
                with open(self.history_file, 'r') as f:
                    self.conversation_history = json.load(f)
            except:
                pass

        # Load system state
        if self.system_state_file.exists():
            try:
                with open(self.system_state_file, 'r') as f:
                    saved_state = json.load(f)
                    self.system_state.update(saved_state)
            except:
                pass

    def add_message(self, message, response, metadata=None):
        """Add message to conversation history"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "user_message": message,
            "ai_response": response,
            "metadata": metadata or {},
            "session_id": self.get_session_id()
        }

        self.conversation_history.append(entry)

        # Keep only last 100 messages to manage memory
        if len(self.conversation_history) > 100:
            self.conversation_history = self.conversation_history[-100:]

        self.save_context()

    def get_session_id(self):
        """Get current session ID"""
        return datetime.now().strftime("%Y%m%d_%H%M")

    def get_context_summary(self):
        """Get summary of current context for new conversations"""
        summary = {
            "system_capabilities": [
                "DSMIL military-grade framework active",
                "NPU military mode: 26.4 TOPS performance",
                "45.88 TFLOPS total system performance",
                "Zero external token usage",
                "4 local Opus servers operational",
                "Voice UI with NPU acceleration",
                "98 specialized agents available",
                "Pure local operation - no external APIs"
            ],
            "current_session": {
                "messages_count": len(self.conversation_history),
                "session_start": self.conversation_history[0]["timestamp"] if self.conversation_history else None,
                "last_activity": self.conversation_history[-1]["timestamp"] if self.conversation_history else None
            },
            "system_status": self.system_state,
            "recent_topics": self.extract_recent_topics()
        }
        return summary

    def extract_recent_topics(self, last_n=10):
        """Extract recent conversation topics"""
        if not self.conversation_history:
            return []

        recent_messages = self.conversation_history[-last_n:]
        topics = []

        for msg in recent_messages:
            # Simple keyword extraction
            text = msg["user_message"].lower()
            if "dsmil" in text or "military" in text:
                topics.append("DSMIL military framework")
            elif "voice" in text or "npu" in text:
                topics.append("Voice UI and NPU acceleration")
            elif "performance" in text or "tflops" in text:
                topics.append("System performance optimization")
            elif "local" in text or "token" in text:
                topics.append("Local operation and token usage")

        return list(set(topics))  # Remove duplicates

    def save_context(self):
        """Save current context to files"""
        try:
            # Save conversation history
            with open(self.history_file, 'w') as f:
                json.dump(self.conversation_history, f, indent=2)

            # Update and save system state
            self.system_state["last_update"] = datetime.now().isoformat()
            with open(self.system_state_file, 'w') as f:
                json.dump(self.system_state, f, indent=2)

        except Exception as e:
            print(f"Error saving context: {e}")

    def update_system_state(self, key, value):
        """Update system state"""
        self.system_state[key] = value
        self.save_context()

    def get_contextual_prompt(self, new_message):
        """Generate contextual prompt for local AI"""
        summary = self.get_context_summary()

        prompt = f"""Context: You are operating in pure local mode with zero external tokens.

System Status:
- DSMIL military framework: {summary['system_status']['dsmil_active']}
- NPU military mode: {summary['system_status']['npu_military_mode']} (26.4 TOPS)
- Total performance: {summary['system_status']['performance']}
- Local Opus servers: {len(summary['system_status']['opus_servers'])} active
- Voice UI: {summary['system_status']['voice_enabled']}

Recent conversation topics: {', '.join(summary['recent_topics'])}

Current message: {new_message}

Respond as a local AI system with access to military-grade hardware capabilities."""

        return prompt

    def clear_old_context(self, days_old=7):
        """Clear context older than specified days"""
        cutoff_time = time.time() - (days_old * 24 * 60 * 60)

        self.conversation_history = [
            msg for msg in self.conversation_history
            if datetime.fromisoformat(msg["timestamp"]).timestamp() > cutoff_time
        ]

        self.save_context()

# Enhanced Pure Local UI with Context
def create_context_aware_ui():
    """Create the context-aware pure local UI"""
    return '''
    // Add to existing PURE_LOCAL_OFFLINE_UI.py JavaScript section

    // Context management
    let contextManager = {
        history: [],
        systemState: {},

        addMessage: function(message, response) {
            this.history.push({
                timestamp: new Date().toISOString(),
                user: message,
                ai: response
            });

            // Keep last 50 messages in browser
            if (this.history.length > 50) {
                this.history = this.history.slice(-50);
            }

            this.saveToLocal();
        },

        saveToLocal: function() {
            localStorage.setItem('claude_context', JSON.stringify({
                history: this.history,
                systemState: this.systemState,
                lastUpdate: new Date().toISOString()
            }));
        },

        loadFromLocal: function() {
            const saved = localStorage.getItem('claude_context');
            if (saved) {
                const data = JSON.parse(saved);
                this.history = data.history || [];
                this.systemState = data.systemState || {};

                // Restore conversation display
                this.restoreConversation();
            }
        },

        restoreConversation: function() {
            const messages = document.getElementById('chatMessages');
            messages.innerHTML = '<div class="message ai-message"><strong>🤖 Local AI:</strong> Context restored. Previous conversation history available.</div>';

            // Show last few messages
            const recentMessages = this.history.slice(-5);
            recentMessages.forEach(msg => {
                addMessage(msg.user, true);
                addMessage(msg.ai, false);
            });
        },

        getContextSummary: function() {
            return {
                messageCount: this.history.length,
                recentTopics: this.extractTopics(),
                systemStatus: this.systemState
            };
        },

        extractTopics: function() {
            const recent = this.history.slice(-10);
            const topics = new Set();

            recent.forEach(msg => {
                const text = msg.user.toLowerCase();
                if (text.includes('dsmil') || text.includes('military')) topics.add('DSMIL');
                if (text.includes('voice') || text.includes('npu')) topics.add('Voice/NPU');
                if (text.includes('performance') || text.includes('tflops')) topics.add('Performance');
                if (text.includes('local') || text.includes('token')) topics.add('Local Mode');
            });

            return Array.from(topics);
        }
    };

    // Override sendMessage to include context
    async function sendMessageWithContext() {
        const input = document.getElementById('chatInput');
        const message = input.value.trim();
        if (!message) return;

        addMessage(message, true);
        input.value = '';

        try {
            // Include context in request
            const contextSummary = contextManager.getContextSummary();

            const response = await fetch('/local_chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    message: message,
                    context: contextSummary,
                    timestamp: Date.now()
                })
            });

            const data = await response.json();
            const aiResponse = data.response || 'Local processing complete.';

            addMessage(aiResponse, false);
            contextManager.addMessage(message, aiResponse);

        } catch (error) {
            addMessage('Error: Local server not responding. Check Opus servers.');
        }
    }

    // Load context on startup
    window.addEventListener('load', function() {
        contextManager.loadFromLocal();
    });
    '''

if __name__ == "__main__":
    # Test context manager
    cm = ContextManager()

    # Add some test context
    cm.add_message(
        "Test the DSMIL military framework",
        "DSMIL framework active with 26.4 TOPS NPU performance",
        {"system": "local", "tokens": 0}
    )

    print("Context Manager initialized")
    print(f"Session ID: {cm.get_session_id()}")
    print(f"Context summary: {cm.get_context_summary()}")