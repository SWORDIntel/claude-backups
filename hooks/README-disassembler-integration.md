# DISASSEMBLER Agent Integration Hook

This directory contains the complete integration system for the DISASSEMBLER agent with Ghidra analysis capabilities.

## Components

### 1. `disassembler-hook.py`
Main hook that monitors for binary files and triggers analysis.

**Features:**
- Binary file detection (ELF, PE, Mach-O, etc.)
- File type validation using magic numbers and MIME types
- Analysis caching to avoid duplicate work
- Async execution for performance
- Integration with ghidra-integration.sh

**Usage:**
```bash
# Analyze a specific file
./disassembler-hook.py --file /path/to/binary

# Monitor directory for binaries
./disassembler-hook.py --directory /path/to/dir --recursive

# Show analysis summary
./disassembler-hook.py --summary

# Clear analysis cache
./disassembler-hook.py --clear-cache
```

### 2. `disassembler-bridge.py`
Bridge between the hook and the DISASSEMBLER agent system.

**Features:**
- Agent invocation coordination
- Result processing and scoring
- Batch processing capabilities
- Security assessment scoring
- Complexity analysis

**Usage:**
```bash
# Process a single binary file
./disassembler-bridge.py --file /path/to/binary

# Process all binaries in directory
./disassembler-bridge.py --directory /path/to/dir --recursive

# Save results to file
./disassembler-bridge.py --directory /path/to/dir --output results.json
```

### 3. `test-disassembler-integration.py`
Test script to verify the complete integration workflow.

**Usage:**
```bash
./test-disassembler-integration.py
```

## File Type Detection

The hook automatically detects binary files using:

1. **File extensions:** `.exe`, `.dll`, `.so`, `.dylib`, `.bin`, `.elf`, `.o`, `.obj`, `.lib`, `.a`, `.out`, `.app`
2. **MIME types:** `application/x-executable`, `application/x-sharedlib`, etc.
3. **Magic numbers:** ELF (`\x7fELF`), PE (`MZ`), etc.
4. **Executable bit:** Files with execute permissions

## Integration with Ghidra

The hook integrates with the existing `ghidra-integration.sh` script:

1. Binary file detected by hook
2. DISASSEMBLER agent invoked for initial analysis
3. If complex analysis needed, ghidra-integration.sh is called
4. Results are combined and cached

## Analysis Caching

The system maintains a cache of analysis results to avoid duplicate work:

- Cache location: `hooks/.disassembler_cache.json`
- Files are re-analyzed only if they change (SHA256 hash comparison)
- Cache can be cleared with `--clear-cache` option

## Security Scoring

The bridge calculates a security score (0-100) based on:

- **Security features:** NX/DEP (+10), PIE/ASLR (+15), RELRO/Canary (+10)
- **Vulnerabilities:** Each vulnerability (-20)
- **Base score:** 50

## Complexity Assessment

Reverse engineering complexity is assessed as:

- **Low:** <20 symbols, <50 strings
- **Medium:** 20-100 symbols, 50-200 strings
- **High:** >100 symbols, >200 strings

## Error Handling

- Comprehensive logging to `/tmp/disassembler-hook.log`
- Graceful fallback when dependencies are missing
- Async error handling with proper exception management

## Dependencies

- Python 3.7+
- `python-magic` (optional, for better file type detection)
- `ghidra-integration.sh` (for Ghidra analysis)
- DISASSEMBLER agent (for agent-based analysis)

## Installation

1. Ensure all hook files are in the `hooks/` directory
2. Make scripts executable: `chmod +x *.py`
3. Install optional dependencies: `pip install python-magic`
4. Test integration: `./test-disassembler-integration.py`

## Integration with Agent System

The hooks are designed to work with the Claude agent ecosystem:

1. **DISASSEMBLER Agent:** Primary analysis engine
2. **Task Tool:** Agent coordination mechanism
3. **Project Root:** Automatic detection via `CLAUDE_PROJECT_ROOT`
4. **Ghidra Integration:** Enhanced disassembly capabilities

## Example Workflow

```bash
# 1. Monitor a build directory for new binaries
./disassembler-hook.py --directory /path/to/build --recursive

# 2. Process results through agent bridge
./disassembler-bridge.py --directory /path/to/build --output analysis.json

# 3. Review analysis results
cat analysis.json | jq '.results[] | select(.summary.security_score < 70)'
```

## Troubleshooting

1. **Import errors:** Ensure Python path includes hooks directory
2. **Permission errors:** Check file permissions and executable bits
3. **Missing dependencies:** Install python-magic for better detection
4. **Ghidra issues:** Verify ghidra-integration.sh exists and is executable
5. **Agent errors:** Check CLAUDE_PROJECT_ROOT environment variable

## Future Enhancements

- Real-time file system monitoring (inotify)
- Web interface for analysis results
- Integration with CI/CD pipelines
- Machine learning-based vulnerability detection
- Integration with additional disassemblers (Radare2, Binary Ninja)