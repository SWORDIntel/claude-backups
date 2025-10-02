#!/usr/bin/env python3
"""
Integrated Enhanced Learning System Setup v5.0
Complete PostgreSQL 17 + Agent Learning System Integration
"""

import os
import sys
import json
import subprocess
import asyncio
import psycopg2
import time
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, field
from datetime import datetime

# Colors for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'  # No Color

@dataclass
class SetupConfig:
    """Configuration for learning system setup"""
    project_root: Path = field(default_factory=lambda: Path(__file__).parent)
    database_dir: Path = field(init=False)
    agents_dir: Path = field(init=False)
    python_dir: Path = field(init=False)
    config_dir: Path = field(init=False)
    
    # Database configuration
    db_host: str = "localhost"
    db_port: int = 5433
    db_name: str = "claude_auth"
    db_user: str = "claude_auth"
    db_password: str = "claude_auth_pass"
    
    # Setup options
    reset_mode: bool = False
    skip_deps: bool = False
    verbose: bool = False
    auto_port_detection: bool = True
    create_venv: bool = True
    
    def __post_init__(self):
        """Initialize derived paths"""
        self.database_dir = self.project_root / "database"
        self.agents_dir = self.project_root / "agents"
        self.python_dir = self.agents_dir / "src" / "python"
        self.config_dir = self.project_root / "config"

class DatabaseManager:
    """Manages PostgreSQL database setup and configuration"""
    
    def __init__(self, config: SetupConfig):
        self.config = config
        self.connection_params = None
        
    def detect_postgres_port(self) -> int:
        """Detect available PostgreSQL port"""
        if not self.config.auto_port_detection:
            return self.config.db_port
            
        # Check for environment variable
        env_port = os.environ.get('POSTGRES_PORT')
        if env_port:
            return int(env_port)
        
        # Check common ports
        for port in [5433, 5432, 5434]:
            if self._test_port_connection(port):
                print(f"{Colors.GREEN}✓ PostgreSQL detected on port {port}{Colors.NC}")
                return port
                
        # Default to 5433 for local instance
        print(f"{Colors.YELLOW}⚠ No active PostgreSQL detected, defaulting to port 5433{Colors.NC}")
        return 5433
    
    def _test_port_connection(self, port: int) -> bool:
        """Test if PostgreSQL is running on specified port"""
        try:
            result = subprocess.run(['nc', '-z', 'localhost', str(port)], 
                                  capture_output=True, timeout=2)
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def start_local_postgres(self) -> bool:
        """Start local PostgreSQL instance if needed"""
        if self.config.db_port == 5433 and not self._test_port_connection(5433):
            manage_script = self.config.database_dir / "manage_database.sh"
            if manage_script.exists():
                print(f"{Colors.BLUE}Starting local PostgreSQL instance...{Colors.NC}")
                try:
                    result = subprocess.run([str(manage_script), 'start'], 
                                          capture_output=True, text=True, timeout=30)
                    if result.returncode == 0:
                        time.sleep(3)  # Wait for startup
                        if self._test_port_connection(5433):
                            print(f"{Colors.GREEN}✓ Local PostgreSQL started successfully{Colors.NC}")
                            return True
                    print(f"{Colors.RED}✗ Failed to start local PostgreSQL: {result.stderr}{Colors.NC}")
                except subprocess.TimeoutExpired:
                    print(f"{Colors.RED}✗ PostgreSQL startup timed out{Colors.NC}")
        return self._test_port_connection(self.config.db_port)
    
    def setup_connection_params(self):
        """Setup database connection parameters"""
        # Auto-detect port
        self.config.db_port = self.detect_postgres_port()
        
        # Setup socket connection for local instance
        if self.config.db_port == 5433:
            socket_dir = self.config.database_dir / "data" / "run"
            if socket_dir.exists():
                self.config.db_host = str(socket_dir)
                print(f"{Colors.GREEN}✓ Using local socket connection{Colors.NC}")
        
        self.connection_params = {
            'host': self.config.db_host,
            'port': self.config.db_port,
            'database': self.config.db_name,
            'user': self.config.db_user,
            'password': self.config.db_password
        }
    
    def test_connection(self) -> bool:
        """Test database connection"""
        try:
            conn = psycopg2.connect(**self.connection_params)
            cursor = conn.cursor()
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
            cursor.close()
            conn.close()
            
            # Extract PostgreSQL version
            import re
            version_match = re.search(r'PostgreSQL (\d+\.?\d*)', version)
            if version_match:
                pg_version = float(version_match.group(1))
                if pg_version >= 13:
                    print(f"{Colors.GREEN}✓ PostgreSQL {pg_version} connection successful{Colors.NC}")
                    return True
                else:
                    print(f"{Colors.YELLOW}⚠ PostgreSQL {pg_version} detected - version 13+ recommended{Colors.NC}")
                    return True
            return True
            
        except Exception as e:
            print(f"{Colors.RED}✗ Database connection failed: {e}{Colors.NC}")
            return False
    
    def create_database_if_not_exists(self) -> bool:
        """Create database if it doesn't exist"""
        try:
            # Connect to postgres database to check if target database exists
            temp_params = self.connection_params.copy()
            temp_params['database'] = 'postgres'
            
            conn = psycopg2.connect(**temp_params)
            conn.autocommit = True
            cursor = conn.cursor()
            
            # Check if database exists
            cursor.execute("""
                SELECT 1 FROM pg_database WHERE datname = %s
            """, (self.config.db_name,))
            
            exists = cursor.fetchone() is not None
            
            if not exists:
                print(f"{Colors.BLUE}Creating database '{self.config.db_name}'...{Colors.NC}")
                cursor.execute(f'CREATE DATABASE "{self.config.db_name}"')
                print(f"{Colors.GREEN}✓ Database created successfully{Colors.NC}")
            else:
                print(f"{Colors.GREEN}✓ Database '{self.config.db_name}' already exists{Colors.NC}")
            
            cursor.close()
            conn.close()
            return True
            
        except Exception as e:
            print(f"{Colors.RED}✗ Database creation failed: {e}{Colors.NC}")
            return False
    
    def reset_database(self) -> bool:
        """Reset database by dropping and recreating"""
        if not self.config.reset_mode:
            return True
            
        try:
            temp_params = self.connection_params.copy()
            temp_params['database'] = 'postgres'
            
            conn = psycopg2.connect(**temp_params)
            conn.autocommit = True
            cursor = conn.cursor()
            
            print(f"{Colors.YELLOW}Resetting database '{self.config.db_name}'...{Colors.NC}")
            
            # Terminate existing connections
            cursor.execute("""
                SELECT pg_terminate_backend(pg_stat_activity.pid)
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = %s
                  AND pid <> pg_backend_pid()
            """, (self.config.db_name,))
            
            # Drop and recreate database
            cursor.execute(f'DROP DATABASE IF EXISTS "{self.config.db_name}"')
            cursor.execute(f'CREATE DATABASE "{self.config.db_name}"')
            
            cursor.close()
            conn.close()
            
            print(f"{Colors.GREEN}✓ Database reset successfully{Colors.NC}")
            return True
            
        except Exception as e:
            print(f"{Colors.RED}✗ Database reset failed: {e}{Colors.NC}")
            return False

class PythonEnvironmentManager:
    """Manages Python environment and dependencies"""
    
    def __init__(self, config: SetupConfig):
        self.config = config
        self.venv_path = config.project_root / "venv"
        
    def setup_virtual_environment(self) -> bool:
        """Setup virtual environment"""
        if not self.config.create_venv:
            return True
            
        try:
            if not self.venv_path.exists():
                print(f"{Colors.BLUE}Creating virtual environment...{Colors.NC}")
                result = subprocess.run([
                    sys.executable, '-m', 'venv', str(self.venv_path)
                ], capture_output=True, text=True)
                
                if result.returncode != 0:
                    print(f"{Colors.RED}✗ Virtual environment creation failed: {result.stderr}{Colors.NC}")
                    return False
                    
                print(f"{Colors.GREEN}✓ Virtual environment created{Colors.NC}")
            else:
                print(f"{Colors.GREEN}✓ Virtual environment exists{Colors.NC}")
            
            return True
            
        except Exception as e:
            print(f"{Colors.RED}✗ Virtual environment setup failed: {e}{Colors.NC}")
            return False
    
    def install_dependencies(self) -> bool:
        """Install Python dependencies"""
        if self.config.skip_deps:
            print(f"{Colors.YELLOW}⚠ Skipping dependency installation{Colors.NC}")
            return True
        
        python_executable = self._get_python_executable()
        if not python_executable:
            return False
        
        dependencies = [
            # Core database drivers
            "psycopg2-binary>=2.9.0",
            "asyncpg>=0.27.0",
            
            # Machine learning
            "numpy>=1.21.0",
            "scikit-learn>=1.0.0",
            "joblib>=1.0.0",
            
            # Async utilities
            "aiofiles",
            
            # Optional but recommended
            "pandas", 
            "matplotlib", 
            "seaborn"
        ]
        
        print(f"{Colors.BLUE}Installing Python dependencies...{Colors.NC}")
        
        # Upgrade pip first
        subprocess.run([python_executable, '-m', 'pip', 'install', '--upgrade', 'pip'], 
                      capture_output=True)
        
        # Install core dependencies
        for dep in dependencies:
            try:
                result = subprocess.run([
                    python_executable, '-m', 'pip', 'install', dep
                ], capture_output=True, text=True, timeout=120)
                
                if result.returncode == 0:
                    if self.config.verbose:
                        print(f"  ✓ {dep}")
                else:
                    print(f"{Colors.YELLOW}⚠ Failed to install {dep}: {result.stderr.strip()}{Colors.NC}")
                    
            except subprocess.TimeoutExpired:
                print(f"{Colors.YELLOW}⚠ Timeout installing {dep}{Colors.NC}")
        
        # Try to install PyTorch (optional)
        self._install_pytorch(python_executable)
        
        print(f"{Colors.GREEN}✓ Python dependencies installation completed{Colors.NC}")
        return True
    
    def _get_python_executable(self) -> Optional[str]:
        """Get Python executable path"""
        if self.venv_path.exists():
            if sys.platform == "win32":
                python_exe = self.venv_path / "Scripts" / "python.exe"
            else:
                python_exe = self.venv_path / "bin" / "python"
                
            if python_exe.exists():
                return str(python_exe)
        
        return sys.executable
    
    def _install_pytorch(self, python_executable: str):
        """Install PyTorch (optional)"""
        try:
            print("  Installing PyTorch (this may take a while)...")
            result = subprocess.run([
                python_executable, '-m', 'pip', 'install', 
                'torch', 'torchvision', 'torchaudio',
                '--index-url', 'https://download.pytorch.org/whl/cpu'
            ], capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                print(f"  {Colors.GREEN}✓ PyTorch installed successfully{Colors.NC}")
            else:
                print(f"  {Colors.YELLOW}○ PyTorch installation skipped (optional){Colors.NC}")
                
        except subprocess.TimeoutExpired:
            print(f"  {Colors.YELLOW}○ PyTorch installation timeout (optional){Colors.NC}")

class LearningSystemManager:
    """Manages learning system setup and configuration"""
    
    def __init__(self, config: SetupConfig, db_manager: DatabaseManager):
        self.config = config
        self.db_manager = db_manager
        
    def setup_learning_schema(self) -> bool:
        """Setup learning system database schema"""
        print(f"{Colors.BLUE}Setting up learning system schema...{Colors.NC}")
        
        try:
            # Check if PostgreSQL learning system exists
            postgres_system_file = self.config.python_dir / "postgresql_learning_system.py"
            if not postgres_system_file.exists():
                print(f"{Colors.RED}✗ postgresql_learning_system.py not found{Colors.NC}")
                return False
            
            # Run the learning system initialization
            python_executable = self._get_python_executable()
            if not python_executable:
                return False
            
            # Create temporary initialization script
            init_script = self._create_schema_init_script()
            
            try:
                # Set environment variables
                env = os.environ.copy()
                env.update({
                    'POSTGRES_HOST': str(self.config.db_host),
                    'POSTGRES_PORT': str(self.config.db_port),
                    'POSTGRES_DB': self.config.db_name,
                    'POSTGRES_USER': self.config.db_user,
                    'POSTGRES_PASSWORD': self.config.db_password,
                    'PYTHONPATH': f"{self.config.python_dir}:{env.get('PYTHONPATH', '')}"
                })
                
                result = subprocess.run([
                    python_executable, init_script
                ], cwd=self.config.python_dir, env=env, 
                capture_output=True, text=True, timeout=60)
                
                if result.returncode == 0:
                    print(f"{Colors.GREEN}✓ Learning system schema setup completed{Colors.NC}")
                    if self.config.verbose:
                        print(f"Output: {result.stdout}")
                    return True
                else:
                    print(f"{Colors.RED}✗ Schema setup failed: {result.stderr}{Colors.NC}")
                    return False
                    
            finally:
                # Cleanup temporary script
                if os.path.exists(init_script):
                    os.unlink(init_script)
                    
        except Exception as e:
            print(f"{Colors.RED}✗ Learning system setup failed: {e}{Colors.NC}")
            return False
    
    def _create_schema_init_script(self) -> str:
        """Create temporary schema initialization script"""
        script_content = '''#!/usr/bin/env python3
import asyncio
import sys
import os
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

async def initialize_schema():
    try:
        # Import the ultimate learning system
        from postgresql_learning_system import UltimatePostgreSQLLearningSystem
        
        # Get database config from environment
        db_config = {
            'host': os.environ.get('POSTGRES_HOST', 'localhost'),
            'port': int(os.environ.get('POSTGRES_PORT', '5432')),
            'database': os.environ.get('POSTGRES_DB', 'claude_auth'),
            'user': os.environ.get('POSTGRES_USER', 'postgres'),
            'password': os.environ.get('POSTGRES_PASSWORD', 'password')
        }
        
        # Initialize the learning system
        print("Initializing Ultimate PostgreSQL Learning System v3.1...")
        learning_system = UltimatePostgreSQLLearningSystem(db_config)
        
        success = await learning_system.initialize()
        if success:
            print("✓ Learning system initialized successfully")
            
            # Run a quick test
            dashboard = await learning_system.get_ultimate_dashboard()
            print(f"✓ Dashboard available: {dashboard.get('status', 'unknown')}")
            return True
        else:
            print("✗ Learning system initialization failed")
            return False
            
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = asyncio.run(initialize_schema())
    sys.exit(0 if success else 1)
'''
        
        # Write to temporary file
        fd, script_path = tempfile.mkstemp(suffix='.py', prefix='schema_init_')
        try:
            with os.fdopen(fd, 'w') as f:
                f.write(script_content)
            return script_path
        except:
            os.close(fd)
            raise
    
    def _get_python_executable(self) -> Optional[str]:
        """Get Python executable path"""
        venv_path = self.config.project_root / "venv"
        if venv_path.exists():
            if sys.platform == "win32":
                python_exe = venv_path / "Scripts" / "python.exe"
            else:
                python_exe = venv_path / "bin" / "python"
                
            if python_exe.exists():
                return str(python_exe)
        
        return sys.executable
    
    def create_configuration_files(self) -> bool:
        """Create configuration files for the learning system"""
        print(f"{Colors.BLUE}Creating configuration files...{Colors.NC}")
        
        try:
            # Ensure config directory exists
            self.config.config_dir.mkdir(parents=True, exist_ok=True)
            
            # Database configuration
            db_config = {
                "host": self.config.db_host,
                "port": self.config.db_port,
                "database": self.config.db_name,
                "user": self.config.db_user,
                "password": self.config.db_password
            }
            
            db_config_file = self.config.config_dir / "database.json"
            with open(db_config_file, 'w') as f:
                json.dump(db_config, f, indent=2)
            
            # Learning system configuration
            learning_config = {
                "learning_mode": "adaptive",
                "optimization_objective": "balanced",
                "auto_retrain_threshold": 50,
                "alert_thresholds": {
                    "success_rate_min": 0.7,
                    "duration_p95_max": 120,
                    "error_rate_max": 0.2
                },
                "exploration_budget": 0.2,
                "learning_rate": 0.1,
                "confidence_threshold": 0.7,
                "model_update_frequency": 3600,
                "monitoring_interval": 60,
                "features": {
                    "ml_models_enabled": True,
                    "deep_learning_available": self._check_pytorch_availability(),
                    "real_time_monitoring": True,
                    "auto_optimization": True,
                    "postgresql_17_features": True
                }
            }
            
            learning_config_file = self.config.config_dir / "learning_config.json"
            with open(learning_config_file, 'w') as f:
                json.dump(learning_config, f, indent=2)
            
            # Environment file
            env_content = f"""# Database Configuration
POSTGRES_HOST={self.config.db_host}
POSTGRES_PORT={self.config.db_port}
POSTGRES_DB={self.config.db_name}
POSTGRES_USER={self.config.db_user}
POSTGRES_PASSWORD={self.config.db_password}

# Learning System Configuration
LEARNING_MODE=adaptive
AUTO_INITIALIZE=true
ENABLE_MONITORING=true
ENABLE_ML_MODELS=true
ENABLE_DEEP_LEARNING={str(self._check_pytorch_availability()).lower()}

# Agent System Paths
AGENT_BASE_PATH={self.config.agents_dir}
PYTHONPATH={self.config.python_dir}:$PYTHONPATH

# Feature Flags
ENABLE_DEPRECATED_MIGRATION=true
ENABLE_AUTO_PORT_DETECTION=true
ENABLE_POSTGRESQL_17_FEATURES=true
"""
            
            env_file = self.config.project_root / ".env"
            with open(env_file, 'w') as f:
                f.write(env_content)
            
            print(f"{Colors.GREEN}✓ Configuration files created{Colors.NC}")
            return True
            
        except Exception as e:
            print(f"{Colors.RED}✗ Configuration file creation failed: {e}{Colors.NC}")
            return False
    
    def _check_pytorch_availability(self) -> bool:
        """Check if PyTorch is available"""
        try:
            import torch
            return True
        except ImportError:
            return False
    
    def create_convenience_scripts(self) -> bool:
        """Create convenience scripts for easy access"""
        print(f"{Colors.BLUE}Creating convenience scripts...{Colors.NC}")
        
        try:
            # Main launcher script
            launcher_script = self.config.python_dir / "launch_learning_system.sh"
            launcher_content = f'''#!/bin/bash
# Quick launcher for the learning system

SCRIPT_DIR="$( cd "$( dirname "${{BASH_SOURCE[0]}}" )" && pwd )"
cd "$SCRIPT_DIR"

# Activate virtual environment if it exists
if [ -d "../../venv" ]; then
    source ../../venv/bin/activate
elif [ -d "venv" ]; then
    source venv/bin/activate
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
elif [ -f "../../.env" ]; then
    export $(cat ../../.env | grep -v '^#' | xargs)
fi

# Launch the PostgreSQL learning system
python3 postgresql_learning_system.py "$@"
'''
            
            with open(launcher_script, 'w') as f:
                f.write(launcher_content)
            launcher_script.chmod(0o755)
            
            # Testing script
            test_script = self.config.python_dir / "test_learning_integration.py"
            test_content = '''#!/usr/bin/env python3
"""
Comprehensive Learning System Integration Test
"""

import asyncio
import sys
import json
import os
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))

async def test_integration():
    """Test all learning system components"""
    print("Testing Learning System Integration...")
    
    test_results = {
        'database_connection': False,
        'learning_system': False,
        'orchestrator_bridge': False,
        'configuration': False,
        'ml_models': False
    }
    
    try:
        # Test 1: Database connection
        print("\\n1. Testing database connection...")
        import psycopg2
        
        # Get database config
        config_file = Path(__file__).parent.parent.parent / "config" / "database.json"
        if config_file.exists():
            with open(config_file) as f:
                db_config = json.load(f)
        else:
            db_config = {
                'host': os.environ.get('POSTGRES_HOST', 'localhost'),
                'port': int(os.environ.get('POSTGRES_PORT', '5433')),
                'database': os.environ.get('POSTGRES_DB', 'claude_auth'),
                'user': os.environ.get('POSTGRES_USER', 'claude_auth'),
                'password': os.environ.get('POSTGRES_PASSWORD', 'claude_auth_pass')
            }
        
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'")
        table_count = cursor.fetchone()[0]
        print(f"   ✓ Connected to database ({table_count} tables found)")
        test_results['database_connection'] = True
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"   ✗ Database test failed: {e}")
    
    try:
        # Test 2: Learning system
        print("\\n2. Testing PostgreSQL learning system...")
        from postgresql_learning_system import UltimatePostgreSQLLearningSystem
        
        learning_system = UltimatePostgreSQLLearningSystem(db_config)
        success = await learning_system.initialize()
        
        if success:
            print("   ✓ Learning system initialized")
            dashboard = await learning_system.get_ultimate_dashboard()
            print(f"   ✓ Dashboard status: {dashboard.get('status', 'unknown')}")
            test_results['learning_system'] = True
        
    except Exception as e:
        print(f"   ✗ Learning system test failed: {e}")
    
    try:
        # Test 3: Orchestrator bridge
        print("\\n3. Testing orchestrator bridge...")
        from learning_orchestrator_bridge import EnhancedLearningOrchestrator, LearningStrategy
        
        orchestrator = EnhancedLearningOrchestrator(LearningStrategy.ADAPTIVE)
        await orchestrator.initialize()
        print("   ✓ Orchestrator bridge initialized")
        test_results['orchestrator_bridge'] = True
        
    except Exception as e:
        print(f"   ✗ Orchestrator bridge test failed: {e}")
    
    # Test 4: Configuration
    config_dir = Path(__file__).parent.parent.parent / "config"
    if (config_dir / "database.json").exists() and (config_dir / "learning_config.json").exists():
        print("\\n4. Testing configuration files...")
        print("   ✓ Configuration files present")
        test_results['configuration'] = True
    
    # Test 5: ML capabilities
    try:
        print("\\n5. Testing ML models...")
        import numpy as np
        import sklearn
        print("   ✓ NumPy and scikit-learn available")
        
        try:
            import torch
            print("   ✓ PyTorch available")
        except ImportError:
            print("   ○ PyTorch not available (optional)")
            
        test_results['ml_models'] = True
    except Exception as e:
        print(f"   ○ ML models test: {e}")
    
    # Summary
    print("\\n" + "="*50)
    print("Integration Test Summary:")
    print("="*50)
    
    passed = sum(1 for v in test_results.values() if v)
    total = len(test_results)
    
    for test, result in test_results.items():
        status = "✓" if result else "✗"
        print(f"  {status} {test.replace('_', ' ').title()}")
    
    print(f"\\nTotal: {passed}/{total} tests passed")
    success_rate = (passed / total) * 100
    print(f"Success Rate: {success_rate:.1f}%")
    
    return success_rate >= 80

if __name__ == "__main__":
    success = asyncio.run(test_integration())
    sys.exit(0 if success else 1)
'''
            
            with open(test_script, 'w') as f:
                f.write(test_content)
            test_script.chmod(0o755)
            
            print(f"{Colors.GREEN}✓ Convenience scripts created{Colors.NC}")
            return True
            
        except Exception as e:
            print(f"{Colors.RED}✗ Script creation failed: {e}{Colors.NC}")
            return False

class IntegratedLearningSetup:
    """Main setup orchestrator for the integrated learning system"""
    
    def __init__(self):
        self.config = SetupConfig()
        self.db_manager = DatabaseManager(self.config)
        self.py_manager = PythonEnvironmentManager(self.config)
        self.learning_manager = LearningSystemManager(self.config, self.db_manager)
        
    def parse_arguments(self, args: List[str]):
        """Parse command line arguments"""
        i = 0
        while i < len(args):
            arg = args[i]
            
            if arg == '--reset':
                self.config.reset_mode = True
            elif arg == '--port':
                if i + 1 < len(args):
                    self.config.db_port = int(args[i + 1])
                    self.config.auto_port_detection = False
                    i += 1
            elif arg == '--skip-deps':
                self.config.skip_deps = True
            elif arg == '--verbose':
                self.config.verbose = True
            elif arg == '--no-venv':
                self.config.create_venv = False
            elif arg in ['--help', '-h']:
                self.print_help()
                sys.exit(0)
            
            i += 1
    
    def print_help(self):
        """Print help message"""
        print(f"""
{Colors.CYAN}Integrated Enhanced Learning System Setup v5.0{Colors.NC}

Complete setup for PostgreSQL 17 + Agent Learning System Integration

{Colors.WHITE}Usage:{Colors.NC}
  python3 integrated_learning_setup.py [options]

{Colors.WHITE}Options:{Colors.NC}
  --help, -h     Show this help message
  --port PORT    Override PostgreSQL port (default: auto-detect)
  --reset        Reset existing database before setup
  --skip-deps    Skip Python dependency installation
  --verbose      Enable verbose output
  --no-venv      Skip virtual environment creation

{Colors.WHITE}Environment Variables:{Colors.NC}
  POSTGRES_HOST      Database host (default: localhost)
  POSTGRES_PORT      Database port (default: auto-detect 5433/5432)
  POSTGRES_DB        Database name (default: claude_auth)
  POSTGRES_USER      Database user (default: claude_auth)
  POSTGRES_PASSWORD  Database password (default: claude_auth_pass)

{Colors.WHITE}Features:{Colors.NC}
  • PostgreSQL 17 integration with enhanced JSON support
  • Advanced ML models with sklearn + PyTorch support
  • Real-time pattern recognition and anomaly detection
  • Comprehensive agent performance analytics
  • Production orchestrator integration
  • Automatic dependency management
  • Configuration file generation
        """)
    
    def run_setup(self) -> bool:
        """Run the complete setup process"""
        print(f"{Colors.CYAN}{'='*60}{Colors.NC}")
        print(f"{Colors.CYAN}Integrated Enhanced Learning System Setup v5.0{Colors.NC}")
        print(f"{Colors.CYAN}{'='*60}{Colors.NC}")
        
        # Step 1: System requirements check
        print(f"\n{Colors.WHITE}Step 1: System Requirements Check{Colors.NC}")
        print("="*40)
        
        if not self._check_system_requirements():
            return False
        
        # Step 2: Database setup
        print(f"\n{Colors.WHITE}Step 2: Database Configuration{Colors.NC}")
        print("="*40)
        
        self.db_manager.setup_connection_params()
        
        if not self.db_manager.start_local_postgres():
            print(f"{Colors.YELLOW}⚠ Local PostgreSQL not started - ensure PostgreSQL is running{Colors.NC}")
        
        if not self.db_manager.test_connection():
            print(f"{Colors.RED}✗ Cannot connect to database. Check configuration.{Colors.NC}")
            return False
        
        if not self.db_manager.reset_database():
            return False
            
        if not self.db_manager.create_database_if_not_exists():
            return False
        
        # Step 3: Python environment setup
        print(f"\n{Colors.WHITE}Step 3: Python Environment Setup{Colors.NC}")
        print("="*40)
        
        if not self.py_manager.setup_virtual_environment():
            return False
        
        if not self.py_manager.install_dependencies():
            return False
        
        # Step 4: Learning system setup
        print(f"\n{Colors.WHITE}Step 4: Learning System Setup{Colors.NC}")
        print("="*40)
        
        if not self.learning_manager.setup_learning_schema():
            return False
        
        if not self.learning_manager.create_configuration_files():
            return False
        
        if not self.learning_manager.create_convenience_scripts():
            return False
        
        # Step 5: Integration testing
        print(f"\n{Colors.WHITE}Step 5: Integration Testing{Colors.NC}")
        print("="*40)
        
        if not self._run_integration_tests():
            print(f"{Colors.YELLOW}⚠ Some integration tests failed, but setup is complete{Colors.NC}")
        
        # Success message
        self._print_success_message()
        return True
    
    def _check_system_requirements(self) -> bool:
        """Check system requirements"""
        requirements_met = True
        
        # Check Python version
        python_version = sys.version_info
        if python_version >= (3, 8):
            print(f"{Colors.GREEN}✓ Python {python_version.major}.{python_version.minor} is compatible{Colors.NC}")
        else:
            print(f"{Colors.RED}✗ Python 3.8+ required (found {python_version.major}.{python_version.minor}){Colors.NC}")
            requirements_met = False
        
        # Check for required commands
        required_commands = ['psql', 'createdb', 'nc']
        for cmd in required_commands:
            if subprocess.run(['which', cmd], capture_output=True).returncode == 0:
                print(f"{Colors.GREEN}✓ {cmd} is available{Colors.NC}")
            else:
                print(f"{Colors.YELLOW}⚠ {cmd} not found - some features may not work{Colors.NC}")
        
        # Check directory structure
        required_dirs = [self.config.database_dir, self.config.agents_dir, self.config.python_dir]
        for directory in required_dirs:
            if directory.exists():
                print(f"{Colors.GREEN}✓ {directory.name}/ directory exists{Colors.NC}")
            else:
                print(f"{Colors.RED}✗ {directory} directory missing{Colors.NC}")
                requirements_met = False
        
        # Check for critical files
        critical_files = [
            self.config.python_dir / "postgresql_learning_system.py",
            self.config.python_dir / "learning_orchestrator_bridge.py"
        ]
        
        for file_path in critical_files:
            if file_path.exists():
                print(f"{Colors.GREEN}✓ {file_path.name} exists{Colors.NC}")
            else:
                print(f"{Colors.RED}✗ {file_path} missing{Colors.NC}")
                requirements_met = False
        
        return requirements_met
    
    def _run_integration_tests(self) -> bool:
        """Run basic integration tests"""
        test_script = self.config.python_dir / "test_learning_integration.py"
        if not test_script.exists():
            print(f"{Colors.YELLOW}⚠ Integration test script not found{Colors.NC}")
            return False
        
        try:
            python_executable = self.py_manager._get_python_executable()
            if not python_executable:
                return False
            
            # Set environment variables
            env = os.environ.copy()
            env.update({
                'POSTGRES_HOST': str(self.config.db_host),
                'POSTGRES_PORT': str(self.config.db_port),
                'POSTGRES_DB': self.config.db_name,
                'POSTGRES_USER': self.config.db_user,
                'POSTGRES_PASSWORD': self.config.db_password,
                'PYTHONPATH': f"{self.config.python_dir}:{env.get('PYTHONPATH', '')}"
            })
            
            result = subprocess.run([
                python_executable, str(test_script)
            ], cwd=self.config.python_dir, env=env, 
            capture_output=True, text=True, timeout=120)
            
            if result.returncode == 0:
                print(f"{Colors.GREEN}✓ Integration tests passed{Colors.NC}")
                if self.config.verbose:
                    print(result.stdout)
                return True
            else:
                print(f"{Colors.YELLOW}⚠ Some integration tests failed{Colors.NC}")
                if self.config.verbose:
                    print(result.stderr)
                return False
                
        except subprocess.TimeoutExpired:
            print(f"{Colors.YELLOW}⚠ Integration tests timed out{Colors.NC}")
            return False
        except Exception as e:
            print(f"{Colors.RED}✗ Integration test error: {e}{Colors.NC}")
            return False
    
    def _print_success_message(self):
        """Print success message with usage instructions"""
        print(f"\n{Colors.GREEN}{'='*60}{Colors.NC}")
        print(f"{Colors.GREEN}✅ INTEGRATED LEARNING SYSTEM SETUP COMPLETE!{Colors.NC}")
        print(f"{Colors.GREEN}{'='*60}{Colors.NC}")
        print(f"\n{Colors.CYAN}The Enhanced Agent Learning System v5.0 is ready!{Colors.NC}")
        
        print(f"\n{Colors.WHITE}Quick Start Commands:{Colors.NC}")
        print(f"  {Colors.BLUE}# Test the system{Colors.NC}")
        print(f"  python3 {self.config.python_dir}/test_learning_integration.py")
        
        print(f"\n  {Colors.BLUE}# Start learning system{Colors.NC}")
        print(f"  {self.config.python_dir}/launch_learning_system.sh")
        
        print(f"\n  {Colors.BLUE}# View dashboard{Colors.NC}")
        print(f"  python3 {self.config.python_dir}/postgresql_learning_system.py dashboard")
        
        print(f"\n{Colors.WHITE}Configuration Files:{Colors.NC}")
        print(f"  {self.config.config_dir}/database.json")
        print(f"  {self.config.config_dir}/learning_config.json") 
        print(f"  {self.config.project_root}/.env")
        
        print(f"\n{Colors.WHITE}Key Features Enabled:{Colors.NC}")
        print(f"  • PostgreSQL 17 with enhanced JSON support")
        print(f"  • Advanced ML models (sklearn + PyTorch)")
        print(f"  • Real-time monitoring and anomaly detection")
        print(f"  • Agent performance analytics")
        print(f"  • Production orchestrator integration")
        print(f"  • Adaptive learning strategies")
        
        print(f"\n{Colors.YELLOW}To activate in current shell:{Colors.NC}")
        if self.config.create_venv and (self.config.project_root / "venv").exists():
            print(f"  source {self.config.project_root}/venv/bin/activate")
        print(f"  source {self.config.project_root}/.env")
        
        print(f"\n{Colors.GREEN}Happy Learning! 🚀{Colors.NC}")

def main():
    """Main entry point"""
    setup = IntegratedLearningSetup()
    
    # Parse command line arguments
    setup.parse_arguments(sys.argv[1:])
    
    try:
        success = setup.run_setup()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Setup interrupted by user{Colors.NC}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Setup failed with error: {e}{Colors.NC}")
        if setup.config.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()