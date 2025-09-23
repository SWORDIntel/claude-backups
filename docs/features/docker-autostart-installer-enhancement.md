# Docker Container Auto-Restart Configuration Enhancement

**Date**: 2025-08-31  
**Version**: claude-installer.sh v10.0  
**Status**: ✅ PRODUCTION READY  
**Type**: Enhancement  

## Overview

Added automatic Docker container restart configuration to the Claude installer to ensure learning system containers automatically restart after system reboots on new installations.

## Problem Solved

Previously, Docker containers for the learning system (`claude-postgres`, `claude-prometheus`) were created with the default restart policy of "no", meaning they would not automatically restart after system reboots. Users had to manually start containers after each reboot.

## Solution Implemented

### New Function: `configure_docker_autostart()`

Added at **line 1895** in `claude-installer.sh`:

```bash
# Configure Docker containers for auto-restart on system reboot
configure_docker_autostart() {
    info "Configuring Docker containers for auto-restart on system reboot..."
    
    local containers=("claude-postgres" "claude-learning" "claude-bridge" "claude-prometheus")
    local docker_cmd="${DOCKER_SUDO:-}"
    
    # Check if any containers exist
    local container_found=false
    for container in "${containers[@]}"; do
        if ${docker_cmd} docker ps -a --format '{{.Names}}' | grep -q "^${container}$" 2>/dev/null; then
            container_found=true
            break
        fi
    done
    
    if [[ "$container_found" = false ]]; then
        info "No Claude containers found - restart policy will be set when containers are created"
        return 0
    fi
    
    # Update restart policy for existing containers
    local updated_count=0
    for container in "${containers[@]}"; do
        if ${docker_cmd} docker ps -a --format '{{.Names}}' | grep -q "^${container}$" 2>/dev/null; then
            info "  • Updating restart policy for $container..."
            if ${docker_cmd} docker update --restart=unless-stopped "$container" >/dev/null 2>&1; then
                ((updated_count++))
            else
                warning "    Could not update restart policy for $container (may not be running)"
            fi
        fi
    done
    
    # Verify configuration
    if [[ $updated_count -gt 0 ]]; then
        success "Updated restart policy for $updated_count containers"
        info "Verifying restart policy configuration..."
        
        for container in "${containers[@]}"; do
            if ${docker_cmd} docker ps -a --format '{{.Names}}' | grep -q "^${container}$" 2>/dev/null; then
                local policy=$(${docker_cmd} docker inspect "$container" --format='{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null || echo "unknown")
                if [[ "$policy" == "unless-stopped" ]]; then
                    success "  ✓ $container: restart policy = unless-stopped"
                else
                    warning "  ⚠ $container: restart policy = $policy (expected: unless-stopped)"
                fi
            fi
        done
    else
        info "No existing containers needed restart policy update"
    fi
    
    success "Docker auto-restart configuration complete"
    info "Containers will automatically start after system reboot"
    return 0
}
```

### Function Integration Points

1. **Line 1885** - Called in `setup_learning_system_docker()`:
```bash
success "Learning system Docker integration configured"
export LEARNING_SYSTEM_STATUS="docker_configured"
configure_docker_autostart  # <-- Added here
return 0
```

2. **Line 1978** - Called in `setup_learning_system_native()`:
```bash
# Configure auto-restart for any existing containers
configure_docker_autostart  # <-- Added here

return 0
```

## Key Features

### 1. Automatic Container Detection
- Scans for existing Claude containers
- Only processes containers that actually exist
- Gracefully handles missing containers

### 2. Containers Managed
- `claude-postgres` - PostgreSQL learning database
- `claude-learning` - Learning system engine
- `claude-bridge` - Agent bridge connector
- `claude-prometheus` - Monitoring system

### 3. Restart Policy: `unless-stopped`
This policy ensures containers:
- Start automatically when Docker daemon starts
- Restart if they crash unexpectedly
- Stay stopped only if manually stopped by user
- Resume after system reboots

### 4. Error Handling
- Handles missing Docker gracefully
- Works with or without sudo requirements
- Provides clear feedback for each operation
- Non-fatal warnings for individual container issues

### 5. Verification
- Confirms restart policy was actually applied
- Shows current policy for each container
- Reports success/warning for each container

## Benefits

1. **Zero Manual Intervention**: Learning system automatically available after reboots
2. **Continuous Data Collection**: No gaps in agent performance metrics
3. **Improved Reliability**: Containers restart if they crash
4. **User Friendly**: Clear status messages during installation
5. **Idempotent**: Safe to run multiple times without side effects

## Testing

### Manual Verification
```bash
# Check current restart policies
docker inspect claude-postgres --format='{{.HostConfig.RestartPolicy.Name}}'
docker inspect claude-prometheus --format='{{.HostConfig.RestartPolicy.Name}}'

# Test restart behavior
docker stop claude-postgres
docker start claude-postgres
docker update --restart=unless-stopped claude-postgres

# Verify after reboot
sudo systemctl restart docker
docker ps  # Should show containers running
```

### Expected Output During Installation
```
ℹ Configuring Docker containers for auto-restart on system reboot...
  • Updating restart policy for claude-postgres...
  • Updating restart policy for claude-prometheus...
✓ Updated restart policy for 2 containers
ℹ Verifying restart policy configuration...
  ✓ claude-postgres: restart policy = unless-stopped
  ✓ claude-prometheus: restart policy = unless-stopped
✓ Docker auto-restart configuration complete
ℹ Containers will automatically start after system reboot
```

## Compatibility

- **Docker versions**: All versions supporting `docker update --restart`
- **Operating Systems**: Linux, macOS with Docker Desktop
- **Container Runtime**: Docker, Docker Compose
- **Existing Installations**: Can be applied retroactively

## Migration for Existing Users

Users with existing installations can enable auto-restart manually:
```bash
# One-time command for existing containers
docker update --restart=unless-stopped claude-postgres
docker update --restart=unless-stopped claude-prometheus
docker update --restart=unless-stopped claude-learning
docker update --restart=unless-stopped claude-bridge
```

Or re-run the installer which will now apply this configuration.

## Technical Notes

1. **Docker Restart Policies**:
   - `no`: Never restart (default)
   - `always`: Always restart, even if manually stopped
   - `unless-stopped`: Restart unless manually stopped ✅ (chosen)
   - `on-failure`: Only restart on non-zero exit

2. **Why `unless-stopped`**:
   - Respects user's manual stop commands
   - Survives system reboots
   - Handles crashes gracefully
   - Most appropriate for database services

3. **Integration with docker-compose.yml**:
   - The docker-compose.yml already specifies `restart: unless-stopped`
   - This enhancement ensures the policy is applied even for manually created containers
   - Provides verification that the policy is actually active

## Related Files

- `$HOME/claude-backups/claude-installer.sh` - Main installer with enhancement
- `$HOME/claude-backups/docker-compose.yml` - Docker Compose configuration
- `$HOME/claude-backups/database/check_learning_system.sh` - System status checker

## Changelog

### 2025-08-31 - Initial Implementation
- Added `configure_docker_autostart()` function
- Integrated with both Docker and native setup paths
- Added verification and user feedback
- Documented in `docs/features/`

---

*Implementation designed by CONSTRUCTOR agent*  
*Placement optimized for installer flow*  
*Zero learning curve for end users*