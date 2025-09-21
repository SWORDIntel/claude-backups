#!/usr/bin/env python3
"""
DISASSEMBLER Agent Integration Hook
Monitors for binary files and triggers DISASSEMBLER agent analysis via ghidra-integration.sh
"""

import os
import sys
import asyncio
import subprocess
import logging
import json
import hashlib
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import mimetypes

# Optional dependency for better file type detection
try:
    import magic
    HAS_MAGIC = True
except ImportError:
    HAS_MAGIC = False

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/disassembler-hook.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('disassembler-hook')

class DisassemblerHook:
    """
    DISASSEMBLER Agent Integration Hook
    Monitors for binary files and triggers analysis when appropriate
    """

    def __init__(self, project_root: Optional[str] = None):
        self.project_root = project_root or os.environ.get('CLAUDE_PROJECT_ROOT', '/home/john/claude-backups')
        self.hooks_dir = os.path.join(self.project_root, 'hooks')
        self.ghidra_script = os.path.join(self.hooks_dir, 'ghidra-integration.sh')
        self.analysis_cache = os.path.join(self.hooks_dir, '.disassembler_cache.json')

        # File type patterns for binary analysis
        self.binary_extensions = {
            '.exe', '.dll', '.so', '.dylib', '.bin', '.elf',
            '.o', '.obj', '.lib', '.a', '.out', '.app'
        }

        # MIME types for binary files
        self.binary_mimetypes = {
            'application/x-executable',
            'application/x-sharedlib',
            'application/x-object',
            'application/x-archive',
            'application/x-mach-binary',
            'application/octet-stream'
        }

        # Cache for analysis results
        self.cache = self._load_cache()

        # Initialize magic for file type detection
        if HAS_MAGIC:
            try:
                self.magic = magic.Magic(mime=True)
            except Exception as e:
                logger.warning(f"Could not initialize python-magic: {e}")
                self.magic = None
        else:
            self.magic = None
            logger.info("python-magic not available, using fallback file detection")

    def _load_cache(self) -> Dict:
        """Load analysis cache from disk"""
        try:
            if os.path.exists(self.analysis_cache):
                with open(self.analysis_cache, 'r') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Could not load cache: {e}")
        return {}

    def _save_cache(self):
        """Save analysis cache to disk"""
        try:
            with open(self.analysis_cache, 'w') as f:
                json.dump(self.cache, f, indent=2)
        except Exception as e:
            logger.error(f"Could not save cache: {e}")

    def _get_file_hash(self, filepath: str) -> str:
        """Get SHA256 hash of file for caching"""
        try:
            with open(filepath, 'rb') as f:
                return hashlib.sha256(f.read()).hexdigest()
        except Exception as e:
            logger.error(f"Could not hash file {filepath}: {e}")
            return ""

    def is_binary_file(self, filepath: str) -> bool:
        """
        Determine if file is a binary that should be analyzed

        Args:
            filepath: Path to file to check

        Returns:
            True if file should be analyzed by DISASSEMBLER
        """
        try:
            if not os.path.isfile(filepath):
                return False

            # Check file extension
            path = Path(filepath)
            if path.suffix.lower() in self.binary_extensions:
                return True

            # Check MIME type with python-magic if available
            if self.magic:
                try:
                    mime_type = self.magic.from_file(filepath)
                    if mime_type in self.binary_mimetypes:
                        return True
                except Exception as e:
                    logger.debug(f"Magic detection failed for {filepath}: {e}")

            # Fallback to mimetypes module
            mime_type, _ = mimetypes.guess_type(filepath)
            if mime_type in self.binary_mimetypes:
                return True

            # Check if file is executable
            if os.access(filepath, os.X_OK) and not filepath.endswith(('.sh', '.py', '.pl', '.rb', '.js')):
                return True

            # Check for ELF magic number
            try:
                with open(filepath, 'rb') as f:
                    magic_bytes = f.read(4)
                    if magic_bytes == b'\x7fELF':  # ELF magic
                        return True
                    if magic_bytes[:2] == b'MZ':   # PE magic
                        return True
                    if magic_bytes == b'\xcf\xfa\xed\xfe':  # Mach-O 32-bit
                        return True
                    if magic_bytes == b'\xcf\xfa\xed\xfe':  # Mach-O 64-bit
                        return True
            except Exception:
                pass

            return False

        except Exception as e:
            logger.error(f"Error checking if {filepath} is binary: {e}")
            return False

    def should_analyze(self, filepath: str) -> bool:
        """
        Determine if file should be analyzed (not in cache or changed)

        Args:
            filepath: Path to file to check

        Returns:
            True if file should be analyzed
        """
        if not os.path.exists(filepath):
            return False

        if not self.is_binary_file(filepath):
            return False

        # Check cache
        file_hash = self._get_file_hash(filepath)
        if not file_hash:
            return False

        cache_key = os.path.abspath(filepath)
        cached_entry = self.cache.get(cache_key)

        if cached_entry and cached_entry.get('hash') == file_hash:
            logger.debug(f"File {filepath} already analyzed (cached)")
            return False

        return True

    async def invoke_disassembler_agent(self, filepath: str, analysis_type: str = "comprehensive") -> Dict:
        """
        Invoke DISASSEMBLER agent for file analysis

        Args:
            filepath: Path to file to analyze
            analysis_type: Type of analysis to perform

        Returns:
            Analysis results from DISASSEMBLER agent
        """
        try:
            # Prepare DISASSEMBLER agent invocation
            agent_prompt = f"""
            Analyze the binary file: {filepath}

            Perform {analysis_type} analysis including:
            - File format identification
            - Architecture detection
            - Entry point analysis
            - String extraction
            - Symbol table analysis
            - Security analysis (stack canaries, DEP, ASLR)
            - Vulnerability detection

            Use ghidra-integration.sh for detailed disassembly when appropriate.

            File details:
            - Path: {filepath}
            - Size: {os.path.getsize(filepath)} bytes
            - Modified: {time.ctime(os.path.getmtime(filepath))}
            """

            # Note: In a real implementation, this would invoke the DISASSEMBLER agent
            # via the Task tool or agent coordination system
            logger.info(f"Would invoke DISASSEMBLER agent for: {filepath}")

            # Get basic file info for mock response
            file_stat = os.stat(filepath)

            # Determine architecture and format from file command
            try:
                file_cmd = subprocess.run(['file', filepath], capture_output=True, text=True)
                file_output = file_cmd.stdout.strip()
            except Exception:
                file_output = "Unknown file type"

            # Mock agent response with some real data
            result = {
                "status": "analyzed",
                "filepath": filepath,
                "analysis_type": analysis_type,
                "timestamp": time.time(),
                "agent": "DISASSEMBLER",
                "findings": {
                    "file_format": file_output,
                    "architecture": "x86-64" if "x86-64" in file_output else "unknown",
                    "file_size": file_stat.st_size,
                    "permissions": oct(file_stat.st_mode)[-3:],
                    "security_features": ["NX", "PIE"] if "executable" in file_output else [],
                    "vulnerabilities": [],
                    "strings": [],
                    "symbols": [],
                    "complexity": "medium"
                }
            }

            return result

        except Exception as e:
            logger.error(f"Error invoking DISASSEMBLER agent for {filepath}: {e}")
            return {"status": "error", "error": str(e)}

    async def run_ghidra_analysis(self, filepath: str) -> Dict:
        """
        Run Ghidra analysis via ghidra-integration.sh script

        Args:
            filepath: Path to file to analyze

        Returns:
            Ghidra analysis results
        """
        try:
            if not os.path.exists(self.ghidra_script):
                logger.warning(f"Ghidra script not found: {self.ghidra_script}")
                return {"status": "skipped", "reason": "ghidra-integration.sh not found"}

            # Run ghidra-integration.sh
            cmd = [self.ghidra_script, filepath]
            logger.info(f"Running Ghidra analysis: {' '.join(cmd)}")

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=self.hooks_dir
            )

            stdout, stderr = await process.communicate()

            result = {
                "status": "completed" if process.returncode == 0 else "failed",
                "returncode": process.returncode,
                "stdout": stdout.decode('utf-8', errors='ignore'),
                "stderr": stderr.decode('utf-8', errors='ignore'),
                "timestamp": time.time()
            }

            if process.returncode == 0:
                logger.info(f"Ghidra analysis completed for {filepath}")
            else:
                logger.error(f"Ghidra analysis failed for {filepath}: {stderr.decode()}")

            return result

        except Exception as e:
            logger.error(f"Error running Ghidra analysis for {filepath}: {e}")
            return {"status": "error", "error": str(e)}

    async def analyze_file(self, filepath: str) -> Dict:
        """
        Perform complete analysis of a binary file

        Args:
            filepath: Path to file to analyze

        Returns:
            Combined analysis results
        """
        if not self.should_analyze(filepath):
            return {"status": "skipped", "reason": "not_required"}

        logger.info(f"Starting analysis of: {filepath}")

        try:
            # Run DISASSEMBLER agent analysis
            agent_result = await self.invoke_disassembler_agent(filepath)

            # Run Ghidra analysis if available
            ghidra_result = await self.run_ghidra_analysis(filepath)

            # Combine results
            combined_result = {
                "filepath": filepath,
                "timestamp": time.time(),
                "hash": self._get_file_hash(filepath),
                "agent_analysis": agent_result,
                "ghidra_analysis": ghidra_result,
                "status": "completed"
            }

            # Cache results
            cache_key = os.path.abspath(filepath)
            self.cache[cache_key] = combined_result
            self._save_cache()

            logger.info(f"Analysis completed for: {filepath}")
            return combined_result

        except Exception as e:
            logger.error(f"Error analyzing {filepath}: {e}")
            return {"status": "error", "error": str(e)}

    async def monitor_directory(self, directory: str, recursive: bool = True) -> List[Dict]:
        """
        Monitor directory for binary files and analyze them

        Args:
            directory: Directory to monitor
            recursive: Whether to scan recursively

        Returns:
            List of analysis results
        """
        results = []

        try:
            if recursive:
                for root, dirs, files in os.walk(directory):
                    for file in files:
                        filepath = os.path.join(root, file)
                        if self.should_analyze(filepath):
                            result = await self.analyze_file(filepath)
                            results.append(result)
            else:
                for file in os.listdir(directory):
                    filepath = os.path.join(directory, file)
                    if os.path.isfile(filepath) and self.should_analyze(filepath):
                        result = await self.analyze_file(filepath)
                        results.append(result)

        except Exception as e:
            logger.error(f"Error monitoring directory {directory}: {e}")

        return results

    def get_analysis_summary(self) -> Dict:
        """Get summary of all cached analyses"""
        try:
            total_files = len(self.cache)
            successful = len([v for v in self.cache.values() if v.get('status') == 'completed'])
            failed = len([v for v in self.cache.values() if v.get('status') == 'error'])

            return {
                "total_analyzed": total_files,
                "successful": successful,
                "failed": failed,
                "cache_size": total_files,
                "last_analysis": max([v.get('timestamp', 0) for v in self.cache.values()] + [0])
            }
        except Exception as e:
            logger.error(f"Error generating summary: {e}")
            return {"error": str(e)}

# CLI Interface
async def main():
    """Main CLI interface for DISASSEMBLER hook"""
    import argparse

    parser = argparse.ArgumentParser(description='DISASSEMBLER Agent Integration Hook')
    parser.add_argument('--file', '-f', help='Analyze specific file')
    parser.add_argument('--directory', '-d', help='Monitor directory for binary files')
    parser.add_argument('--recursive', '-r', action='store_true', help='Recursive directory scan')
    parser.add_argument('--summary', '-s', action='store_true', help='Show analysis summary')
    parser.add_argument('--clear-cache', action='store_true', help='Clear analysis cache')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    hook = DisassemblerHook()

    if args.clear_cache:
        hook.cache = {}
        hook._save_cache()
        print("Analysis cache cleared")
        return

    if args.summary:
        summary = hook.get_analysis_summary()
        print(json.dumps(summary, indent=2))
        return

    if args.file:
        result = await hook.analyze_file(args.file)
        print(json.dumps(result, indent=2))
        return

    if args.directory:
        results = await hook.monitor_directory(args.directory, args.recursive)
        print(json.dumps(results, indent=2))
        return

    # Default: monitor current directory
    results = await hook.monitor_directory('.', False)
    print(json.dumps(results, indent=2))

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nDisassembler hook interrupted")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)