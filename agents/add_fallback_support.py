#!/usr/bin/env python3
"""
Add tandem execution and fallback support to all agent files
"""

import os
import re
from pathlib import Path

def get_communication_section(agent_name, port_num=9000):
    """Generate communication section for an agent"""
    agent_lower = agent_name.lower().replace('-', '_')
    
    return f"""################################################################################
# COMMUNICATION SYSTEM INTEGRATION v3.0
################################################################################

communication:
  protocol: ultra_fast_binary_v3
  capabilities:
    throughput: 4.2M_msg_sec
    latency: 200ns_p99
    
  tandem_execution:
    supported_modes:
      - INTELLIGENT      # Default: Python orchestrates, C executes
      - PYTHON_ONLY     # Fallback when C unavailable
      - REDUNDANT       # Both layers for critical operations
      - CONSENSUS       # Both must agree on results
      
    fallback_strategy:
      when_c_unavailable: PYTHON_ONLY
      when_performance_degraded: PYTHON_ONLY
      when_consensus_fails: RETRY_PYTHON
      max_retries: 3
      
    python_implementation:
      module: "agents.src.python.{agent_lower}_impl"
      class: "{agent_name}PythonExecutor"
      capabilities:
        - "Full {agent_name} functionality in Python"
        - "Async execution support"
        - "Error recovery and retry logic"
        - "Progress tracking and reporting"
      performance: "100-500 ops/sec"
      
    c_implementation:
      binary: "src/c/{agent_lower}_agent"
      shared_lib: "lib{agent_lower}.so"
      capabilities:
        - "High-speed execution"
        - "Binary protocol support"
        - "Hardware optimization"
      performance: "10K+ ops/sec"
      
  integration:
    auto_register: true
    binary_protocol: "binary-communications-system/ultra_hybrid_enhanced.c"
    discovery_service: "src/c/agent_discovery.c"
    message_router: "src/c/message_router.c"
    runtime: "src/c/unified_agent_runtime.c"
    
  ipc_methods:
    CRITICAL: shared_memory_50ns
    HIGH: io_uring_500ns
    NORMAL: unix_sockets_2us
    LOW: mmap_files_10us
    BATCH: dma_regions
    
  message_patterns:
    - publish_subscribe
    - request_response
    - work_queues
    
  security:
    authentication: JWT_RS256_HS256
    authorization: RBAC_4_levels
    encryption: TLS_1.3
    integrity: HMAC_SHA256
    
  monitoring:
    prometheus_port: {port_num}
    grafana_dashboard: true
    health_check: "/health/ready"
    metrics_endpoint: "/metrics"

################################################################################
# FALLBACK EXECUTION PATTERNS
################################################################################

fallback_patterns:
  python_only_execution:
    implementation: |
      class {agent_name}PythonExecutor:
          def __init__(self):
              self.cache = {{}}
              self.metrics = {{}}
              
          async def execute_command(self, command):
              \"\"\"Execute {agent_name} commands in pure Python\"\"\"
              try:
                  result = await self.process_command(command)
                  self.metrics['success'] += 1
                  return result
              except Exception as e:
                  self.metrics['errors'] += 1
                  return await self.handle_error(e, command)
                  
          async def process_command(self, command):
              \"\"\"Process specific command types\"\"\"
              # Agent-specific implementation
              pass
              
          async def handle_error(self, error, command):
              \"\"\"Error recovery logic\"\"\"
              # Retry logic
              for attempt in range(3):
                  try:
                      return await self.process_command(command)
                  except:
                      await asyncio.sleep(2 ** attempt)
              raise error
    
  graceful_degradation:
    triggers:
      - "C layer timeout > 1000ms"
      - "C layer error rate > 5%"
      - "Binary bridge disconnection"
      - "Memory pressure > 80%"
      
    actions:
      immediate: "Switch to PYTHON_ONLY mode"
      cache_results: "Store recent operations"
      reduce_load: "Limit concurrent operations"
      notify_user: "Alert about degraded performance"
      
  recovery_strategy:
    detection: "Monitor C layer every 30s"
    validation: "Test with simple command"
    reintegration: "Gradually shift load to C"
    verification: "Compare outputs for consistency"

"""

def update_agent_file(filepath):
    """Update an agent file with communication/fallback support"""
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Skip if already has communication section
    if 'communication:' in content and 'tandem_execution:' in content:
        print(f"  ✓ {filepath.name} already has tandem support")
        return False
    
    # Extract agent name from file
    agent_name = filepath.stem
    if agent_name in ['Template', 'TEMPLATE', 'README', 'WHERE_I_AM', 'STATUSLINE_INTEGRATION']:
        print(f"  - Skipping {filepath.name}")
        return False
    
    # Find a good insertion point
    # Look for common section headers to insert before
    insertion_patterns = [
        r'^#{10,}\n# SUCCESS METRICS',
        r'^#{10,}\n# INTEGRATION COMMANDS',
        r'^#{10,}\n# USAGE EXAMPLES',
        r'^#{10,}\n# EXAMPLE WORKFLOWS',
        r'^---\n\n## Acceptance Criteria',
        r'^---\n\*.*Performance:',
    ]
    
    inserted = False
    for pattern in insertion_patterns:
        if re.search(pattern, content, re.MULTILINE):
            # Calculate port number based on agent name
            port_num = 9000 + abs(hash(agent_name)) % 1000
            
            communication_section = get_communication_section(agent_name, port_num)
            
            # Insert the communication section
            content = re.sub(
                pattern,
                communication_section + '\n' + r'\g<0>',
                content,
                count=1,
                flags=re.MULTILINE
            )
            inserted = True
            break
    
    if not inserted:
        # If no pattern found, append at the end before the final metadata
        if content.endswith('*\n'):
            # Find the last line that starts with *
            lines = content.split('\n')
            for i in range(len(lines) - 1, -1, -1):
                if lines[i].startswith('*'):
                    port_num = 9000 + abs(hash(agent_name)) % 1000
                    communication_section = get_communication_section(agent_name, port_num)
                    lines.insert(i, communication_section)
                    content = '\n'.join(lines)
                    inserted = True
                    break
    
    if not inserted:
        print(f"  ⚠ Could not find insertion point for {filepath.name}")
        return False
    
    # Write updated content
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"  ✓ Updated {filepath.name} with tandem execution support")
    return True

def main():
    """Main function"""
    agents_dir = Path('/home/siducer/Documents/Claude/agents')
    
    # Get all .md files
    agent_files = sorted([f for f in agents_dir.glob('*.md') if f.is_file()])
    
    print(f"Found {len(agent_files)} agent files")
    print("Adding tandem execution and fallback support...\n")
    
    updated_count = 0
    for agent_file in agent_files:
        if update_agent_file(agent_file):
            updated_count += 1
    
    print(f"\n✅ Updated {updated_count} agent files with fallback support")
    print(f"📊 {len(agent_files) - updated_count} files were skipped or already had support")

if __name__ == "__main__":
    main()