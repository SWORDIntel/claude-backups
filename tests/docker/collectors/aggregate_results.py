#!/usr/bin/env python3
"""
Test Result Collector and Aggregator for Claude Hook System
Collects test results from all environments and generates comprehensive reports
"""

import json
import logging
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

import pandas as pd

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class TestResultCollector:
    """Collects and aggregates test results from multiple environments"""

    def __init__(self, data_dir: str = "/data", output_dir: str = "/app/results"):
        self.data_dir = Path(data_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)

        # Initialize results database
        self.db_path = self.output_dir / "test_results.db"
        self.init_database()

        self.results = {}

    def init_database(self):
        """Initialize SQLite database for test results"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS test_results (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    environment TEXT NOT NULL,
                    test_type TEXT NOT NULL,
                    test_name TEXT NOT NULL,
                    status TEXT NOT NULL,
                    duration_ms REAL,
                    response_time_ms REAL,
                    memory_usage_mb REAL,
                    cpu_usage_percent REAL,
                    cache_hit_ratio REAL,
                    error_message TEXT,
                    metadata TEXT
                )
            """
            )

            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS performance_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    environment TEXT NOT NULL,
                    metric_name TEXT NOT NULL,
                    metric_value REAL,
                    unit TEXT,
                    metadata TEXT
                )
            """
            )

            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS security_findings (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    finding_type TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    description TEXT,
                    input_data TEXT,
                    mitigation_applied BOOLEAN,
                    metadata TEXT
                )
            """
            )

    def collect_all_results(self):
        """Collect results from all test environments"""
        logger.info("Starting test result collection...")

        environments = [
            "python39",
            "python310",
            "python311",
            "python312",
            "security",
            "performance",
            "coordination",
        ]

        for env in environments:
            env_path = self.data_dir / env
            if env_path.exists():
                logger.info(f"Collecting results from {env} environment...")
                self.collect_environment_results(env, env_path)
            else:
                logger.warning(f"Environment {env} data not found at {env_path}")

        # Generate aggregate reports
        self.generate_reports()

    def collect_environment_results(self, env_name: str, env_path: Path):
        """Collect results from a specific environment"""
        self.results[env_name] = {
            "pytest_results": self.collect_pytest_results(env_path),
            "performance_metrics": self.collect_performance_metrics(env_path),
            "security_findings": self.collect_security_findings(env_path),
            "logs": self.collect_logs(env_path),
        }

    def collect_pytest_results(self, env_path: Path) -> Dict[str, Any]:
        """Collect pytest results from JSON report"""
        results = {"tests": [], "summary": {}}

        # Look for pytest JSON reports
        for json_file in env_path.glob("**/*.json"):
            if "pytest" in json_file.name or "test" in json_file.name:
                try:
                    with open(json_file, "r") as f:
                        data = json.load(f)

                    if "tests" in data:
                        results["tests"].extend(data["tests"])
                    if "summary" in data:
                        results["summary"] = data["summary"]

                except Exception as e:
                    logger.error(f"Error reading {json_file}: {e}")

        return results

    def collect_performance_metrics(self, env_path: Path) -> Dict[str, Any]:
        """Collect performance metrics"""
        metrics = {"benchmarks": [], "load_tests": [], "profiles": []}

        # Collect benchmark results
        benchmark_file = env_path / "benchmark.json"
        if benchmark_file.exists():
            try:
                with open(benchmark_file, "r") as f:
                    metrics["benchmarks"] = json.load(f)
            except Exception as e:
                logger.error(f"Error reading benchmark results: {e}")

        # Collect load test results
        for load_file in env_path.glob("**/*load_test*.json"):
            try:
                with open(load_file, "r") as f:
                    metrics["load_tests"].append(json.load(f))
            except Exception as e:
                logger.error(f"Error reading {load_file}: {e}")

        return metrics

    def collect_security_findings(self, env_path: Path) -> Dict[str, Any]:
        """Collect security test findings"""
        findings = {"vulnerabilities": [], "security_metrics": {}}

        for security_file in env_path.glob("**/*security*.json"):
            try:
                with open(security_file, "r") as f:
                    data = json.load(f)
                if "vulnerabilities" in data:
                    findings["vulnerabilities"].extend(data["vulnerabilities"])
                if "metrics" in data:
                    findings["security_metrics"].update(data["metrics"])
            except Exception as e:
                logger.error(f"Error reading {security_file}: {e}")

        return findings

    def collect_logs(self, env_path: Path) -> List[str]:
        """Collect log files"""
        logs = []
        for log_file in env_path.glob("**/*.log"):
            try:
                with open(log_file, "r") as f:
                    logs.append({"file": str(log_file), "content": f.read()})
            except Exception as e:
                logger.error(f"Error reading log {log_file}: {e}")

        return logs

    def generate_reports(self):
        """Generate comprehensive test reports"""
        logger.info("Generating test reports...")

        # Generate summary report
        self.generate_summary_report()

        # Generate compatibility report
        self.generate_compatibility_report()

        # Generate performance report
        self.generate_performance_report()

        # Generate security report
        self.generate_security_report()

        # Generate HTML dashboard
        self.generate_html_dashboard()

    def generate_summary_report(self):
        """Generate overall summary report"""
        summary = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "environments_tested": len(self.results),
            "total_tests": 0,
            "passed_tests": 0,
            "failed_tests": 0,
            "performance_improvements": {},
            "security_status": "UNKNOWN",
            "recommendations": [],
        }

        # Aggregate test results
        for env, results in self.results.items():
            pytest_results = results.get("pytest_results", {})
            if "summary" in pytest_results:
                summary["total_tests"] += pytest_results["summary"].get("total", 0)
                summary["passed_tests"] += pytest_results["summary"].get("passed", 0)
                summary["failed_tests"] += pytest_results["summary"].get("failed", 0)

        # Calculate success rate
        if summary["total_tests"] > 0:
            success_rate = summary["passed_tests"] / summary["total_tests"]
            summary["success_rate"] = success_rate

            if success_rate >= 0.95:
                summary["overall_status"] = "EXCELLENT"
            elif success_rate >= 0.90:
                summary["overall_status"] = "GOOD"
            elif success_rate >= 0.80:
                summary["overall_status"] = "ACCEPTABLE"
            else:
                summary["overall_status"] = "NEEDS_IMPROVEMENT"

        # Save summary report
        with open(self.output_dir / "summary_report.json", "w") as f:
            json.dump(summary, f, indent=2)

        logger.info(f"Summary report generated: {summary['overall_status']}")

    def generate_compatibility_report(self):
        """Generate Python version compatibility report"""
        compatibility = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "python_versions": {},
            "compatibility_matrix": {},
            "recommendations": [],
        }

        python_envs = ["python39", "python310", "python311", "python312"]

        for env in python_envs:
            if env in self.results:
                results = self.results[env]
                pytest_results = results.get("pytest_results", {})
                summary = pytest_results.get("summary", {})

                compatibility["python_versions"][env] = {
                    "total_tests": summary.get("total", 0),
                    "passed": summary.get("passed", 0),
                    "failed": summary.get("failed", 0),
                    "success_rate": summary.get("passed", 0)
                    / max(summary.get("total", 1), 1),
                }

        # Save compatibility report
        with open(self.output_dir / "compatibility_report.json", "w") as f:
            json.dump(compatibility, f, indent=2)

    def generate_performance_report(self):
        """Generate performance analysis report"""
        performance = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "baseline_metrics": {},
            "current_metrics": {},
            "improvements": {},
            "targets_met": {},
        }

        if "performance" in self.results:
            perf_data = self.results["performance"]["performance_metrics"]

            # Analyze benchmark results
            if "benchmarks" in perf_data:
                for benchmark in perf_data["benchmarks"]:
                    if "benchmarks" in benchmark:
                        for test in benchmark["benchmarks"]:
                            performance["current_metrics"][test["name"]] = {
                                "mean_time": test["stats"]["mean"],
                                "stddev": test["stats"]["stddev"],
                                "min_time": test["stats"]["min"],
                                "max_time": test["stats"]["max"],
                            }

            # Check performance targets (4-6x improvement)
            targets = {"4x_improvement": 4.0, "6x_improvement": 6.0}

            for target, factor in targets.items():
                # This would need baseline data to calculate actual improvement
                performance["targets_met"][target] = "UNKNOWN"

        # Save performance report
        with open(self.output_dir / "performance_report.json", "w") as f:
            json.dump(performance, f, indent=2)

    def generate_security_report(self):
        """Generate security analysis report"""
        security = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "fixes_validated": 0,
            "vulnerabilities_found": 0,
            "security_features_tested": [],
            "mitigation_effectiveness": {},
            "overall_security_status": "UNKNOWN",
        }

        if "security" in self.results:
            sec_data = self.results["security"]["security_findings"]

            security["vulnerabilities_found"] = len(sec_data.get("vulnerabilities", []))
            security["security_features_tested"] = list(
                sec_data.get("security_metrics", {}).keys()
            )

            # Determine overall security status
            if security["vulnerabilities_found"] == 0:
                security["overall_security_status"] = "SECURE"
            elif security["vulnerabilities_found"] <= 2:
                security["overall_security_status"] = "MOSTLY_SECURE"
            else:
                security["overall_security_status"] = "NEEDS_ATTENTION"

        # Save security report
        with open(self.output_dir / "security_report.json", "w") as f:
            json.dump(security, f, indent=2)

    def generate_html_dashboard(self):
        """Generate HTML dashboard with all results"""
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Claude Hook System Test Results</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; }}
        .section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }}
        .success {{ color: green; }}
        .warning {{ color: orange; }}
        .error {{ color: red; }}
        .metrics {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }}
        .metric {{ background: #f9f9f9; padding: 10px; border-radius: 3px; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Claude Hook System Test Results</h1>
        <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
    </div>
    
    <div class="section">
        <h2>Test Environment Summary</h2>
        <p>Environments tested: {len(self.results)}</p>
        <ul>
            {''.join(f'<li>{env}</li>' for env in self.results.keys())}
        </ul>
    </div>
    
    <div class="section">
        <h2>Overall Status</h2>
        <p>This dashboard provides a comprehensive overview of all testing results.</p>
        <p>Detailed JSON reports are available in the results directory.</p>
    </div>
</body>
</html>
        """

        with open(self.output_dir / "dashboard.html", "w") as f:
            f.write(html_content)

        logger.info("HTML dashboard generated")


def main():
    """Main collection function"""
    collector = TestResultCollector()

    try:
        collector.collect_all_results()
        logger.info("Test result collection completed successfully")

        # Print summary to stdout
        summary_file = collector.output_dir / "summary_report.json"
        if summary_file.exists():
            with open(summary_file, "r") as f:
                summary = json.load(f)
            print(f"\nTEST SUMMARY:")
            print(f"Environments: {summary['environments_tested']}")
            print(f"Total Tests: {summary['total_tests']}")
            print(f"Passed: {summary['passed_tests']}")
            print(f"Failed: {summary['failed_tests']}")
            print(f"Success Rate: {summary.get('success_rate', 0):.2%}")
            print(f"Overall Status: {summary.get('overall_status', 'UNKNOWN')}")

    except Exception as e:
        logger.error(f"Error during collection: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
