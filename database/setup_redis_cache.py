#!/usr/bin/env python3
"""
Redis Cache Setup for Multi-Level Caching System
Integrates with existing PostgreSQL auth system and learning framework

Provides:
- Redis installation and configuration
- Cache-specific Redis instances
- Performance-optimized Redis settings
- Integration with existing auth_redis_setup.py
- Monitoring and metrics collection
"""

import asyncio
import subprocess
import sys
import os
import json
import time
from pathlib import Path
from typing import Dict, Any, Optional
import logging


# Add project root to Python path for imports
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

try:
    from path_utilities import (
        get_project_root, get_agents_dir, get_database_dir,
        get_python_src_dir, get_shadowgit_paths, get_database_config
    )
except ImportError:
    # Fallback if path_utilities not available
    def get_project_root():
        return Path(__file__).parent.parent.parent
    def get_agents_dir():
        return get_project_root() / 'agents'
    def get_database_dir():
        return get_project_root() / 'database'
    def get_python_src_dir():
        return get_agents_dir() / 'src' / 'python'
    def get_shadowgit_paths():
        home_dir = Path.home()
        return {'root': home_dir / 'shadowgit'}
    def get_database_config():
        return {
            'host': 'localhost', 'port': 5433,
            'database': 'claude_agents_auth',
            'user': 'claude_agent', 'password': 'claude_auth_pass'
        }
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('redis_cache_setup')

class RedisCacheSetup:
    """Redis cache setup and configuration manager"""
    
    def __init__(self, config_dir: str = str(get_project_root() / "config"):
        self.config_dir = Path(config_dir)
        self.redis_instances = {
            'cache': {'port': 6379, 'db': 0, 'purpose': 'L2 Cache'},
            'sessions': {'port': 6380, 'db': 0, 'purpose': 'Session Storage'},
            'metrics': {'port': 6381, 'db': 0, 'purpose': 'Metrics and Monitoring'}
        }
        
        # Redis configuration templates
        self.redis_config_template = """
# Redis Configuration for Claude Caching System
# Optimized for high-performance caching workloads

# Network
port {port}
bind 127.0.0.1 ::1
protected-mode yes
tcp-backlog 511
tcp-keepalive 300

# General
daemonize yes
pidfile /var/run/redis/redis-{instance}.pid
logfile /var/log/redis/redis-{instance}.log
loglevel notice

# Snapshotting - Disabled for cache instances (we can rebuild)
# save 900 1
# save 300 10
# save 60 10000
save ""

# Memory Management
maxmemory {maxmemory}
maxmemory-policy allkeys-lru
maxmemory-samples 5

# Lazy Freeing (Redis 4.0+)
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes

# Threaded I/O (Redis 6.0+)
io-threads 4
io-threads-do-reads yes

# Append Only File - Disabled for cache
appendonly no

# Slow Log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Client Output Buffer Limits
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

# Advanced Configuration
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100

# Active Rehashing
activerehashing yes

# Jemalloc Background Thread
jemalloc-bg-thread yes

# Performance Monitoring
latency-monitor-threshold 100
"""
    
    def check_redis_installed(self) -> bool:
        """Check if Redis is installed"""
        try:
            result = subprocess.run(['redis-server', '--version'], capture_output=True, text=True)
            if result.returncode == 0:
                version = result.stdout.strip()
                logger.info(f"Redis is installed: {version}")
                return True
        except FileNotFoundError:
            pass
        
        logger.warning("Redis is not installed")
        return False
    
    def install_redis(self) -> bool:
        """Install Redis if not present"""
        if self.check_redis_installed():
            return True
        
        logger.info("Installing Redis...")
        
        try:
            # Update package list
            subprocess.run(['sudo', 'apt', 'update'], check=True)
            
            # Install Redis
            subprocess.run(['sudo', 'apt', 'install', '-y', 'redis-server'], check=True)
            
            # Install Redis tools
            subprocess.run(['sudo', 'apt', 'install', '-y', 'redis-tools'], check=True)
            
            # Enable Redis service
            subprocess.run(['sudo', 'systemctl', 'enable', 'redis-server'], check=True)
            
            logger.info("Redis installed successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to install Redis: {e}")
            return False
    
    def create_redis_configs(self) -> bool:
        """Create optimized Redis configurations for each instance"""
        
        # Create config directory
        config_dir = Path('/etc/redis')
        config_dir.mkdir(exist_ok=True)
        
        # Create log directory
        log_dir = Path('/var/log/redis')
        subprocess.run(['sudo', 'mkdir', '-p', str(log_dir)], check=True)
        subprocess.run(['sudo', 'chown', 'redis:redis', str(log_dir)], check=True)
        
        # Create pid directory
        pid_dir = Path('/var/run/redis')
        subprocess.run(['sudo', 'mkdir', '-p', str(pid_dir)], check=True)
        subprocess.run(['sudo', 'chown', 'redis:redis', str(pid_dir)], check=True)
        
        for instance, config in self.redis_instances.items():
            # Calculate memory limit based on instance purpose
            if instance == 'cache':
                maxmemory = '2gb'  # Large cache for L2
            elif instance == 'sessions':
                maxmemory = '512mb'  # Sessions need less space
            else:  # metrics
                maxmemory = '256mb'  # Metrics are lightweight
            
            # Generate config content
            config_content = self.redis_config_template.format(
                port=config['port'],
                instance=instance,
                maxmemory=maxmemory
            )
            
            # Write config file
            config_file = config_dir / f'redis-{instance}.conf'
            try:
                with open(config_file, 'w') as f:
                    f.write(config_content)
                
                # Set proper ownership
                subprocess.run(['sudo', 'chown', 'redis:redis', str(config_file)], check=True)
                logger.info(f"Created Redis config for {instance} instance: {config_file}")
                
            except Exception as e:
                logger.error(f"Failed to create Redis config for {instance}: {e}")
                return False
        
        return True
    
    def create_systemd_services(self) -> bool:
        """Create systemd service files for Redis instances"""
        
        service_template = """[Unit]
Description=Advanced key-value store ({instance})
After=network.target
Documentation=http://redis.io/documentation, man:redis-server(1)

[Service]
Type=notify
ExecStart=/usr/bin/redis-server /etc/redis/redis-{instance}.conf
ExecStop=/bin/kill -s QUIT $MAINPID
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStopSec=0
Restart=always
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=-/var/lib/redis
ReadWritePaths=-/var/log/redis
ReadWritePaths=-/var/run/redis
CapabilityBoundingSet=CAP_SETGID CAP_SETUID CAP_SYS_RESOURCE
MemoryDenyWriteExecute=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictNamespaces=true
LockPersonality=true

# redis-server can write to its own config file when in cluster mode so we
# permit writing there by default. If you are not using this feature, it is
# recommended that you replace the following lines with "ProtectSystem=full".
ProtectSystem=true
ReadWritePaths=-/etc/redis

[Install]
WantedBy=multi-user.target
Alias=redis-{instance}.service
"""
        
        service_dir = Path('/etc/systemd/system')
        
        for instance in self.redis_instances.keys():
            service_content = service_template.format(instance=instance)
            service_file = service_dir / f'redis-{instance}.service'
            
            try:
                with open(service_file, 'w') as f:
                    f.write(service_content)
                
                logger.info(f"Created systemd service: {service_file}")
                
            except Exception as e:
                logger.error(f"Failed to create systemd service for {instance}: {e}")
                return False
        
        # Reload systemd
        subprocess.run(['sudo', 'systemctl', 'daemon-reload'], check=True)
        return True
    
    def start_redis_instances(self) -> bool:
        """Start all Redis instances"""
        
        success = True
        for instance in self.redis_instances.keys():
            try:
                service_name = f'redis-{instance}.service'
                
                # Stop default Redis if running
                if instance == 'cache':
                    try:
                        subprocess.run(['sudo', 'systemctl', 'stop', 'redis-server'], check=False)
                        subprocess.run(['sudo', 'systemctl', 'disable', 'redis-server'], check=False)
                    except:
                        pass
                
                # Start instance
                subprocess.run(['sudo', 'systemctl', 'start', service_name], check=True)
                subprocess.run(['sudo', 'systemctl', 'enable', service_name], check=True)
                
                logger.info(f"Started Redis instance: {instance}")
                
                # Wait a moment and check status
                time.sleep(2)
                result = subprocess.run(['sudo', 'systemctl', 'is-active', service_name], 
                                      capture_output=True, text=True)
                if result.stdout.strip() == 'active':
                    logger.info(f"✓ Redis {instance} is running")
                else:
                    logger.error(f"✗ Redis {instance} failed to start")
                    success = False
                
            except subprocess.CalledProcessError as e:
                logger.error(f"Failed to start Redis instance {instance}: {e}")
                success = False
        
        return success
    
    async def test_redis_connectivity(self) -> Dict[str, bool]:
        """Test connectivity to all Redis instances"""
        
        try:
            import redis.asyncio as redis
        except ImportError:
            logger.error("redis package not installed. Install with: pip install redis")
            return {}
        
        results = {}
        
        for instance, config in self.redis_instances.items():
            try:
                client = redis.Redis(
                    host='localhost',
                    port=config['port'],
                    db=config['db'],
                    decode_responses=True
                )
                
                # Test basic operations
                await client.ping()
                await client.set(f'test:{instance}', f'Hello from {instance}')
                value = await client.get(f'test:{instance}')
                await client.delete(f'test:{instance}')
                
                if value == f'Hello from {instance}':
                    results[instance] = True
                    logger.info(f"✓ Redis {instance} connectivity test passed")
                else:
                    results[instance] = False
                    logger.error(f"✗ Redis {instance} connectivity test failed")
                
                await client.close()
                
            except Exception as e:
                results[instance] = False
                logger.error(f"✗ Redis {instance} connectivity test failed: {e}")
        
        return results
    
    def create_cache_config(self) -> bool:
        """Create cache configuration file"""
        
        cache_config = {
            'redis_instances': {
                'cache': {
                    'url': f'redis://localhost:{self.redis_instances["cache"]["port"]}/0',
                    'purpose': 'L2 Cache Storage',
                    'max_connections': 50,
                    'retry_on_timeout': True,
                    'health_check_interval': 30
                },
                'sessions': {
                    'url': f'redis://localhost:{self.redis_instances["sessions"]["port"]}/0',
                    'purpose': 'Session Storage',
                    'max_connections': 20,
                    'retry_on_timeout': True,
                    'health_check_interval': 30
                },
                'metrics': {
                    'url': f'redis://localhost:{self.redis_instances["metrics"]["port"]}/0',
                    'purpose': 'Metrics and Monitoring',
                    'max_connections': 10,
                    'retry_on_timeout': True,
                    'health_check_interval': 60
                }
            },
            'cache_settings': {
                'default_ttl': 3600,
                'l2_cache_ttl': 7200,
                'session_ttl': 86400,
                'metrics_ttl': 3600,
                'key_prefix': 'claude_cache',
                'compression': True,
                'serialization': 'pickle'
            }
        }
        
        config_file = self.config_dir / 'redis_cache_config.json'
        
        try:
            self.config_dir.mkdir(parents=True, exist_ok=True)
            with open(config_file, 'w') as f:
                json.dump(cache_config, f, indent=2)
            
            logger.info(f"Created cache configuration: {config_file}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create cache configuration: {e}")
            return False
    
    def create_monitoring_scripts(self) -> bool:
        """Create Redis monitoring scripts"""
        
        monitoring_script = """#!/bin/bash
# Redis Cache Monitoring Script
# Provides health checks and performance metrics for all Redis instances

INSTANCES="cache sessions metrics"
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
NC='\\033[0m' # No Color

echo "=== Redis Cache Health Check ==="
echo "Timestamp: $(date)"
echo

for instance in $INSTANCES; do
    case $instance in
        "cache") port=6379 ;;
        "sessions") port=6380 ;;
        "metrics") port=6381 ;;
    esac
    
    echo "--- Redis $instance (port $port) ---"
    
    # Check if service is running
    if systemctl is-active --quiet redis-$instance; then
        echo -e "Service: ${GREEN}RUNNING${NC}"
    else
        echo -e "Service: ${RED}STOPPED${NC}"
        continue
    fi
    
    # Test Redis connectivity
    if redis-cli -p $port ping > /dev/null 2>&1; then
        echo -e "Connectivity: ${GREEN}OK${NC}"
        
        # Get Redis info
        info=$(redis-cli -p $port info server,memory,stats 2>/dev/null)
        
        # Extract key metrics
        version=$(echo "$info" | grep "redis_version:" | cut -d: -f2 | tr -d '\\r')
        memory=$(echo "$info" | grep "used_memory_human:" | cut -d: -f2 | tr -d '\\r')
        keys=$(redis-cli -p $port dbsize 2>/dev/null)
        connections=$(echo "$info" | grep "connected_clients:" | cut -d: -f2 | tr -d '\\r')
        
        echo "Version: $version"
        echo "Memory Used: $memory"
        echo "Keys: $keys"
        echo "Connections: $connections"
        
        # Check for slow queries
        slow_queries=$(redis-cli -p $port slowlog len 2>/dev/null)
        if [ "$slow_queries" -gt 0 ]; then
            echo -e "Slow Queries: ${YELLOW}$slow_queries${NC}"
        else
            echo "Slow Queries: 0"
        fi
        
    else
        echo -e "Connectivity: ${RED}FAILED${NC}"
    fi
    
    echo
done

echo "=== Performance Summary ==="
total_memory=$(redis-cli -p 6379 info memory 2>/dev/null | grep "used_memory_human:" | cut -d: -f2 | tr -d '\\r')
total_keys=$(($(redis-cli -p 6379 dbsize 2>/dev/null) + $(redis-cli -p 6380 dbsize 2>/dev/null) + $(redis-cli -p 6381 dbsize 2>/dev/null)))

echo "Total Memory Usage: $total_memory"
echo "Total Keys: $total_keys"
"""
        
        script_path = Path('/usr/local/bin/redis-cache-monitor')
        
        try:
            with open(script_path, 'w') as f:
                f.write(monitoring_script)
            
            # Make executable
            subprocess.run(['sudo', 'chmod', '+x', str(script_path)], check=True)
            logger.info(f"Created monitoring script: {script_path}")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to create monitoring script: {e}")
            return False
    
    async def setup_complete_redis_cache(self) -> bool:
        """Complete Redis cache setup process"""
        logger.info("Starting comprehensive Redis cache setup...")
        
        steps = [
            ("Installing Redis", self.install_redis),
            ("Creating Redis configurations", self.create_redis_configs),
            ("Creating systemd services", self.create_systemd_services),
            ("Starting Redis instances", self.start_redis_instances),
            ("Creating cache configuration", self.create_cache_config),
            ("Creating monitoring scripts", self.create_monitoring_scripts),
        ]
        
        for step_name, step_func in steps:
            logger.info(f"Step: {step_name}")
            try:
                success = step_func()
                if not success:
                    logger.error(f"Failed: {step_name}")
                    return False
                logger.info(f"✓ {step_name}")
            except Exception as e:
                logger.error(f"Error in {step_name}: {e}")
                return False
        
        # Test connectivity
        logger.info("Testing Redis connectivity...")
        connectivity_results = await self.test_redis_connectivity()
        
        all_connected = all(connectivity_results.values())
        if all_connected:
            logger.info("✅ Redis cache setup completed successfully!")
            logger.info("Available instances:")
            for instance, config in self.redis_instances.items():
                logger.info(f"  - {instance}: redis://localhost:{config['port']}/0 ({config['purpose']})")
        else:
            logger.error("❌ Some Redis instances failed connectivity tests")
            return False
        
        return True

async def main():
    """Main setup function"""
    setup = RedisCacheSetup()
    
    try:
        success = await setup.setup_complete_redis_cache()
        if success:
            print("\\n🎉 Redis cache setup completed successfully!")
            print("\\nNext steps:")
            print("1. Test the multi-level cache system:")
            print("   python3 multilevel_cache_system.py")
            print("2. Monitor Redis health:")
            print("   redis-cache-monitor")
            print("3. Integrate with your applications using the config at:")
            print(f"   {setup.config_dir}/redis_cache_config.json")
        else:
            print("\\n❌ Redis cache setup failed. Check logs for details.")
            sys.exit(1)
    
    except KeyboardInterrupt:
        print("\\nSetup interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Setup failed with exception: {e}")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())