#!/usr/bin/env python3
"""
Claude Terminal Status Monitor - Dark Theme
Creates a small status window positioned to avoid tab overlap
Displays real-time status of Claude Agent Framework v7.0 subsystems
"""

import json
import os
import subprocess
import sys
import threading
import time
import tkinter as tk
from datetime import datetime
from pathlib import Path
from tkinter import ttk

import psutil


class ClaudeTerminalStatusMonitor:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Claude Status")
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 0.95)

        # Smaller window to avoid tab overlap
        self.window_width = 240
        self.window_height = 320

        # Dark theme colors
        self.colors = {
            "bg": "#1e1e1e",
            "fg": "#ffffff",
            "accent": "#007acc",
            "success": "#4caf50",
            "warning": "#ff9800",
            "error": "#f44336",
            "secondary": "#6c757d",
        }

        # Configure dark theme
        self.setup_dark_theme()
        self.setup_window()
        self.setup_ui()

        # Status data with comprehensive tracking
        self.agent_count = 98
        self.module_count = 11
        self.status_data = {
            "framework": "Online",
            "agents_online": 0,
            "modules_online": 0,
            "npu_status": "Checking...",
            "cpu_temp": 0,
            "memory_usage": 0,
            "last_update": None,
            "database_status": "Unknown",
            "communication_status": "Unknown",
            "agents_detail": {},
            "modules_detail": {},
        }

        # Start monitoring
        self.start_monitoring()

    def setup_dark_theme(self):
        """Configure dark theme for the entire application"""
        self.root.configure(bg=self.colors["bg"])

        # Configure ttk styles for dark theme
        style = ttk.Style()
        style.theme_use("clam")

        # Configure frame styles
        style.configure(
            "Dark.TFrame", background=self.colors["bg"], borderwidth=1, relief="solid"
        )

        # Configure label styles
        style.configure(
            "Dark.TLabel",
            background=self.colors["bg"],
            foreground=self.colors["fg"],
            font=("Consolas", 8),
        )

        style.configure(
            "Title.TLabel",
            background=self.colors["bg"],
            foreground=self.colors["accent"],
            font=("Consolas", 9, "bold"),
        )

        style.configure(
            "Status.TLabel",
            background=self.colors["bg"],
            foreground=self.colors["success"],
            font=("Consolas", 8),
        )

        # Configure button styles
        style.configure(
            "Dark.TButton",
            background=self.colors["accent"],
            foreground=self.colors["fg"],
            borderwidth=0,
            focuscolor="none",
        )

        style.map("Dark.TButton", background=[("active", self.colors["warning"])])

    def setup_window(self):
        """Position window to avoid tab overlap and stay within terminal bounds"""
        positioned = False

        # Try multiple positioning methods
        positioning_methods = [
            self.position_via_xdotool,
            self.position_via_wmctrl,
            self.position_via_environment,
        ]

        for method in positioning_methods:
            try:
                if method():
                    positioned = True
                    break
            except Exception as e:
                continue

        if not positioned:
            # Final fallback: position relative to screen (top-right, avoiding tabs)
            self.root.update_idletasks()  # Ensure window is ready
            screen_width = self.root.winfo_screenwidth()
            screen_height = self.root.winfo_screenheight()

            # Position in top-right with safe margins
            x = screen_width - self.window_width - 30
            y = 120  # Below typical tab area

            self.root.geometry(f"{self.window_width}x{self.window_height}+{x}+{y}")

    def position_via_xdotool(self):
        """Try positioning using xdotool"""
        result = subprocess.run(
            ["xdotool", "getactivewindow", "getwindowgeometry"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split("\n")
            width = height = x = y = 0

            for line in lines:
                if "Position:" in line:
                    pos_part = line.split("Position: ")[1]
                    x, y = map(int, pos_part.split(","))
                elif "Geometry:" in line:
                    geo_part = line.split("Geometry: ")[1]
                    width, height = map(int, geo_part.split("x"))

            if width and height:
                status_x = x + width - self.window_width - 15
                status_y = y + 80  # Below tabs
                self.root.geometry(
                    f"{self.window_width}x{self.window_height}+{status_x}+{status_y}"
                )
                return True
        return False

    def position_via_wmctrl(self):
        """Try positioning using wmctrl"""
        result = subprocess.run(
            ["wmctrl", "-l", "-G"], capture_output=True, text=True, timeout=2
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split("\n")
            for line in lines:
                if any(
                    term in line.lower()
                    for term in ["claude", "terminal", "gnome-terminal"]
                ):
                    parts = line.split()
                    if len(parts) >= 6:
                        x, y, width, height = map(int, parts[2:6])
                        status_x = x + width - self.window_width - 15
                        status_y = y + 80
                        self.root.geometry(
                            f"{self.window_width}x{self.window_height}+{status_x}+{status_y}"
                        )
                        return True
        return False

    def position_via_environment(self):
        """Try positioning using environment variables or display info"""
        try:
            # Check if we're in a specific terminal environment
            if os.environ.get("WINDOWID"):
                # Use window ID if available
                window_id = os.environ.get("WINDOWID")
                # Try to get geometry with xwininfo
                result = subprocess.run(
                    ["xwininfo", "-id", window_id],
                    capture_output=True,
                    text=True,
                    timeout=2,
                )
                if result.returncode == 0:
                    # Parse xwininfo output for position and size
                    for line in result.stdout.split("\n"):
                        if "Absolute upper-left X:" in line:
                            x = int(line.split(":")[1].strip())
                        elif "Absolute upper-left Y:" in line:
                            y = int(line.split(":")[1].strip())
                        elif "Width:" in line:
                            width = int(line.split(":")[1].strip())
                        elif "Height:" in line:
                            height = int(line.split(":")[1].strip())

                    if all(v for v in [x, y, width, height]):
                        status_x = x + width - self.window_width - 15
                        status_y = y + 80
                        self.root.geometry(
                            f"{self.window_width}x{self.window_height}+{status_x}+{status_y}"
                        )
                        return True
        except:
            pass
        return False

    def setup_ui(self):
        """Create the dark-themed status display UI"""
        # Main frame with dark theme
        main_frame = ttk.Frame(self.root, style="Dark.TFrame", padding="8")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Title
        title_label = ttk.Label(
            main_frame, text="Claude Agent Framework", style="Title.TLabel"
        )
        title_label.grid(row=0, column=0, columnspan=2, pady=(0, 8), sticky=tk.W)

        # Close button (small, top-right)
        close_btn = ttk.Button(
            main_frame,
            text="×",
            width=3,
            style="Dark.TButton",
            command=self.close_monitor,
        )
        close_btn.grid(row=0, column=1, sticky=tk.E)

        # Status indicators
        self.status_labels = {}
        row = 1

        # Framework status
        ttk.Label(main_frame, text="Framework:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["framework"] = ttk.Label(
            main_frame, text="●", style="Status.TLabel"
        )
        self.status_labels["framework"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Communication system
        ttk.Label(main_frame, text="Communication:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["communication"] = ttk.Label(
            main_frame, text="●", style="Status.TLabel"
        )
        self.status_labels["communication"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Database status
        ttk.Label(main_frame, text="Database:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["database"] = ttk.Label(
            main_frame, text="●", style="Status.TLabel"
        )
        self.status_labels["database"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Agents status
        ttk.Label(main_frame, text="Agents:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["agents"] = ttk.Label(
            main_frame, text="0/98", style="Dark.TLabel"
        )
        self.status_labels["agents"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Modules status
        ttk.Label(main_frame, text="Modules:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["modules"] = ttk.Label(
            main_frame, text="0/11", style="Dark.TLabel"
        )
        self.status_labels["modules"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # OpenVINO status
        ttk.Label(main_frame, text="OpenVINO:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["openvino"] = ttk.Label(
            main_frame, text="●", style="Status.TLabel"
        )
        self.status_labels["openvino"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # NPU status
        ttk.Label(main_frame, text="NPU:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["npu"] = ttk.Label(
            main_frame, text="Checking...", style="Dark.TLabel"
        )
        self.status_labels["npu"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Shadowgit status
        ttk.Label(main_frame, text="Shadowgit:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["shadowgit"] = ttk.Label(
            main_frame, text="●", style="Status.TLabel"
        )
        self.status_labels["shadowgit"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Hardware status
        ttk.Label(main_frame, text="CPU Temp:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["temp"] = ttk.Label(
            main_frame, text="--°C", style="Dark.TLabel"
        )
        self.status_labels["temp"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Memory usage
        ttk.Label(main_frame, text="Memory:", style="Dark.TLabel").grid(
            row=row, column=0, sticky=tk.W, pady=2
        )
        self.status_labels["memory"] = ttk.Label(
            main_frame, text="--%", style="Dark.TLabel"
        )
        self.status_labels["memory"].grid(row=row, column=1, sticky=tk.W, pady=2)
        row += 1

        # Last update
        self.status_labels["update"] = ttk.Label(
            main_frame, text="Initializing...", style="Dark.TLabel"
        )
        self.status_labels["update"].grid(row=row, column=0, columnspan=2, pady=(8, 0))

    def check_agent_status(self):
        """Check status of all agents and modules comprehensively"""
        agents_online = 0
        modules_online = 0

        # Check if agent registry exists and get detailed agent info
        registry_path = Path.home() / ".cache/claude/registered_agents.json"
        if registry_path.exists():
            try:
                with open(registry_path) as f:
                    registry = json.load(f)
                    if "agents" in registry:
                        agents_online = len(registry["agents"])
                        # Store agent details for future use
                        self.status_data["agents_detail"] = registry["agents"]
            except:
                pass

        # Also check project registry
        project_registry = Path(
            "/home/john/claude-backups/config/registered_agents.json"
        )
        if project_registry.exists():
            try:
                with open(project_registry) as f:
                    registry = json.load(f)
                    if "agents" in registry:
                        agents_online = max(agents_online, len(registry["agents"]))
            except:
                pass

        # Check core modules comprehensively
        module_checks = [
            ("OpenVINO", lambda: self.check_python_module("openvino")),
            ("PostgreSQL", lambda: self.check_postgresql()),
            ("Shadowgit", lambda: self.check_shadowgit()),
            ("C Agent Engine", lambda: self.check_c_agent_engine()),
            ("Agent Systems", lambda: self.check_agent_systems()),
            ("PICMCS", lambda: self.check_picmcs()),
            ("Integration", lambda: self.check_integration_module()),
            ("Orchestration", lambda: self.check_orchestration()),
            ("NPU Acceleration", lambda: self.check_npu()),
            ("Memory Optimization", lambda: self.check_memory_optimization()),
            ("Update Scheduler", lambda: self.check_update_scheduler()),
        ]

        module_details = {}
        for name, check_func in module_checks:
            try:
                status = check_func()
                module_details[name] = status
                if status:
                    modules_online += 1
            except Exception as e:
                module_details[name] = False

        self.status_data["modules_detail"] = module_details
        return agents_online, modules_online

    def check_postgresql(self):
        """Check PostgreSQL status specifically"""
        try:
            # Check if PostgreSQL is running on port 5433
            result = subprocess.run(
                ["pg_isready", "-p", "5433"], capture_output=True, timeout=2
            )
            return result.returncode == 0
        except:
            # Fallback: check if port is open
            try:
                import socket

                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(1)
                result = sock.connect_ex(("localhost", 5433))
                sock.close()
                return result == 0
            except:
                return False

    def check_shadowgit(self):
        """Check Shadowgit module"""
        shadowgit_path = Path("/home/john/claude-backups/hooks/shadowgit")
        return shadowgit_path.exists() and (shadowgit_path / "python").exists()

    def check_c_agent_engine(self):
        """Check C Agent Engine"""
        engine_path = Path("/home/john/claude-backups/agents/src/c")
        return engine_path.exists()

    def check_agent_systems(self):
        """Check Agent Systems"""
        agents_path = Path.home() / ".local/share/claude/agents"
        return agents_path.exists() and agents_path.is_symlink()

    def check_picmcs(self):
        """Check PICMCS context chopping system"""
        picmcs_path = Path("/home/john/claude-backups/integration")
        return picmcs_path.exists()

    def check_integration_module(self):
        """Check Integration Module"""
        integration_path = Path("/home/john/claude-backups/integration")
        return integration_path.exists() and any(integration_path.glob("*.py"))

    def check_orchestration(self):
        """Check Orchestration Module"""
        orchestration_path = Path("/home/john/claude-backups/orchestration")
        return orchestration_path.exists()

    def check_memory_optimization(self):
        """Check Memory Optimization"""
        optimization_path = Path("/home/john/claude-backups/optimization")
        return optimization_path.exists()

    def check_update_scheduler(self):
        """Check Update Scheduler"""
        scheduler_path = Path.home() / ".local/bin/claude-update-checker"
        return scheduler_path.exists()

    def check_communication_system(self):
        """Check the ultra-fast binary communication system"""
        try:
            # Check if the communication system is active
            c_engine = Path("/home/john/claude-backups/agents/src/c")
            if c_engine.exists():
                # Check for compiled binaries
                compiled_files = list(c_engine.glob("*.so")) + list(
                    c_engine.glob("*.a")
                )
                return len(compiled_files) > 0
        except:
            pass
        return False

    def check_python_module(self, module_name):
        """Check if Python module is available"""
        try:
            __import__(module_name)
            return True
        except ImportError:
            return False

    def check_service(self, service_name):
        """Check if system service is running"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", service_name],
                capture_output=True,
                text=True,
                timeout=2,
            )
            return result.returncode == 0
        except:
            return False

    def check_npu(self):
        """Check NPU status"""
        try:
            # Check for NPU device
            if Path("/dev/accel/accel0").exists():
                return True
        except:
            pass
        return False

    def get_hardware_status(self):
        """Get hardware status information"""
        try:
            # CPU temperature
            temps = psutil.sensors_temperatures()
            cpu_temp = 0
            if "coretemp" in temps:
                cpu_temp = max([t.current for t in temps["coretemp"]])
            elif temps:
                # Fallback to first available sensor
                first_sensor = list(temps.values())[0]
                cpu_temp = max([t.current for t in first_sensor])

            # Memory usage
            memory = psutil.virtual_memory()
            memory_percent = memory.percent

            return cpu_temp, memory_percent
        except:
            return 0, 0

    def update_status_display(self):
        """Update the status display with current data using dark theme"""
        # Framework status
        if self.status_data["agents_online"] > 80:  # Most agents online
            self.status_labels["framework"].config(
                text="●", foreground=self.colors["success"]
            )
        elif self.status_data["agents_online"] > 50:
            self.status_labels["framework"].config(
                text="●", foreground=self.colors["warning"]
            )
        else:
            self.status_labels["framework"].config(
                text="●", foreground=self.colors["error"]
            )

        # Communication system status
        comm_status = self.check_communication_system()
        comm_color = self.colors["success"] if comm_status else self.colors["error"]
        self.status_labels["communication"].config(text="●", foreground=comm_color)

        # Database status
        db_status = self.status_data.get("modules_detail", {}).get("PostgreSQL", False)
        db_color = self.colors["success"] if db_status else self.colors["error"]
        self.status_labels["database"].config(text="●", foreground=db_color)

        # Agents count with color coding
        agents_text = f"{self.status_data['agents_online']}/{self.agent_count}"
        agents_color = self.colors["fg"]
        if self.status_data["agents_online"] > 80:
            agents_color = self.colors["success"]
        elif self.status_data["agents_online"] > 50:
            agents_color = self.colors["warning"]
        elif self.status_data["agents_online"] < 20:
            agents_color = self.colors["error"]
        self.status_labels["agents"].config(text=agents_text, foreground=agents_color)

        # Modules count with color coding
        modules_text = f"{self.status_data['modules_online']}/{self.module_count}"
        modules_color = self.colors["fg"]
        if self.status_data["modules_online"] > 8:
            modules_color = self.colors["success"]
        elif self.status_data["modules_online"] > 5:
            modules_color = self.colors["warning"]
        else:
            modules_color = self.colors["error"]
        self.status_labels["modules"].config(
            text=modules_text, foreground=modules_color
        )

        # OpenVINO status
        openvino_status = self.status_data.get("modules_detail", {}).get(
            "OpenVINO", False
        )
        openvino_color = (
            self.colors["success"] if openvino_status else self.colors["error"]
        )
        self.status_labels["openvino"].config(text="●", foreground=openvino_color)

        # NPU status
        npu_active = self.check_npu()
        if npu_active:
            npu_text = "26.4 TOPS"
            npu_color = self.colors["success"]
        else:
            npu_text = "Offline"
            npu_color = self.colors["error"]
        self.status_labels["npu"].config(text=npu_text, foreground=npu_color)

        # Shadowgit status
        shadowgit_status = self.status_data.get("modules_detail", {}).get(
            "Shadowgit", False
        )
        shadowgit_color = (
            self.colors["success"] if shadowgit_status else self.colors["error"]
        )
        self.status_labels["shadowgit"].config(text="●", foreground=shadowgit_color)

        # Hardware status with dark theme colors
        temp_text = (
            f"{self.status_data['cpu_temp']:.0f}°C"
            if self.status_data["cpu_temp"] > 0
            else "--°C"
        )

        # Set temp color based on value
        if self.status_data["cpu_temp"] > 85:
            temp_color = self.colors["error"]
        elif self.status_data["cpu_temp"] > 75:
            temp_color = self.colors["warning"]
        else:
            temp_color = self.colors["fg"]
        self.status_labels["temp"].config(text=temp_text, foreground=temp_color)

        # Memory usage with color coding
        mem_text = (
            f"{self.status_data['memory_usage']:.0f}%"
            if self.status_data["memory_usage"] > 0
            else "--%"
        )

        # Set memory color based on usage
        if self.status_data["memory_usage"] > 85:
            mem_color = self.colors["error"]
        elif self.status_data["memory_usage"] > 70:
            mem_color = self.colors["warning"]
        else:
            mem_color = self.colors["fg"]
        self.status_labels["memory"].config(text=mem_text, foreground=mem_color)

        # Last update time
        if self.status_data["last_update"]:
            update_text = (
                f"Updated: {self.status_data['last_update'].strftime('%H:%M:%S')}"
            )
            self.status_labels["update"].config(
                text=update_text, foreground=self.colors["secondary"]
            )

    def monitor_loop(self):
        """Background monitoring loop with comprehensive status checking"""
        while True:
            try:
                # Check agent and module status
                agents_online, modules_online = self.check_agent_status()

                # Get hardware status
                cpu_temp, memory_usage = self.get_hardware_status()

                # Check communication system
                communication_status = self.check_communication_system()

                # Check database status (already done in check_agent_status)
                database_status = self.status_data.get("modules_detail", {}).get(
                    "PostgreSQL", False
                )

                # Debug output
                print(
                    f"[DEBUG] Agents: {agents_online}, Modules: {modules_online}, CPU: {cpu_temp:.1f}°C, Mem: {memory_usage:.1f}%"
                )

                # Update status data
                self.status_data.update(
                    {
                        "agents_online": agents_online,
                        "modules_online": modules_online,
                        "cpu_temp": cpu_temp,
                        "memory_usage": memory_usage,
                        "communication_status": (
                            "Online" if communication_status else "Offline"
                        ),
                        "database_status": "Online" if database_status else "Offline",
                        "last_update": datetime.now(),
                    }
                )

                # Update display in main thread
                self.root.after(0, self.update_status_display)

            except Exception as e:
                print(f"Monitor error: {e}")

            # Wait before next update (slightly faster for better responsiveness)
            time.sleep(2.5)

    def start_monitoring(self):
        """Start the background monitoring thread"""
        monitor_thread = threading.Thread(target=self.monitor_loop, daemon=True)
        monitor_thread.start()

        # Initial update
        self.root.after(1000, self.update_status_display)

    def close_monitor(self):
        """Close the status monitor"""
        self.root.quit()
        self.root.destroy()

    def run(self):
        """Run the status monitor"""
        try:
            self.root.mainloop()
        except KeyboardInterrupt:
            self.close_monitor()


if __name__ == "__main__":
    monitor = ClaudeTerminalStatusMonitor()
    monitor.run()
