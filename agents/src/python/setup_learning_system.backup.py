#!/usr/bin/env python3
"""
PostgreSQL Learning System Setup
Configures and initializes the agent learning system with PostgreSQL 17
"""

import os
import sys
import json
import asyncio
import logging
from pathlib import Path
from typing import Dict, Optional
import subprocess

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class PostgreSQLLearningSetup:
    """Setup and configuration for PostgreSQL-based agent learning system"""
    
    def __init__(self):
        self.project_root = Path(__file__).parent.parent.parent.parent
        self.database_dir = self.project_root / "database"
        self.config_dir = self.project_root / "config"
        self.agents_dir = self.project_root / "agents"
        
        # Database configuration using self-contained claude_auth database
        self.db_config = {
            'host': os.getenv('POSTGRES_HOST', 'localhost'),
            'port': int(os.getenv('POSTGRES_PORT', 5432)),
            'database': os.getenv('POSTGRES_DB', 'claude_auth'),
            'user': os.getenv('POSTGRES_USER', 'claude_auth'),
            'password': os.getenv('POSTGRES_PASSWORD', 'claude_auth_pass')
        }
        
        self.dependencies_installed = False
        
    def install_dependencies(self) -> bool:
        """Install required Python packages for PostgreSQL"""
        packages = [
            "psycopg2-binary>=2.9.0",
            "asyncpg>=0.27.0",
            "numpy>=1.21.0",
            "scikit-learn>=1.0.0",
            "joblib>=1.0.0"
        ]
        
        logger.info("Installing PostgreSQL learning system dependencies...")
        
        # Check if we're in an externally managed environment
        pip_args = [sys.executable, "-m", "pip", "install", "-q"]
        
        # Try with --user first for safety
        try:
            subprocess.check_call(pip_args + ["--user", "psycopg2-binary"], 
                                stderr=subprocess.DEVNULL)
            user_install = True
            logger.info("Using --user installation for packages")
        except subprocess.CalledProcessError:
            # If --user fails, try with --break-system-packages as last resort
            user_install = False
            pip_args.append("--break-system-packages")
            logger.info("Note: Using system-wide installation")
        
        for package in packages:
            try:
                cmd = pip_args + (["--user"] if user_install else []) + [package]
                subprocess.check_call(cmd, stderr=subprocess.DEVNULL)
                logger.info(f"✓ Installed {package}")
            except subprocess.CalledProcessError:
                # Try to import the module to see if it's already available
                module_name = package.split('>=')[0].replace('-', '_')
                if module_name == 'psycopg2_binary':
                    module_name = 'psycopg2'
                try:
                    __import__(module_name)
                    logger.info(f"✓ {package} already available")
                except ImportError:
                    logger.warning(f"⚠ Could not install {package}, will try to continue")
        
        self.dependencies_installed = True
        return True
    
    def load_existing_config(self) -> Dict:
        """Load existing database configuration if available"""
        config_file = self.config_dir / "database_learning.json"
        if config_file.exists():
            logger.info(f"Loading existing config from {config_file}")
            with open(config_file, 'r') as f:
                existing_config = json.load(f)
                # Don't override password from file for security
                if 'password' in existing_config:
                    del existing_config['password']
                self.db_config.update(existing_config)
        return self.db_config
    
    def save_config(self):
        """Save database configuration for future use"""
        self.config_dir.mkdir(parents=True, exist_ok=True)
        config_file = self.config_dir / "database_learning.json"
        
        # Save config without password
        safe_config = {k: v for k, v in self.db_config.items() if k != 'password'}
        safe_config['password_hint'] = 'Set via POSTGRES_PASSWORD env var or use claude_auth_pass'
        
        with open(config_file, 'w') as f:
            json.dump(safe_config, f, indent=2)
        logger.info(f"Configuration saved to {config_file}")
    
    def verify_database_connection(self) -> bool:
        """Verify connection to PostgreSQL database"""
        if not self.dependencies_installed:
            if not self.install_dependencies():
                return False
        
        try:
            import psycopg2
            
            # Test connection
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Verify we're connected to the right database
            cursor.execute("SELECT current_database(), current_user, version()")
            db_name, user, version = cursor.fetchone()
            
            logger.info(f"✓ Connected to database '{db_name}' as user '{user}'")
            logger.info(f"  PostgreSQL version: {version.split(',')[0]}")
            
            cursor.close()
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"✗ Database connection failed: {e}")
            logger.info("  Please ensure PostgreSQL is running and credentials are correct")
            logger.info(f"  Current config: database={self.db_config['database']}, user={self.db_config['user']}")
            return False
    
    def install_learning_schema(self) -> bool:
        """Install the learning system schema in PostgreSQL"""
        schema_file = self.database_dir / "sql" / "learning_system_schema.sql"
        
        if not schema_file.exists():
            logger.warning(f"Schema file not found: {schema_file}")
            logger.info("Creating learning schema from embedded definition...")
            return self.create_embedded_schema()
        
        try:
            import psycopg2
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Read and execute schema
            with open(schema_file, 'r') as f:
                schema_sql = f.read()
            
            cursor.execute(schema_sql)
            conn.commit()
            
            logger.info("✓ Learning system schema installed successfully")
            cursor.close()
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"✗ Schema installation failed: {e}")
            return False
    
    def create_embedded_schema(self) -> bool:
        """Create learning schema directly (fallback if file not found)"""
        try:
            import psycopg2
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Create learning tables
            cursor.execute("""
                -- Agent metadata table
                CREATE TABLE IF NOT EXISTS agent_metadata (
                    agent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    agent_name VARCHAR(64) UNIQUE NOT NULL,
                    agent_version VARCHAR(16),
                    capabilities JSONB DEFAULT '{}',
                    performance_metrics JSONB DEFAULT '{}',
                    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                
                -- Task execution tracking
                CREATE TABLE IF NOT EXISTS agent_task_executions (
                    execution_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    task_id VARCHAR(128),
                    task_type VARCHAR(64) NOT NULL,
                    task_description TEXT,
                    agents_invoked JSONB DEFAULT '[]',
                    execution_order JSONB DEFAULT '[]',
                    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    end_time TIMESTAMP,
                    duration_seconds FLOAT,
                    success BOOLEAN NOT NULL DEFAULT false,
                    error_message TEXT,
                    complexity_score FLOAT DEFAULT 1.0,
                    user_id UUID,
                    metadata JSONB DEFAULT '{}',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                
                -- Agent collaboration patterns
                CREATE TABLE IF NOT EXISTS agent_collaboration_patterns (
                    pattern_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    source_agent VARCHAR(64) NOT NULL,
                    target_agent VARCHAR(64) NOT NULL,
                    task_type VARCHAR(64),
                    invocation_count INT DEFAULT 1,
                    success_rate FLOAT DEFAULT 1.0,
                    avg_duration FLOAT,
                    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(source_agent, target_agent, task_type)
                );
                
                -- Learning insights
                CREATE TABLE IF NOT EXISTS learning_insights (
                    insight_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    insight_type VARCHAR(32) NOT NULL,
                    confidence FLOAT DEFAULT 0.5,
                    description TEXT,
                    data JSONB DEFAULT '{}',
                    applied BOOLEAN DEFAULT false,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                
                -- Performance metrics
                CREATE TABLE IF NOT EXISTS agent_performance_metrics (
                    metric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
                
                -- Create indexes for performance
                CREATE INDEX IF NOT EXISTS idx_executions_task_type ON agent_task_executions(task_type);
                CREATE INDEX IF NOT EXISTS idx_executions_success ON agent_task_executions(success);
                CREATE INDEX IF NOT EXISTS idx_executions_created ON agent_task_executions(created_at DESC);
                CREATE INDEX IF NOT EXISTS idx_patterns_agents ON agent_collaboration_patterns(source_agent, target_agent);
                CREATE INDEX IF NOT EXISTS idx_insights_type ON learning_insights(insight_type);
                CREATE INDEX IF NOT EXISTS idx_metrics_agent ON agent_performance_metrics(agent_name);
            """)
            
            conn.commit()
            logger.info("✓ Learning schema created successfully")
            
            cursor.close()
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"✗ Failed to create embedded schema: {e}")
            return False
    
    def initialize_agents(self) -> bool:
        """Initialize agent metadata from existing agent files"""
        try:
            import psycopg2
            import json
            
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Get all agent files
            agent_files = list(self.agents_dir.glob("*.md"))
            agent_count = 0
            
            for agent_file in agent_files:
                if agent_file.name in ["Template.md", "STANDARDIZED_TEMPLATE.md"]:
                    continue
                
                agent_name = agent_file.stem.lower()
                
                # Check if agent already exists
                cursor.execute(
                    "SELECT 1 FROM agent_metadata WHERE agent_name = %s",
                    (agent_name,)
                )
                
                if not cursor.fetchone():
                    # Insert new agent with v8.0 metadata
                    cursor.execute("""
                        INSERT INTO agent_metadata (
                            agent_name, agent_version, capabilities, 
                            performance_metrics
                        ) VALUES (%s, %s, %s, %s)
                    """, (
                        agent_name,
                        'v8.0',
                        json.dumps({
                            "status": "active",
                            "tools": ["Task"],
                            "ultra_gratuitous": True
                        }),
                        json.dumps({
                            "success_rate": 1.0,
                            "avg_response_time": 0.5,
                            "collaboration_score": 1.0
                        })
                    ))
                    agent_count += 1
            
            conn.commit()
            
            # Get total count
            cursor.execute("SELECT COUNT(*) FROM agent_metadata")
            total_agents = cursor.fetchone()[0]
            
            logger.info(f"✓ Initialized {agent_count} new agents ({total_agents} total in database)")
            
            cursor.close()
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"✗ Agent initialization failed: {e}")
            return False
    
    def setup_learning_functions(self) -> bool:
        """Create PostgreSQL functions for learning analysis"""
        try:
            import psycopg2
            
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Function to calculate agent success rates
            cursor.execute("""
                CREATE OR REPLACE FUNCTION calculate_agent_success_rate(agent_name_param VARCHAR)
                RETURNS TABLE(success_rate FLOAT, total_executions INT, avg_duration FLOAT) AS $$
                BEGIN
                    RETURN QUERY
                    SELECT 
                        CASE 
                            WHEN COUNT(*) = 0 THEN 0.0
                            ELSE SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*)
                        END as success_rate,
                        COUNT(*)::INT as total_executions,
                        AVG(duration_seconds)::FLOAT as avg_duration
                    FROM agent_task_executions
                    WHERE agents_invoked @> jsonb_build_array(jsonb_build_object('name', agent_name_param));
                END;
                $$ LANGUAGE plpgsql;
            """)
            
            # Function to get collaboration patterns
            cursor.execute("""
                CREATE OR REPLACE FUNCTION get_top_collaborations(limit_count INT DEFAULT 10)
                RETURNS TABLE(
                    source VARCHAR, 
                    target VARCHAR, 
                    task_type VARCHAR,
                    invocations INT, 
                    success_rate FLOAT
                ) AS $$
                BEGIN
                    RETURN QUERY
                    SELECT 
                        source_agent::VARCHAR,
                        target_agent::VARCHAR,
                        agent_collaboration_patterns.task_type::VARCHAR,
                        invocation_count,
                        agent_collaboration_patterns.success_rate
                    FROM agent_collaboration_patterns
                    ORDER BY invocation_count DESC, success_rate DESC
                    LIMIT limit_count;
                END;
                $$ LANGUAGE plpgsql;
            """)
            
            conn.commit()
            logger.info("✓ Learning functions created successfully")
            
            cursor.close()
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"✗ Failed to create learning functions: {e}")
            return False
    
    def test_learning_system(self) -> bool:
        """Test the learning system with sample data"""
        try:
            import psycopg2
            import json
            from datetime import datetime, timedelta
            import random
            
            conn = psycopg2.connect(**self.db_config)
            cursor = conn.cursor()
            
            # Insert sample execution
            sample_agents = ["director", "architect", "constructor", "testbed"]
            task_types = ["web_development", "security_audit", "bug_fix", "deployment"]
            
            logger.info("Inserting sample learning data...")
            
            for i in range(5):
                task_type = random.choice(task_types)
                agents = random.sample(sample_agents, k=random.randint(2, 4))
                success = random.random() > 0.3
                duration = random.uniform(0.5, 5.0)
                
                cursor.execute("""
                    INSERT INTO agent_task_executions (
                        task_id, task_type, task_description,
                        agents_invoked, execution_order,
                        duration_seconds, success, complexity_score
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    f"test_{i}",
                    task_type,
                    f"Test {task_type} task #{i}",
                    json.dumps([{"name": agent, "version": "v8.0"} for agent in agents]),
                    json.dumps(agents),
                    duration,
                    success,
                    random.uniform(1.0, 3.0)
                ))
            
            conn.commit()
            
            # Test retrieval
            cursor.execute("""
                SELECT COUNT(*), AVG(duration_seconds), 
                       SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*) as success_rate
                FROM agent_task_executions
                WHERE task_id LIKE 'test_%'
            """)
            
            count, avg_duration, success_rate = cursor.fetchone()
            logger.info(f"✓ Test data: {count} executions, {avg_duration:.2f}s avg, {success_rate:.1%} success")
            
            cursor.close()
            conn.close()
            return True
            
        except Exception as e:
            logger.error(f"✗ Learning system test failed: {e}")
            return False
    
    async def test_async_connection(self):
        """Test async connection for high-performance operations"""
        if not self.dependencies_installed:
            if not self.install_dependencies():
                return False
        
        try:
            import asyncpg
            
            # Create connection string
            conn_str = f"postgresql://{self.db_config['user']}:{self.db_config['password']}@{self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}"
            
            conn = await asyncpg.connect(conn_str)
            version = await conn.fetchval('SELECT version()')
            logger.info(f"✓ Async connection successful")
            logger.info(f"  {version.split(',')[0]}")
            await conn.close()
            return True
            
        except Exception as e:
            logger.error(f"✗ Async connection test failed: {e}")
            logger.info("  This is optional - sync operations will still work")
            return False
    
    def create_launcher_script(self):
        """Create a convenient launcher script"""
        launcher_content = """#!/bin/bash
# PostgreSQL Agent Learning System Launcher

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Set database credentials
export POSTGRES_DB=claude_auth
export POSTGRES_USER=claude_auth
export POSTGRES_PASSWORD=claude_auth_pass

case "$1" in
    "setup")
        echo "Setting up PostgreSQL learning system..."
        python3 setup_learning_system.py
        ;;
    "status")
        python3 -c "
from postgresql_learning_system import PostgreSQLLearningSystem
import asyncio

async def show_status():
    system = PostgreSQLLearningSystem()
    await system.connect()
    summary = await system.get_summary()
    print('Learning System Status:')
    print(f'  Total Executions: {summary.get(\"total_executions\", 0)}')
    print(f'  Success Rate: {summary.get(\"success_rate\", 0):.1%}')
    print(f'  Total Agents: {summary.get(\"total_agents\", 0)}')
    await system.close()

asyncio.run(show_status())
"
        ;;
    "test")
        echo "Testing learning system..."
        python3 -c "
from setup_learning_system import PostgreSQLLearningSetup
setup = PostgreSQLLearningSetup()
setup.test_learning_system()
"
        ;;
    "cli")
        shift
        python3 learning_cli.py "$@"
        ;;
    *)
        echo "PostgreSQL Agent Learning System"
        echo ""
        echo "Usage: $0 {setup|status|test|cli}"
        echo ""
        echo "Commands:"
        echo "  setup   - Install and configure the learning system"
        echo "  status  - Show current learning system status"
        echo "  test    - Run learning system tests"
        echo "  cli     - Access the learning CLI"
        echo ""
        echo "Examples:"
        echo "  $0 setup"
        echo "  $0 status"
        echo "  $0 cli dashboard"
        echo "  $0 cli simulate web_development 10"
        ;;
esac
"""
        
        launcher_path = Path("postgresql-learning")
        with open(launcher_path, 'w') as f:
            f.write(launcher_content)
        
        os.chmod(launcher_path, 0o755)
        logger.info(f"✓ Created launcher script: {launcher_path}")
    
    def run_setup(self):
        """Run complete setup process"""
        logger.info("=" * 60)
        logger.info("PostgreSQL Agent Learning System Setup")
        logger.info("=" * 60)
        
        # Load any existing configuration
        self.load_existing_config()
        
        logger.info(f"Database: {self.db_config['database']} @ {self.db_config['host']}:{self.db_config['port']}")
        logger.info(f"User: {self.db_config['user']}")
        
        # Step 1: Install dependencies
        if not self.install_dependencies():
            logger.error("Failed to install dependencies")
            return False
        
        # Step 2: Verify database connection
        if not self.verify_database_connection():
            logger.error("Failed to connect to database")
            logger.info("\nPlease ensure PostgreSQL is running and the claude_auth database exists:")
            logger.info("  sudo -u postgres psql -c \"CREATE USER claude_auth WITH PASSWORD 'claude_auth_pass';\"")
            logger.info("  sudo -u postgres psql -c \"CREATE DATABASE claude_auth OWNER claude_auth;\"")
            return False
        
        # Step 3: Install learning schema
        if not self.install_learning_schema():
            logger.error("Failed to install learning schema")
            return False
        
        # Step 4: Create learning functions
        if not self.setup_learning_functions():
            logger.error("Failed to create learning functions")
            return False
        
        # Step 5: Initialize agents
        if not self.initialize_agents():
            logger.error("Failed to initialize agents")
            return False
        
        # Step 6: Test learning system
        if not self.test_learning_system():
            logger.warning("Learning system test had issues, but setup can continue")
        
        # Step 7: Test async connection
        loop = asyncio.get_event_loop()
        if not loop.run_until_complete(self.test_async_connection()):
            logger.info("  Async connection optional - sync operations will work")
        
        # Step 8: Create launcher script
        self.create_launcher_script()
        
        # Save configuration
        self.save_config()
        
        logger.info("=" * 60)
        logger.info("✅ PostgreSQL Agent Learning System Setup Complete!")
        logger.info("=" * 60)
        logger.info("\nThe learning system is now tracking agent collaborations in PostgreSQL")
        logger.info("\nQuick Start:")
        logger.info("  ./postgresql-learning status    # Check system status")
        logger.info("  ./postgresql-learning test      # Run tests")
        logger.info("  ./postgresql-learning cli dashboard  # View dashboard")
        logger.info("\nThe system will:")
        logger.info("  • Track all agent task executions")
        logger.info("  • Learn optimal agent combinations")
        logger.info("  • Generate insights for orchestration")
        logger.info("  • Store everything in PostgreSQL for persistence")
        
        return True


def main():
    """Main entry point"""
    setup = PostgreSQLLearningSetup()
    
    # Allow command-line database override
    if len(sys.argv) > 1:
        if sys.argv[1] in ['--help', '-h']:
            print("PostgreSQL Learning System Setup")
            print("\nUsage: python3 setup_learning_system.py [database_name]")
            print("\nDefault uses claude_auth database with claude_auth user")
            sys.exit(0)
        else:
            setup.db_config['database'] = sys.argv[1]
    
    success = setup.run_setup()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()