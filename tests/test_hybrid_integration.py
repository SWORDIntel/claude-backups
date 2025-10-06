#!/usr/bin/env python3
"""
Simple Hybrid Bridge Integration Test
Tests the integration between native learning system and Docker capabilities
"""

import sys
from pathlib import Path
import pytest

# Add source path for imports, making it robust to the test execution location
sys.path.append(str(Path(__file__).resolve().parents[2] / 'agents' / 'src' / 'python'))

def test_python_environment():
    """Test Python environment has required dependencies."""
    try:
        import psycopg2
        import asyncio
        # The test passes if the imports succeed
    except ImportError as e:
        pytest.fail(f"Missing critical dependency: {e}")

def test_hybrid_bridge_manager():
    """Test hybrid bridge manager initialization and status."""
    try:
        from hybrid_bridge_manager import HybridBridgeManager
        bridge = HybridBridgeManager()
        status = bridge.get_system_status()
        assert status['bridge_manager']['status'] == 'operational', "Bridge manager is not operational"
        assert 'mode' in status['bridge_manager'], "Bridge status is missing 'mode' key"
    except Exception as e:
        pytest.fail(f"HybridBridgeManager failed to initialize or get status: {e}")

def test_learning_system_accessibility():
    """Test learning system can be imported and initialized."""
    try:
        from postgresql_learning_system import UltimatePostgreSQLLearningSystem
        system = UltimatePostgreSQLLearningSystem()
        assert system is not None, "Failed to initialize UltimatePostgreSQLLearningSystem"
    except Exception as e:
        pytest.fail(f"Learning system accessibility error: {e}")

def test_docker_compose_exists():
    """Test Docker Compose configuration file exists."""
    project_root = Path(__file__).resolve().parents[2]
    docker_compose_file = project_root / 'docker-compose.yml'
    assert docker_compose_file.exists(), "docker-compose.yml missing from project root"

def test_database_files_structure():
    """Test database directory structure."""
    project_root = Path(__file__).resolve().parents[2]
    required_dirs = [
        project_root / 'database/sql',
        project_root / 'database/docker',
        project_root / 'agents/src/python'
    ]
    
    missing = [str(p) for p in required_dirs if not p.exists() or not p.is_dir()]
    
    assert not missing, f"Missing required directories: {', '.join(missing)}"