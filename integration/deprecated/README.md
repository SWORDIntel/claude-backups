# Deprecated Integration Scripts

These scripts have been superseded by the Python installer and are no longer needed.

## Deprecated Files

### install_unified_integration.sh
**Status:** SUPERSEDED by Python installer

**Original Purpose:**
- Install claude_unified_integration.py
- Create symlinks
- Setup configuration

**Replacement:**
The Python installer now calls `install_unified_integration()` method directly which:
- Creates `~/.local/bin/claude-unified-integration` symlink
- Runs `--setup` automatically
- Installs 94 agents with orchestrator

**Usage (if needed manually):**
```bash
python3 ../claude_unified_integration.py --setup
```

---

### launch_hybrid_system.sh
**Status:** SUPERSEDED by auto-start

**Original Purpose:**
- Manually launch hybrid bridge manager
- Connect to Docker + Native databases

**Replacement:**
Hybrid bridge is now auto-integrated by installer:
- Symlink created: `agents/src/python/hybrid_bridge_manager.py`
- Auto-connects to Docker PostgreSQL (port 5433)
- Health monitoring active (99.9 score)

**Usage (if needed manually):**
```bash
python3 ../agents/src/python/hybrid_bridge_manager.py
```

---

## Active Integration Files

Use these instead:

1. **claude_unified_integration.py** ✅
   - Command: `claude-unified-integration`
   - Auto-installed by installer

2. **enable-natural-invocation.sh** ✅
   - Auto-called by installer
   - Sets up natural language hooks

3. **agent_coordination_matrix.py** ✅
   - Imported by orchestration
   - Used for agent routing

4. **integrate_hybrid_bridge.sh** ✅
   - Auto-called by installer
   - Sets up hybrid DB connection

5. **claude_shell_integration.py**
   - Optional shell integration
   - Can be used standalone

6. **test_unified_integration.py**
   - Test suite
   - Run manually: `python3 integration/test_unified_integration.py`

---

**Last Updated:** 2025-10-11
**Reason:** Python installer now handles all integration automatically
