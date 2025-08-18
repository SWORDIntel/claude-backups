#!/bin/bash
#
# Fix Critical Architecture Flaw: Remove Hardcoded Binary Communication Paths
# 
# This script fixes the critical flaw where all .md agent files contain
# hardcoded absolute paths to binary communication components, making
# the agents non-portable and breaking proper software architecture.
#

set -euo pipefail

AGENTS_DIR="/home/ubuntu/Documents/Claude/agents"
BACKUP_DIR="/home/ubuntu/Documents/Claude/agents/backup-hardcoded-paths-$(date +%Y%m%d-%H%M%S)"

echo "=== Fixing Critical Architecture Flaw: Hardcoded Binary Communication Paths ==="
echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup all agent .md files before modification
echo "Backing up all agent .md files..."
cp "$AGENTS_DIR"/*.md "$BACKUP_DIR/"

# Count how many files have the issue
AFFECTED_FILES=$(grep -l "binary_protocol.*home.*ubuntu" "$AGENTS_DIR"/*.md | wc -l)
echo "Found $AFFECTED_FILES agent files with hardcoded paths"

# Create the proper communication section template
cat > /tmp/communication_section.txt << 'EOF'
################################################################################
# COMMUNICATION SYSTEM INTEGRATION v3.0
################################################################################

communication:
  protocol: ultra_fast_binary_v3
  capabilities:
    throughput: 4.2M_msg_sec
    latency: 200ns_p99
    
  integration:
    auto_register: true
    binary_protocol: "${CLAUDE_AGENTS_ROOT}/binary-communications-system/ultra_hybrid_enhanced.c"
    discovery_service: "${CLAUDE_AGENTS_ROOT}/src/c/agent_discovery.c"
    message_router: "${CLAUDE_AGENTS_ROOT}/src/c/message_router.c"
    runtime: "${CLAUDE_AGENTS_ROOT}/src/c/unified_agent_runtime.c"
    
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
    - broadcast
    - multicast
    
  security:
    authentication: JWT_RS256_HS256
    authorization: RBAC_4_levels
    encryption: TLS_1.3
    integrity: HMAC_SHA256
    
  monitoring:
    prometheus_port: 8001
    grafana_dashboard: true
    health_check: "/health/ready"
    metrics_endpoint: "/metrics"
    
  auto_integration_code: |
    # Python integration
    from auto_integrate import integrate_with_claude_agent_system
    agent = integrate_with_claude_agent_system("AGENT_NAME_PLACEHOLDER")
    
    # C integration
    #include "ultra_fast_protocol.h"
    ufp_context_t* ctx = ufp_create_context("AGENT_NAME_PLACEHOLDER");
EOF

echo "Processing agent files..."

# Process each agent .md file
for agent_file in "$AGENTS_DIR"/*.md; do
    if [[ "$agent_file" == */Template.md ]]; then
        echo "Skipping Template.md (already fixed)"
        continue
    fi
    
    filename=$(basename "$agent_file")
    agent_name=$(echo "$filename" | sed 's/\.md$//' | tr '[:upper:]' '[:lower:]')
    
    echo "Processing: $filename"
    
    # Check if file has hardcoded paths
    if grep -q "binary_protocol.*home.*ubuntu" "$agent_file"; then
        echo "  - Found hardcoded paths, fixing..."
        
        # Create temporary file
        temp_file=$(mktemp)
        
        # Copy content up to communication section
        sed '/^################################################################################$/,/^# COMMUNICATION SYSTEM INTEGRATION/d' "$agent_file" | \
        sed '/^communication:$/,$d' > "$temp_file"
        
        # Add the fixed communication section
        sed "s/AGENT_NAME_PLACEHOLDER/$agent_name/g" /tmp/communication_section.txt >> "$temp_file"
        
        # Add any content after the communication section (if any)
        # Look for hardware section or any section that comes after communication
        if grep -n "^hardware:" "$agent_file" > /dev/null; then
            echo "" >> "$temp_file"
            sed -n '/^hardware:/,$p' "$agent_file" >> "$temp_file"
        elif grep -n "^################################################################################" "$agent_file" | tail -1 | cut -d: -f1 | xargs -I {} sed -n '{},$p' "$agent_file" | grep -v "^# COMMUNICATION SYSTEM INTEGRATION" | grep -v "^################################################################################$" > /dev/null; then
            # Find the next section after communication
            echo "" >> "$temp_file"
            awk '/^hardware:/ || /^success_metrics:/ || /^operational_directives:/ || /^---$/ {found=1} found {print}' "$agent_file" >> "$temp_file"
        fi
        
        # Replace the original file
        mv "$temp_file" "$agent_file"
        echo "  - Fixed: $filename"
    else
        echo "  - No hardcoded paths found in: $filename"
    fi
done

# Clean up
rm -f /tmp/communication_section.txt

echo ""
echo "=== Fix Complete ==="
echo "Backup directory: $BACKUP_DIR"
echo "Fixed $AFFECTED_FILES agent files"
echo ""
echo "All agent .md files now use environment-relative paths:"
echo "  \${CLAUDE_AGENTS_ROOT}/binary-communications-system/ultra_hybrid_enhanced.c"
echo "  \${CLAUDE_AGENTS_ROOT}/src/c/agent_discovery.c"
echo "  \${CLAUDE_AGENTS_ROOT}/src/c/message_router.c"
echo "  \${CLAUDE_AGENTS_ROOT}/src/c/unified_agent_runtime.c"
echo ""
echo "This fixes the critical architecture flaw and makes the agents portable."