#!/usr/bin/env python3
"""
Claude Code Terminal Detector
Specifically detects and positions status window relative to Claude Code terminal
"""

import re
import subprocess
import time
from pathlib import Path


class ClaudeCodeTerminalDetector:
    def __init__(self):
        self.claude_terminal_info = None

    def find_claude_code_terminal(self):
        """Find the active Claude Code terminal window"""
        try:
            # Method 1: Find window by title containing "claude"
            result = subprocess.run(
                ["wmctrl", "-l"], capture_output=True, text=True, timeout=5
            )

            if result.returncode == 0:
                windows = result.stdout.strip().split("\n")
                for window in windows:
                    if any(term in window.lower() for term in ["claude", "anthropic"]):
                        # Extract window ID
                        window_id = window.split()[0]
                        return self.get_window_geometry(window_id)
        except:
            pass

        # Method 2: Get active window (assuming it's the Claude terminal)
        try:
            result = subprocess.run(
                ["xdotool", "getactivewindow"],
                capture_output=True,
                text=True,
                timeout=2,
            )

            if result.returncode == 0:
                window_id = result.stdout.strip()
                return self.get_window_geometry(window_id)
        except:
            pass

        return None

    def get_window_geometry(self, window_id):
        """Get geometry information for a specific window"""
        try:
            result = subprocess.run(
                ["xdotool", "getwindowgeometry", window_id],
                capture_output=True,
                text=True,
                timeout=2,
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split("\n")
                geometry = {}

                for line in lines:
                    if "Position:" in line:
                        pos_match = re.search(r"Position: (\d+),(\d+)", line)
                        if pos_match:
                            geometry["x"] = int(pos_match.group(1))
                            geometry["y"] = int(pos_match.group(2))
                    elif "Geometry:" in line:
                        geo_match = re.search(r"Geometry: (\d+)x(\d+)", line)
                        if geo_match:
                            geometry["width"] = int(geo_match.group(1))
                            geometry["height"] = int(geo_match.group(2))

                return geometry if len(geometry) == 4 else None
        except:
            pass

        return None

    def calculate_status_position(
        self, terminal_geometry, status_width=280, status_height=200
    ):
        """Calculate optimal position for status window in terminal's top-right"""
        if not terminal_geometry:
            return None

        # Position in top-right corner with some padding
        status_x = (
            terminal_geometry["x"] + terminal_geometry["width"] - status_width - 20
        )
        status_y = terminal_geometry["y"] + 30  # Below title bar

        return {
            "x": status_x,
            "y": status_y,
            "width": status_width,
            "height": status_height,
        }

    def get_optimal_status_position(self):
        """Get the optimal position for the status window"""
        terminal_geo = self.find_claude_code_terminal()
        return self.calculate_status_position(terminal_geo)


if __name__ == "__main__":
    detector = ClaudeCodeTerminalDetector()
    position = detector.get_optimal_status_position()
    if position:
        print(
            f"Optimal position: {position['width']}x{position['height']}+{position['x']}+{position['y']}"
        )
    else:
        print("Could not detect Claude Code terminal")
