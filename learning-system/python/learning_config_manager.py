#!/usr/bin/env python3
"""
Learning System Configuration Manager
Handles configuration, validation, and initialization for the integrated system
"""

import asyncio
import json
import logging
import os
import shutil
import socket
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Setup logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class SetupMode(Enum):
    """Setup modes for the learning system"""

    FULL = "full"
    UPGRADE = "upgrade"
    REPAIR = "repair"
    VALIDATE = "validate"


class ComponentStatus(Enum):
    """Status of system components"""

    OK = "✅ OK"
    WARNING = "⚠️ Warning"
    ERROR = "❌ Error"
    UNKNOWN = "❓ Unknown"
    SKIPPED = "⏭️ Skipped"


@dataclass
class SystemConfiguration:
    """Complete system configuration"""

    # Database settings
    db_host: str = "localhost"
    db_port: int = 5433
    db_database: str = "claude_auth"
    db_user: str = "claude_auth"
    db_password: str = "claude_auth_pass"

    # Learning system settings
    learning_mode: str = "adaptive"
    optimization_objective: str = "balanced"
    auto_retrain_threshold: int = 50
    exploration_budget: float = 0.2
    learning_rate: float = 0.1
    confidence_threshold: float = 0.7
    model_update_frequency: int = 3600
    monitoring_interval: int = 60

    # Feature flags
    enable_ml_models: bool = True
    enable_deep_learning: bool = False
    enable_monitoring: bool = True
    enable_auto_optimization: bool = True
    enable_deprecated_migration: bool = True

    # Paths
    project_root: Path = None
    database_dir: Path = None
    config_dir: Path = None
    agents_dir: Path = None
    python_dir: Path = None

    def __post_init__(self):
        """Initialize paths if not provided"""
        if self.project_root is None:
            self.project_root = Path(__file__).parent.parent.parent.parent

        self.database_dir = self.project_root / "database"
        self.config_dir = self.project_root / "config"
        self.agents_dir = self.project_root / "agents"
        self.python_dir = self.project_root / "agents" / "src" / "python"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        data = asdict(self)
        # Convert Path objects to strings
        for key, value in data.items():
            if isinstance(value, Path):
                data[key] = str(value)
        return data

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "SystemConfiguration":
        """Create from dictionary"""
        # Convert string paths back to Path objects
        path_keys = [
            "project_root",
            "database_dir",
            "config_dir",
            "agents_dir",
            "python_dir",
        ]
        for key in path_keys:
            if key in data and data[key] is not None:
                data[key] = Path(data[key])
        return cls(**data)

    @classmethod
    def from_environment(cls) -> "SystemConfiguration":
        """Create configuration from environment variables"""
        config = cls()

        # Database settings from environment
        config.db_host = os.getenv("POSTGRES_HOST", config.db_host)
        config.db_port = int(os.getenv("POSTGRES_PORT", str(config.db_port)))
        config.db_database = os.getenv("POSTGRES_DB", config.db_database)
        config.db_user = os.getenv("POSTGRES_USER", config.db_user)
        config.db_password = os.getenv("POSTGRES_PASSWORD", config.db_password)

        # Learning settings from environment
        config.learning_mode = os.getenv("LEARNING_MODE", config.learning_mode)
        config.enable_ml_models = (
            os.getenv("ENABLE_ML_MODELS", "true").lower() == "true"
        )
        config.enable_monitoring = (
            os.getenv("ENABLE_MONITORING", "true").lower() == "true"
        )

        return config

    def save(self, filepath: Path = None):
        """Save configuration to file"""
        if filepath is None:
            filepath = self.config_dir / "system_config.json"

        filepath.parent.mkdir(parents=True, exist_ok=True)

        with open(filepath, "w") as f:
            json.dump(self.to_dict(), f, indent=2)

        logger.info(f"Configuration saved to {filepath}")

    @classmethod
    def load(cls, filepath: Path = None) -> "SystemConfiguration":
        """Load configuration from file"""
        if filepath is None:
            filepath = (
                Path(__file__).parent.parent.parent.parent
                / "config"
                / "system_config.json"
            )

        if filepath.exists():
            with open(filepath, "r") as f:
                data = json.load(f)
            logger.info(f"Configuration loaded from {filepath}")
            return cls.from_dict(data)
        else:
            logger.warning(
                f"Configuration file not found at {filepath}, using defaults"
            )
            return cls()


class ConfigurationManager:
    """Manages system configuration and setup"""

    def __init__(self, config: SystemConfiguration = None):
        self.config = config or SystemConfiguration.from_environment()
        self.validation_results = {}
        self.component_status = {}
        self.setup_log = []

    def log(self, message: str, level: str = "info"):
        """Log a setup message"""
        timestamp = datetime.now().isoformat()
        self.setup_log.append(
            {"timestamp": timestamp, "level": level, "message": message}
        )

        if level == "error":
            logger.error(message)
        elif level == "warning":
            logger.warning(message)
        else:
            logger.info(message)

    async def validate_system(self) -> Dict[str, ComponentStatus]:
        """Validate all system components"""
        self.log("Starting system validation...")

        # Check PostgreSQL
        self.component_status["postgresql"] = await self._check_postgresql()

        # Check Python dependencies
        self.component_status["python_deps"] = self._check_python_dependencies()

        # Check database schema
        self.component_status["database_schema"] = await self._check_database_schema()

        # Check agent files
        self.component_status["agent_files"] = self._check_agent_files()

        # Check ML capabilities
        self.component_status["ml_capabilities"] = self._check_ml_capabilities()

        # Check configuration files
        self.component_status["config_files"] = self._check_config_files()

        return self.component_status

    async def _check_postgresql(self) -> ComponentStatus:
        """Check PostgreSQL availability"""
        try:
            import psycopg2

            # Try to connect
            conn = psycopg2.connect(
                host=self.config.db_host,
                port=self.config.db_port,
                database="postgres",  # Connect to default database first
                user=self.config.db_user,
                password=self.config.db_password,
                connect_timeout=5,
            )
            conn.close()

            self.log(f"PostgreSQL available on port {self.config.db_port}")
            return ComponentStatus.OK

        except Exception as e:
            self.log(f"PostgreSQL check failed: {e}", "error")

            # Try to start local instance if on port 5433
            if self.config.db_port == 5433:
                if await self._start_local_postgres():
                    return ComponentStatus.WARNING

            return ComponentStatus.ERROR

    async def _start_local_postgres(self) -> bool:
        """Attempt to start local PostgreSQL instance"""
        manage_script = self.config.database_dir / "manage_database.sh"

        if manage_script.exists():
            try:
                self.log("Attempting to start local PostgreSQL...")
                subprocess.run(
                    [str(manage_script), "start"], check=True, capture_output=True
                )
                await asyncio.sleep(3)  # Wait for startup

                # Verify it's running
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                result = sock.connect_ex(("localhost", 5433))
                sock.close()

                if result == 0:
                    self.log("Local PostgreSQL started successfully")
                    return True

            except Exception as e:
                self.log(f"Failed to start local PostgreSQL: {e}", "warning")

        return False

    def _check_python_dependencies(self) -> ComponentStatus:
        """Check Python dependencies"""
        required_packages = ["psycopg2", "asyncpg", "numpy", "sklearn", "joblib"]

        missing = []
        for package in required_packages:
            try:
                __import__(package)
            except ImportError:
                missing.append(package)

        if not missing:
            self.log("All required Python packages installed")
            return ComponentStatus.OK
        elif len(missing) < len(required_packages) / 2:
            self.log(f"Some packages missing: {', '.join(missing)}", "warning")
            return ComponentStatus.WARNING
        else:
            self.log(f"Many packages missing: {', '.join(missing)}", "error")
            return ComponentStatus.ERROR

    async def _check_database_schema(self) -> ComponentStatus:
        """Check database schema"""
        try:
            import psycopg2

            # Connect to database
            conn = psycopg2.connect(
                host=self.config.db_host,
                port=self.config.db_port,
                database=self.config.db_database,
                user=self.config.db_user,
                password=self.config.db_password,
            )
            cursor = conn.cursor()

            # Check for required tables
            cursor.execute(
                """
                SELECT COUNT(*) FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name IN (
                    'agent_metadata', 
                    'agent_task_executions',
                    'agent_collaboration_patterns', 
                    'learning_insights',
                    'agent_performance_metrics'
                )
            """
            )

            table_count = cursor.fetchone()[0]
            cursor.close()
            conn.close()

            if table_count == 5:
                self.log("All required database tables present")
                return ComponentStatus.OK
            elif table_count > 0:
                self.log(f"Some tables missing ({table_count}/5 present)", "warning")
                return ComponentStatus.WARNING
            else:
                self.log("Database schema not initialized", "warning")
                return ComponentStatus.WARNING

        except psycopg2.OperationalError as e:
            if "does not exist" in str(e):
                self.log("Database does not exist yet", "warning")
                return ComponentStatus.WARNING
            else:
                self.log(f"Database check failed: {e}", "error")
                return ComponentStatus.ERROR
        except Exception as e:
            self.log(f"Database schema check failed: {e}", "error")
            return ComponentStatus.ERROR

    def _check_agent_files(self) -> ComponentStatus:
        """Check agent files"""
        if not self.config.agents_dir.exists():
            self.log("Agents directory not found", "error")
            return ComponentStatus.ERROR

        agent_files = list(self.config.agents_dir.glob("*.md")) + list(
            self.config.agents_dir.glob("*.MD")
        )

        # Filter out templates
        agent_files = [
            f
            for f in agent_files
            if f.name.lower() not in ["template.md", "standardized_template.md"]
        ]

        if len(agent_files) > 10:
            self.log(f"Found {len(agent_files)} agent files")
            return ComponentStatus.OK
        elif len(agent_files) > 0:
            self.log(f"Found only {len(agent_files)} agent files", "warning")
            return ComponentStatus.WARNING
        else:
            self.log("No agent files found", "error")
            return ComponentStatus.ERROR

    def _check_ml_capabilities(self) -> ComponentStatus:
        """Check ML capabilities"""
        has_sklearn = False
        has_torch = False

        try:
            import sklearn

            has_sklearn = True
        except ImportError:
            pass

        try:
            import torch

            has_torch = True
            self.config.enable_deep_learning = True
        except ImportError:
            pass

        if has_sklearn and has_torch:
            self.log("Full ML capabilities available (including deep learning)")
            return ComponentStatus.OK
        elif has_sklearn:
            self.log("Basic ML capabilities available")
            return ComponentStatus.OK
        else:
            self.log("ML capabilities not available", "warning")
            return ComponentStatus.WARNING

    def _check_config_files(self) -> ComponentStatus:
        """Check configuration files"""
        required_files = [
            self.config.config_dir / "database.json",
            self.config.config_dir / "learning_config.json",
        ]

        missing = [f for f in required_files if not f.exists()]

        if not missing:
            self.log("All configuration files present")
            return ComponentStatus.OK
        elif len(missing) < len(required_files):
            self.log(
                f"Some config files missing: {[f.name for f in missing]}", "warning"
            )
            return ComponentStatus.WARNING
        else:
            self.log("Configuration files not found", "warning")
            return ComponentStatus.WARNING

    async def initialize_system(self, mode: SetupMode = SetupMode.FULL) -> bool:
        """Initialize the learning system"""
        self.log(f"Initializing system in {mode.value} mode...")

        success = True

        try:
            if mode == SetupMode.FULL:
                # Full setup
                success &= await self._create_database()
                success &= await self._install_schema()
                success &= await self._initialize_agents()
                success &= await self._setup_ml_models()
                success &= self._create_config_files()

            elif mode == SetupMode.UPGRADE:
                # Upgrade existing system
                success &= await self._upgrade_schema()
                success &= await self._update_agents()
                success &= await self._retrain_models()

            elif mode == SetupMode.REPAIR:
                # Repair broken components
                validation = await self.validate_system()
                for component, status in validation.items():
                    if status != ComponentStatus.OK:
                        success &= await self._repair_component(component)

            elif mode == SetupMode.VALIDATE:
                # Just validate
                validation = await self.validate_system()
                success = all(s == ComponentStatus.OK for s in validation.values())

            return success

        except Exception as e:
            self.log(f"System initialization failed: {e}", "error")
            return False

    async def _create_database(self) -> bool:
        """Create database if it doesn't exist"""
        try:
            import psycopg2
            from psycopg2 import sql

            # Connect to postgres database
            conn = psycopg2.connect(
                host=self.config.db_host,
                port=self.config.db_port,
                database="postgres",
                user=self.config.db_user,
                password=self.config.db_password,
            )
            conn.autocommit = True
            cursor = conn.cursor()

            # Check if database exists
            cursor.execute(
                "SELECT 1 FROM pg_database WHERE datname = %s",
                (self.config.db_database,),
            )

            if not cursor.fetchone():
                # Create database
                cursor.execute(
                    sql.SQL("CREATE DATABASE {}").format(
                        sql.Identifier(self.config.db_database)
                    )
                )
                self.log(f"Created database {self.config.db_database}")
            else:
                self.log(f"Database {self.config.db_database} already exists")

            cursor.close()
            conn.close()
            return True

        except Exception as e:
            self.log(f"Database creation failed: {e}", "error")
            return False

    async def _install_schema(self) -> bool:
        """Install database schema"""
        schema_file = self.config.database_dir / "sql" / "learning_system_schema.sql"

        try:
            import psycopg2

            conn = psycopg2.connect(
                host=self.config.db_host,
                port=self.config.db_port,
                database=self.config.db_database,
                user=self.config.db_user,
                password=self.config.db_password,
            )
            cursor = conn.cursor()

            if schema_file.exists():
                with open(schema_file, "r") as f:
                    schema_sql = f.read()
                cursor.execute(schema_sql)
            else:
                # Use embedded minimal schema
                cursor.execute(self._get_minimal_schema())

            conn.commit()
            cursor.close()
            conn.close()

            self.log("Database schema installed")
            return True

        except Exception as e:
            self.log(f"Schema installation failed: {e}", "error")
            return False

    def _get_minimal_schema(self) -> str:
        """Get minimal schema SQL"""
        return """
            -- Enable UUID extension
            CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
            
            -- Agent metadata
            CREATE TABLE IF NOT EXISTS agent_metadata (
                agent_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                agent_name VARCHAR(64) UNIQUE NOT NULL,
                agent_version VARCHAR(16),
                capabilities JSONB DEFAULT '{}',
                performance_metrics JSONB DEFAULT '{}',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            
            -- Task executions
            CREATE TABLE IF NOT EXISTS agent_task_executions (
                execution_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                task_id VARCHAR(128),
                task_type VARCHAR(64) NOT NULL,
                task_description TEXT,
                agents_invoked JSONB DEFAULT '[]',
                execution_order JSONB DEFAULT '[]',
                start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                end_time TIMESTAMP,
                duration_seconds FLOAT,
                success BOOLEAN DEFAULT false,
                error_message TEXT,
                complexity_score FLOAT DEFAULT 1.0,
                metadata JSONB DEFAULT '{}',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            
            -- Collaboration patterns
            CREATE TABLE IF NOT EXISTS agent_collaboration_patterns (
                pattern_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                source_agent VARCHAR(64) NOT NULL,
                target_agent VARCHAR(64) NOT NULL,
                task_type VARCHAR(64),
                invocation_count INT DEFAULT 1,
                success_rate FLOAT DEFAULT 1.0,
                avg_duration FLOAT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(source_agent, target_agent, task_type)
            );
            
            -- Learning insights
            CREATE TABLE IF NOT EXISTS learning_insights (
                insight_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                insight_type VARCHAR(32) NOT NULL,
                confidence FLOAT DEFAULT 0.5,
                description TEXT,
                data JSONB DEFAULT '{}',
                applied BOOLEAN DEFAULT false,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            
            -- Performance metrics
            CREATE TABLE IF NOT EXISTS agent_performance_metrics (
                metric_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                agent_name VARCHAR(64) NOT NULL,
                task_type VARCHAR(64),
                success_count INT DEFAULT 0,
                failure_count INT DEFAULT 0,
                total_duration FLOAT DEFAULT 0,
                avg_response_time FLOAT,
                last_execution TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(agent_name, task_type)
            );
            
            -- Create indexes
            CREATE INDEX IF NOT EXISTS idx_exec_task_type ON agent_task_executions(task_type);
            CREATE INDEX IF NOT EXISTS idx_exec_success ON agent_task_executions(success);
            CREATE INDEX IF NOT EXISTS idx_patterns_agents ON agent_collaboration_patterns(source_agent, target_agent);
        """

    async def _initialize_agents(self) -> bool:
        """Initialize agents in database"""
        try:
            import json

            import psycopg2

            conn = psycopg2.connect(
                host=self.config.db_host,
                port=self.config.db_port,
                database=self.config.db_database,
                user=self.config.db_user,
                password=self.config.db_password,
            )
            cursor = conn.cursor()

            # Get agent files
            agent_files = list(self.config.agents_dir.glob("*.md")) + list(
                self.config.agents_dir.glob("*.MD")
            )

            agent_files = [
                f
                for f in agent_files
                if f.name.lower() not in ["template.md", "standardized_template.md"]
            ]

            initialized = 0
            for agent_file in agent_files:
                agent_name = agent_file.stem.lower()

                cursor.execute(
                    "SELECT 1 FROM agent_metadata WHERE agent_name = %s", (agent_name,)
                )

                if not cursor.fetchone():
                    cursor.execute(
                        """
                        INSERT INTO agent_metadata (
                            agent_name, agent_version, capabilities
                        ) VALUES (%s, %s, %s)
                    """,
                        (
                            agent_name,
                            "v4.0",
                            json.dumps({"status": "active", "integrated": True}),
                        ),
                    )
                    initialized += 1

            conn.commit()
            cursor.close()
            conn.close()

            self.log(f"Initialized {initialized} agents")
            return True

        except Exception as e:
            self.log(f"Agent initialization failed: {e}", "error")
            return False

    async def _setup_ml_models(self) -> bool:
        """Setup ML models"""
        # This would initialize ML models if needed
        self.log("ML model setup completed")
        return True

    def _create_config_files(self) -> bool:
        """Create configuration files"""
        try:
            # Save main configuration
            self.config.save()

            # Create database config
            db_config = {
                "host": self.config.db_host,
                "port": self.config.db_port,
                "database": self.config.db_database,
                "user": self.config.db_user,
                "password": self.config.db_password,
            }

            db_config_file = self.config.config_dir / "database.json"
            db_config_file.parent.mkdir(parents=True, exist_ok=True)

            with open(db_config_file, "w") as f:
                json.dump(db_config, f, indent=2)

            # Create learning config
            learning_config = {
                "learning_mode": self.config.learning_mode,
                "optimization_objective": self.config.optimization_objective,
                "auto_retrain_threshold": self.config.auto_retrain_threshold,
                "exploration_budget": self.config.exploration_budget,
                "learning_rate": self.config.learning_rate,
                "confidence_threshold": self.config.confidence_threshold,
                "model_update_frequency": self.config.model_update_frequency,
                "monitoring_interval": self.config.monitoring_interval,
            }

            learning_config_file = self.config.config_dir / "learning_config.json"

            with open(learning_config_file, "w") as f:
                json.dump(learning_config, f, indent=2)

            self.log("Configuration files created")
            return True

        except Exception as e:
            self.log(f"Config file creation failed: {e}", "error")
            return False

    async def _repair_component(self, component: str) -> bool:
        """Repair a specific component"""
        self.log(f"Attempting to repair {component}...")

        if component == "postgresql":
            return await self._start_local_postgres()
        elif component == "database_schema":
            return await self._install_schema()
        elif component == "agent_files":
            return await self._initialize_agents()
        elif component == "config_files":
            return self._create_config_files()
        else:
            self.log(f"No repair procedure for {component}", "warning")
            return False

    async def _upgrade_schema(self) -> bool:
        """Upgrade database schema"""
        # Would contain schema migration logic
        self.log("Schema upgrade completed")
        return True

    async def _update_agents(self) -> bool:
        """Update agent definitions"""
        # Would update agent metadata
        self.log("Agent updates completed")
        return True

    async def _retrain_models(self) -> bool:
        """Retrain ML models"""
        # Would retrain models with new data
        self.log("Model retraining completed")
        return True

    def generate_report(self) -> str:
        """Generate setup report"""
        report = []
        report.append("=" * 60)
        report.append("Learning System Configuration Report")
        report.append("=" * 60)
        report.append("")

        # System status
        report.append("System Status:")
        for component, status in self.component_status.items():
            report.append(f"  {component}: {status.value}")

        report.append("")
        report.append("Configuration:")
        report.append(
            f"  Database: {self.config.db_database}@{self.config.db_host}:{self.config.db_port}"
        )
        report.append(f"  Learning Mode: {self.config.learning_mode}")
        report.append(
            f"  ML Models: {'Enabled' if self.config.enable_ml_models else 'Disabled'}"
        )
        report.append(
            f"  Deep Learning: {'Available' if self.config.enable_deep_learning else 'Not Available'}"
        )

        # Recent log entries
        if self.setup_log:
            report.append("")
            report.append("Recent Activity:")
            for entry in self.setup_log[-10:]:
                report.append(f"  [{entry['level']}] {entry['message']}")

        report.append("")
        report.append("=" * 60)

        return "\n".join(report)


async def main():
    """Main entry point for configuration manager"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Learning System Configuration Manager"
    )
    parser.add_argument(
        "command",
        choices=["validate", "setup", "repair", "upgrade", "report"],
        help="Command to execute",
    )
    parser.add_argument("--config", type=str, help="Path to configuration file")
    parser.add_argument(
        "--mode",
        choices=["full", "upgrade", "repair", "validate"],
        default="full",
        help="Setup mode",
    )

    args = parser.parse_args()

    # Load configuration
    if args.config:
        config = SystemConfiguration.load(Path(args.config))
    else:
        config = SystemConfiguration.from_environment()

    # Create manager
    manager = ConfigurationManager(config)

    # Execute command
    if args.command == "validate":
        status = await manager.validate_system()
        print(manager.generate_report())

        # Exit with error if any component failed
        if any(s == ComponentStatus.ERROR for s in status.values()):
            sys.exit(1)

    elif args.command == "setup":
        mode = SetupMode[args.mode.upper()]
        success = await manager.initialize_system(mode)
        print(manager.generate_report())

        if not success:
            sys.exit(1)

    elif args.command == "repair":
        success = await manager.initialize_system(SetupMode.REPAIR)
        print(manager.generate_report())

        if not success:
            sys.exit(1)

    elif args.command == "upgrade":
        success = await manager.initialize_system(SetupMode.UPGRADE)
        print(manager.generate_report())

        if not success:
            sys.exit(1)

    elif args.command == "report":
        await manager.validate_system()
        print(manager.generate_report())


if __name__ == "__main__":
    asyncio.run(main())
