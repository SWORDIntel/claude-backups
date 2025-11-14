#!/usr/bin/env python3
"""
DISASSEMBLER Hook - Production ULTRATHINK Integration
Actual execution of ghidra-integration.sh, no mock data
"""

import hashlib
import json
import logging
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional

# Setup logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("disassembler-hook")


class DisassemblerHook:
    """
    Production hook that executes actual ghidra-integration.sh
    No mock data - real ULTRATHINK analysis
    """

    def __init__(self, project_root: Optional[str] = None):
        self.project_root = Path(
            project_root
            or os.environ.get("CLAUDE_PROJECT_ROOT", "/home/john/claude-backups")
        )
        self.ghidra_script = self.project_root / "hooks" / "ghidra-integration.sh"
        self.cache_file = self.project_root / ".disassembler_cache.json"
        self.analysis_workspace = self.project_root / ".claude" / "ghidra-workspace"

        # Validate ghidra-integration.sh exists
        if not self.ghidra_script.exists():
            logger.error(
                f"CRITICAL: ghidra-integration.sh not found at {self.ghidra_script}"
            )
            logger.error("Install ULTRATHINK framework first")

        # Make script executable
        if self.ghidra_script.exists():
            self.ghidra_script.chmod(0o755)

        # Create workspace
        self.analysis_workspace.mkdir(parents=True, exist_ok=True)

        # Load cache
        self.cache = self._load_cache()

        # Binary signatures for detection
        self.signatures = {
            b"\x7fELF": "ELF",
            b"MZ": "PE",
            b"\xca\xfe\xba\xbe": "Mach-O 32",
            b"\xcf\xfa\xed\xfe": "Mach-O 64",
            b"\xfe\xed\xfa\xce": "Mach-O BE32",
            b"\xfe\xed\xfa\xcf": "Mach-O BE64",
        }

    def _load_cache(self) -> Dict:
        """Load analysis cache"""
        if self.cache_file.exists():
            try:
                return json.load(open(self.cache_file))
            except:
                pass
        return {}

    def _save_cache(self):
        """Save analysis cache"""
        try:
            json.dump(self.cache, open(self.cache_file, "w"), indent=2)
        except Exception as e:
            logger.error(f"Cache save failed: {e}")

    def is_binary(self, filepath: str) -> bool:
        """Check if file is a binary executable"""
        try:
            with open(filepath, "rb") as f:
                header = f.read(4)

            # Check known signatures
            for sig in self.signatures:
                if header.startswith(sig):
                    return True

            # Check if executable
            if os.access(filepath, os.X_OK):
                # Verify it's not a script
                with open(filepath, "rb") as f:
                    chunk = f.read(512)
                # Check for shebang
                if not chunk.startswith(b"#!"):
                    # High non-text ratio = binary
                    text_chars = set(range(0x20, 0x7F)) | {0x09, 0x0A, 0x0D}
                    nontext = sum(1 for b in chunk if b not in text_chars)
                    if nontext / len(chunk) > 0.3:
                        return True

        except Exception as e:
            logger.debug(f"Binary check failed for {filepath}: {e}")
        return False

    def _get_file_hash(self, filepath: str) -> str:
        """SHA256 hash for caching"""
        try:
            sha256 = hashlib.sha256()
            with open(filepath, "rb") as f:
                for chunk in iter(lambda: f.read(8192), b""):
                    sha256.update(chunk)
            return sha256.hexdigest()
        except:
            return ""

    def should_analyze(self, filepath: str) -> bool:
        """Check if file needs analysis (not cached or changed)"""
        if not os.path.exists(filepath):
            return False

        if not self.is_binary(filepath):
            return False

        # Check cache
        file_hash = self._get_file_hash(filepath)
        if not file_hash:
            return False

        cached = self.cache.get(os.path.abspath(filepath))
        if cached and cached.get("hash") == file_hash:
            logger.info(f"Skipping {filepath} (cached)")
            return False

        return True

    def analyze_with_ultrathink(
        self, filepath: str, mode: str = "comprehensive"
    ) -> Dict:
        """
        Execute actual ghidra-integration.sh ULTRATHINK analysis

        THIS IS THE REAL DEAL - NO MOCKS
        """
        if not self.ghidra_script.exists():
            return {
                "status": "error",
                "error": "ghidra-integration.sh not found",
                "solution": "Ensure ULTRATHINK framework is installed",
            }

        logger.info(f"Executing ULTRATHINK analysis on {filepath}")

        # Prepare environment
        env = os.environ.copy()
        env["ANALYSIS_WORKSPACE"] = str(self.analysis_workspace)
        env["ULTRATHINK_MODE"] = mode
        env["ENABLE_MEME_REPORTS"] = "true"  # Always enable meme reports
        env["ENABLE_ML_SCORING"] = "true"
        env["ENABLE_C2_EXTRACTION"] = "true"

        # Execute ghidra-integration.sh
        try:
            cmd = [str(self.ghidra_script), "analyze", filepath, mode]
            logger.info(f"Running: {' '.join(cmd)}")

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300,  # 5 minute timeout
                env=env,
            )

            # Parse output
            analysis_result = {
                "status": "completed" if result.returncode == 0 else "failed",
                "returncode": result.returncode,
                "filepath": filepath,
                "mode": mode,
                "timestamp": time.time(),
                "hash": self._get_file_hash(filepath),
            }

            # Extract key results from output
            if result.returncode == 0:
                # Parse structured output
                analysis_result.update(self._parse_ultrathink_output(result.stdout))

                # Find generated reports
                analysis_result["reports"] = self._find_generated_reports(filepath)

                # Cache successful result
                self.cache[os.path.abspath(filepath)] = analysis_result
                self._save_cache()

                logger.info(f"ULTRATHINK analysis complete for {filepath}")
            else:
                analysis_result["error"] = result.stderr
                logger.error(f"ULTRATHINK failed: {result.stderr}")

            return analysis_result

        except subprocess.TimeoutExpired:
            logger.error(f"ULTRATHINK timeout for {filepath}")
            return {"status": "timeout", "error": "Analysis exceeded 5 minutes"}
        except Exception as e:
            logger.error(f"ULTRATHINK execution error: {e}")
            return {"status": "error", "error": str(e)}

    def _parse_ultrathink_output(self, output: str) -> Dict:
        """Parse ULTRATHINK script output for structured data"""
        result = {
            "phases_completed": [],
            "threat_score": 0,
            "meme_score": 0,
            "iocs": [],
            "malware_family": "unknown",
        }

        # Parse phase completions
        for phase in ["Phase 1", "Phase 2", "Phase 3", "Phase 4", "Phase 5", "Phase 6"]:
            if phase in output:
                result["phases_completed"].append(phase)

        # Extract threat score
        if "Threat Score:" in output:
            try:
                score_line = [l for l in output.split("\n") if "Threat Score:" in l][0]
                result["threat_score"] = int(
                    score_line.split(":")[1].split("/")[0].strip()
                )
            except:
                pass

        # Extract meme score
        if "MEME SCORE:" in output:
            try:
                score_line = [l for l in output.split("\n") if "MEME SCORE:" in l][0]
                result["meme_score"] = int(
                    score_line.split(":")[1].split("/")[0].strip()
                )
            except:
                pass

        # Extract IOCs
        if "IOC:" in output:
            for line in output.split("\n"):
                if "IOC:" in line:
                    ioc = line.split("IOC:")[1].strip()
                    result["iocs"].append(ioc)

        # Check for specific malware indicators
        if "CRYPTD" in output.upper():
            result["malware_family"] = "CRYPTD"
        elif "UPX" in output:
            result["malware_family"] = "UPX-packed"

        return result

    def _find_generated_reports(self, filepath: str) -> Dict:
        """Find reports generated by ULTRATHINK"""
        reports = {}
        basename = os.path.basename(filepath)

        # Check for HTML reports
        report_dirs = [
            self.analysis_workspace / "results",
            self.analysis_workspace / "analysis-reports",
        ]

        for report_dir in report_dirs:
            if report_dir.exists():
                # Find matching reports
                for report in report_dir.glob(f"*{basename}*.html"):
                    reports[report.stem] = str(report)

                # Check for meme report
                meme_report = report_dir / "meme_report.html"
                if meme_report.exists():
                    reports["meme_report"] = str(meme_report)

        return reports

    def batch_analyze(self, directory: str, recursive: bool = True) -> List[Dict]:
        """Analyze all binaries in directory"""
        results = []

        path = Path(directory)
        if not path.exists():
            return [{"status": "error", "error": f"Directory not found: {directory}"}]

        # Find all binaries
        pattern = "**/*" if recursive else "*"
        for file_path in path.glob(pattern):
            if file_path.is_file() and self.should_analyze(str(file_path)):
                logger.info(f"Analyzing: {file_path}")
                result = self.analyze_with_ultrathink(str(file_path))
                results.append(result)

        return results

    def get_status(self) -> Dict:
        """Check ULTRATHINK framework status"""
        status = {
            "ultrathink_installed": self.ghidra_script.exists(),
            "ghidra_script": str(self.ghidra_script),
            "workspace": str(self.analysis_workspace),
            "workspace_exists": self.analysis_workspace.exists(),
            "cache_size": len(self.cache),
            "ghidra_available": False,
        }

        # Check if Ghidra is available
        try:
            # Try snap first
            result = subprocess.run(["snap", "list"], capture_output=True, text=True)
            if "ghidra" in result.stdout:
                status["ghidra_available"] = True
                status["ghidra_type"] = "snap"
            else:
                # Check common paths
                ghidra_paths = [
                    "/opt/ghidra",
                    "/usr/local/ghidra",
                    Path.home() / "ghidra",
                ]
                for path in ghidra_paths:
                    if path.exists():
                        status["ghidra_available"] = True
                        status["ghidra_type"] = "native"
                        status["ghidra_path"] = str(path)
                        break
        except:
            pass

        return status


# CLI Interface
def main():
    import argparse

    parser = argparse.ArgumentParser(description="DISASSEMBLER ULTRATHINK Hook")
    parser.add_argument("--file", "-f", help="Analyze single file")
    parser.add_argument("--directory", "-d", help="Analyze directory")
    parser.add_argument("--recursive", "-r", action="store_true", help="Recursive scan")
    parser.add_argument(
        "--mode",
        "-m",
        default="comprehensive",
        choices=["static", "dynamic", "comprehensive"],
        help="Analysis mode",
    )
    parser.add_argument("--status", "-s", action="store_true", help="Show status")
    parser.add_argument("--clear-cache", action="store_true", help="Clear cache")

    args = parser.parse_args()

    hook = DisassemblerHook()

    if args.status:
        status = hook.get_status()
        print(json.dumps(status, indent=2))
        if not status["ultrathink_installed"]:
            print("\nWARNING: ghidra-integration.sh not found!")
            print("ULTRATHINK framework not installed")
        if not status["ghidra_available"]:
            print("\nWARNING: Ghidra not detected!")
            print("Install with: sudo snap install ghidra")
        sys.exit(0)

    if args.clear_cache:
        hook.cache = {}
        hook._save_cache()
        print("Cache cleared")
        sys.exit(0)

    if args.file:
        if not hook.is_binary(args.file):
            print(f"Not a binary: {args.file}")
            sys.exit(1)
        result = hook.analyze_with_ultrathink(args.file, args.mode)
        print(json.dumps(result, indent=2))

    elif args.directory:
        results = hook.batch_analyze(args.directory, args.recursive)
        print(json.dumps(results, indent=2))

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
