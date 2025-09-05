# Git Repository Cleanup - September 4, 2025

## Problem
The Git repository had grown to 1.2GB, causing push timeouts and making it difficult to work with.

## Root Cause
Large files in Git history:
- Backup tar.gz archives (615MB + 311MB)
- Compiled Rust target directories
- JSONL conversation history files

## Solution

### Files Preserved
- ✅ All source code (Python, C, Rust, etc.)
- ✅ All 86 agent files (DIRECTOR.md, SECURITY.md, etc.)
- ✅ All documentation
- ✅ All configuration files
- ✅ All scripts and installers
- ✅ Database files (PostgreSQL data)
- ✅ claude-portable directory (Claude binaries)

### Files Removed from History
- ❌ backup_pre_reorganization*.tar.gz (926MB total)
- ❌ Rust target/ directories (compiled artifacts)
- ❌ JSONL conversation files

### Steps Taken

1. **Updated .gitignore** to prevent future large files:
   ```
   *.tar.gz
   target/
   **/target/
   *.jsonl
   config/projects/
   ```

2. **Removed files from current tracking**:
   ```bash
   git rm -r --cached config/projects/
   ```

3. **Used BFG Repo-Cleaner** to clean history:
   ```bash
   java -jar bfg.jar --delete-folders "target" --no-blob-protection .
   java -jar bfg.jar --delete-files "*.tar.gz" --no-blob-protection .
   ```

4. **Garbage collected** to remove unreferenced objects:
   ```bash
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   ```

5. **Force pushed** the cleaned repository:
   ```bash
   git push --force-with-lease origin main
   ```

## Results
- Repository size reduced from **1.2GB to 93MB** (92% reduction)
- Push operations now complete successfully
- All essential files preserved
- History cleaned of unnecessary binary files

## Prevention
- Pre-commit hook installed to block files >10MB
- .gitignore updated to exclude common large file patterns
- Regular backups should be stored outside of Git

## Notes
The claude-portable directory was initially considered for removal but was kept as it contains essential Claude installation binaries needed for the system to function.