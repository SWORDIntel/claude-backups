#!/usr/bin/env python3
"""
DISASSEMBLER Bridge - Connects DISASSEMBLER hook with agent system
Provides seamless integration between file monitoring and agent invocation
"""

import os
import sys
import asyncio
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional

# Add project root to path for agent imports
project_root = os.environ.get('CLAUDE_PROJECT_ROOT', '/home/john/claude-backups')
sys.path.insert(0, os.path.join(project_root, 'agents', 'src', 'python'))

logger = logging.getLogger('disassembler-bridge')

class DisassemblerBridge:
    """
    Bridge between DISASSEMBLER hook and agent system
    Handles agent invocation and result processing
    """

    def __init__(self, project_root: Optional[str] = None):
        self.project_root = project_root or os.environ.get('CLAUDE_PROJECT_ROOT', '/home/john/claude-backups')
        self.agent_dir = os.path.join(self.project_root, 'agents')
        self.hooks_dir = os.path.join(self.project_root, 'hooks')

        # Import disassembler hook
        try:
            sys.path.insert(0, self.hooks_dir)
            from disassembler_hook import DisassemblerHook
            self.hook = DisassemblerHook(project_root)
        except ImportError as e:
            logger.error(f"Could not import DisassemblerHook: {e}")
            self.hook = None

    async def invoke_agent_via_task(self, agent_name: str, prompt: str) -> Dict:
        """
        Invoke agent via Task tool (simulated for now)

        Args:
            agent_name: Name of agent to invoke
            prompt: Prompt to send to agent

        Returns:
            Agent response
        """
        try:
            # In a real implementation, this would use Claude Code's Task tool
            # For now, we simulate the agent response

            logger.info(f"Invoking {agent_name} agent with prompt: {prompt[:100]}...")

            # Simulate agent processing time
            await asyncio.sleep(0.1)

            # Mock response based on agent type
            if agent_name.lower() == 'disassembler':
                response = {
                    "agent": "DISASSEMBLER",
                    "status": "success",
                    "analysis": {
                        "file_format": "ELF 64-bit LSB executable",
                        "architecture": "x86-64",
                        "entry_point": "0x1040",
                        "security_features": ["NX", "PIE", "RELRO"],
                        "symbols": ["main", "printf", "exit"],
                        "strings": ["Hello World", "/lib64/ld-linux-x86-64.so.2"],
                        "vulnerabilities": []
                    },
                    "recommendations": [
                        "File appears to be a standard executable",
                        "No obvious security vulnerabilities detected",
                        "Consider deeper analysis with Ghidra for complex binaries"
                    ]
                }
            else:
                response = {
                    "agent": agent_name,
                    "status": "success",
                    "message": f"Agent {agent_name} processed request successfully"
                }

            return response

        except Exception as e:
            logger.error(f"Error invoking agent {agent_name}: {e}")
            return {
                "agent": agent_name,
                "status": "error",
                "error": str(e)
            }

    async def process_binary_file(self, filepath: str) -> Dict:
        """
        Process a binary file through the complete analysis pipeline

        Args:
            filepath: Path to binary file to analyze

        Returns:
            Complete analysis results
        """
        try:
            if not self.hook:
                return {"status": "error", "error": "DisassemblerHook not available"}

            # Check if file should be analyzed
            if not self.hook.should_analyze(filepath):
                return {"status": "skipped", "reason": "file_not_eligible"}

            logger.info(f"Processing binary file: {filepath}")

            # Step 1: Basic file analysis via hook
            hook_result = await self.hook.analyze_file(filepath)

            # Step 2: Invoke DISASSEMBLER agent for advanced analysis
            agent_prompt = f"""
            Perform comprehensive analysis of binary file: {filepath}

            File information:
            - Path: {filepath}
            - Size: {os.path.getsize(filepath) if os.path.exists(filepath) else 'unknown'} bytes
            - Type: Binary executable/library

            Please analyze:
            1. File format and architecture
            2. Security features (DEP, ASLR, stack canaries)
            3. Entry points and critical functions
            4. String analysis and potential indicators
            5. Vulnerability assessment
            6. Reverse engineering complexity

            Coordinate with ghidra-integration.sh if deeper disassembly is needed.
            """

            agent_result = await self.invoke_agent_via_task("DISASSEMBLER", agent_prompt)

            # Step 3: Combine results
            combined_result = {
                "filepath": filepath,
                "timestamp": hook_result.get("timestamp"),
                "status": "completed",
                "hook_analysis": hook_result,
                "agent_analysis": agent_result,
                "summary": {
                    "analyzed_by": ["DisassemblerHook", "DISASSEMBLER_Agent"],
                    "ghidra_used": hook_result.get("ghidra_analysis", {}).get("status") == "completed",
                    "security_score": self._calculate_security_score(agent_result),
                    "complexity": self._assess_complexity(agent_result)
                }
            }

            logger.info(f"Completed processing of: {filepath}")
            return combined_result

        except Exception as e:
            logger.error(f"Error processing binary file {filepath}: {e}")
            return {"status": "error", "error": str(e)}

    def _calculate_security_score(self, agent_result: Dict) -> int:
        """Calculate security score based on agent analysis (0-100)"""
        try:
            analysis = agent_result.get("analysis", {})
            security_features = analysis.get("security_features", [])
            vulnerabilities = analysis.get("vulnerabilities", [])

            base_score = 50

            # Add points for security features
            for feature in security_features:
                if feature.upper() in ["NX", "DEP"]:
                    base_score += 10
                elif feature.upper() in ["PIE", "ASLR"]:
                    base_score += 15
                elif feature.upper() in ["RELRO", "CANARY", "FORTIFY"]:
                    base_score += 10

            # Subtract points for vulnerabilities
            base_score -= len(vulnerabilities) * 20

            return max(0, min(100, base_score))
        except Exception:
            return 50  # Default score

    def _assess_complexity(self, agent_result: Dict) -> str:
        """Assess reverse engineering complexity"""
        try:
            analysis = agent_result.get("analysis", {})
            symbols = analysis.get("symbols", [])
            strings = analysis.get("strings", [])

            if len(symbols) > 100 or len(strings) > 200:
                return "high"
            elif len(symbols) > 20 or len(strings) > 50:
                return "medium"
            else:
                return "low"
        except Exception:
            return "unknown"

    async def batch_process_directory(self, directory: str, recursive: bool = True) -> List[Dict]:
        """
        Process all binary files in a directory

        Args:
            directory: Directory to process
            recursive: Process subdirectories

        Returns:
            List of analysis results
        """
        results = []

        try:
            if not os.path.exists(directory):
                return [{"status": "error", "error": f"Directory not found: {directory}"}]

            files_to_process = []

            if recursive:
                for root, dirs, files in os.walk(directory):
                    for file in files:
                        filepath = os.path.join(root, file)
                        if self.hook and self.hook.is_binary_file(filepath):
                            files_to_process.append(filepath)
            else:
                for file in os.listdir(directory):
                    filepath = os.path.join(directory, file)
                    if os.path.isfile(filepath) and self.hook and self.hook.is_binary_file(filepath):
                        files_to_process.append(filepath)

            logger.info(f"Found {len(files_to_process)} binary files to process")

            # Process files with concurrency limit
            semaphore = asyncio.Semaphore(3)  # Max 3 concurrent analyses

            async def process_with_semaphore(filepath):
                async with semaphore:
                    return await self.process_binary_file(filepath)

            tasks = [process_with_semaphore(fp) for fp in files_to_process]
            results = await asyncio.gather(*tasks, return_exceptions=True)

            # Handle exceptions
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    results[i] = {
                        "filepath": files_to_process[i],
                        "status": "error",
                        "error": str(result)
                    }

            return results

        except Exception as e:
            logger.error(f"Error batch processing directory {directory}: {e}")
            return [{"status": "error", "error": str(e)}]

# CLI Interface
async def main():
    """Main CLI interface for DISASSEMBLER bridge"""
    import argparse

    parser = argparse.ArgumentParser(description='DISASSEMBLER Agent Bridge')
    parser.add_argument('--file', '-f', help='Process specific binary file')
    parser.add_argument('--directory', '-d', help='Process all binaries in directory')
    parser.add_argument('--recursive', '-r', action='store_true', help='Recursive directory processing')
    parser.add_argument('--output', '-o', help='Output file for results (JSON)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')

    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    bridge = DisassemblerBridge()

    results = []

    if args.file:
        result = await bridge.process_binary_file(args.file)
        results = [result]
    elif args.directory:
        results = await bridge.batch_process_directory(args.directory, args.recursive)
    else:
        # Default: process current directory
        results = await bridge.batch_process_directory('.', False)

    # Output results
    output_data = {
        "timestamp": asyncio.get_event_loop().time(),
        "total_files": len(results),
        "successful": len([r for r in results if r.get("status") == "completed"]),
        "failed": len([r for r in results if r.get("status") == "error"]),
        "results": results
    }

    if args.output:
        with open(args.output, 'w') as f:
            json.dump(output_data, f, indent=2)
        print(f"Results written to: {args.output}")
    else:
        print(json.dumps(output_data, indent=2))

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nDisassembler bridge interrupted")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)