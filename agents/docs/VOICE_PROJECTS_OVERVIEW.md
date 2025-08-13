# 🎤 Voice-to-Text Projects Overview

This directory contains **4 separate voice-to-text projects** that have been properly organized into their own subfolders.

## 📁 Project Organization

### 1. 🎯 **standalone-vtt-system/** (C++ Modern Implementation)
**Complete standalone voice-to-text system - RECOMMENDED**
- **Language**: C++17 with GTK4 GUI
- **Features**: Real-time transcription, global hotkeys, waveform display
- **Status**: ✅ Production ready
- **Architecture**: Direct Whisper integration, PulseAudio capture
- **Usage**: `cd standalone-vtt-system && ./build.sh`

### 2. 🔧 **agent-based-vtt-system/** (C Agent-Based Implementation)
**Multi-agent distributed voice system**
- **Language**: C with agent architecture
- **Features**: Distributed processing, multiple specialized agents
- **Status**: 🚧 Legacy/experimental
- **Architecture**: Director + 8 specialized agents (ML, Security, TUI, etc.)
- **Usage**: `cd agent-based-vtt-system/build_test && ./vtt`

### 3. 🦀 **voice-recognition-rust/** (Rust High-Performance)
**High-performance Rust voice recognition**
- **Language**: Rust with hardware acceleration
- **Features**: OpenVINO acceleration, biometric authentication
- **Status**: 🚧 In development
- **Architecture**: Modular Rust with NPU/GPU support
- **Usage**: `cd voice-recognition-rust && cargo run`

### 4. 🦀 **voice-agent-system/** (Rust Agent System)
**Alternative Rust-based agent system**
- **Language**: Rust with agent orchestration
- **Features**: Message-based agents, accelerator support
- **Status**: 🚧 In development  
- **Architecture**: Core + Agent modules
- **Usage**: `cd voice-agent-system && cargo run`

### 5. 🐍 **voice-recognition-system/** (Python ML-Focused)
**Python-based ML voice recognition system**
- **Language**: Python with ML focus
- **Features**: Self-improvement, biometrics, advanced training
- **Status**: 🚧 Research/experimental
- **Architecture**: ML pipeline with user profiling
- **Usage**: `cd voice-recognition-system && python main.py`

## 🏆 Recommended Usage

For **production use**, start with:
```bash
cd standalone-vtt-system
./build.sh
./build/voice-to-text
```

For **development/experimentation**:
- **Performance focus**: Try `voice-recognition-rust/`
- **ML research**: Try `voice-recognition-system/`
- **Agent architecture**: Try `agent-based-vtt-system/`

## 🗂️ What's NOT in subfolders

The main `agents/` directory still contains:
- General agent framework files
- Distributed system components
- Monitoring and security frameworks
- Build tools and documentation
- Other non-voice-specific agents

## 🔧 Quick Start Commands

```bash
# C++ Standalone (Recommended)
cd standalone-vtt-system && ./build.sh

# C Agent-Based
cd agent-based-vtt-system && ./start_voice.sh

# Rust Performance
cd voice-recognition-rust && cargo build --release

# Rust Agent System  
cd voice-agent-system && cargo run

# Python ML System
cd voice-recognition-system && pip install -r requirements.txt && python main.py
```

## 📋 Feature Comparison

| Feature | Standalone C++ | Agent C | Rust Perf | Rust Agent | Python ML |
|---------|---------------|---------|-----------|------------|-----------|
| GUI | ✅ GTK4 | ❌ TUI only | ❌ None | ❌ None | ❌ None |
| Hotkeys | ✅ Global | ✅ Global | ❌ None | ❌ None | ❌ None |
| Real-time | ✅ <500ms | ✅ Variable | ✅ <100ms | 🚧 Dev | 🚧 Dev |
| Offline | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% | ✅ 100% |
| Ready to use | ✅ Yes | 🟡 Experimental | ❌ WIP | ❌ WIP | ❌ WIP |

---

**🎯 For most users: Start with `standalone-vtt-system/` - it's complete and ready to use!**