# Docker Kernel Integration for OpenVINO Systems

## Overview

Guide for integrating Docker-based OpenVINO deployments with kernel-level optimizations, including NPU device passthrough, container networking, and AI workload optimization.

## Docker-Based OpenVINO Deployment

### Why Docker for OpenVINO?

#### **Advantages**
- **No Build Complexity**: Pre-built environments eliminate protobuf/compilation issues
- **Consistent Deployment**: Same environment across different host systems
- **Rapid Deployment**: Minutes vs hours for OpenVINO setup
- **Isolation**: Clean separation from host system dependencies
- **Version Control**: Easy switching between OpenVINO versions

#### **Disadvantages**
- **Performance Overhead**: 5-10% performance penalty vs native
- **Hardware Access**: Complex NPU/GPU device passthrough
- **Integration**: More complex agent framework integration
- **Resource Usage**: Additional memory overhead for container runtime

### Docker OpenVINO Images

#### **Official Intel Images**
```bash
# Development environment (Ubuntu 20.04 + OpenVINO tools)
docker pull openvino/ubuntu20_dev:latest

# Runtime only (minimal)
docker pull openvino/ubuntu20_runtime:latest

# C++ development
docker pull openvino/ubuntu20_dev:2025.4.0

# Python development
docker pull openvino/python_runtime:2025.4.0
```

#### **Custom Image Build**
```dockerfile
# Dockerfile.openvino-ai
FROM openvino/ubuntu20_dev:latest

# Install additional AI tools
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    build-essential \
    cmake \
    git \
    wget \
    curl

# Install Python packages for AI acceleration
RUN pip3 install numpy scipy scikit-learn matplotlib jupyter

# Install OpenVINO Python API
RUN pip3 install openvino openvino-dev

# Configure environment
ENV INTEL_OPENVINO_DIR=/opt/intel/openvino
ENV OpenVINO_DIR=/opt/intel/openvino/runtime/cmake
ENV LD_LIBRARY_PATH=/opt/intel/openvino/runtime/lib/intel64:$LD_LIBRARY_PATH

# Create working directory
WORKDIR /workspace

# Copy test scripts
COPY test-openvino-npu.py /workspace/
COPY ai-benchmark.py /workspace/

CMD ["/bin/bash"]
```

## NPU Device Passthrough

### Host System Requirements

#### **NPU Driver Installation**
```bash
# Verify NPU hardware
lspci | grep -i vpu
# Expected: Intel Corporation Device 7d1d (NPU)

# Check driver status
lsmod | grep intel_vpu
# Expected: intel_vpu module loaded

# Verify device creation
ls -la /dev/accel/accel0
# Expected: crw-rw---- 1 root render 261, 0
```

#### **Container Runtime Configuration**
```bash
# Install Docker with NPU support
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
sudo usermod -aG render $USER  # For NPU access

# Configure Docker daemon for hardware access
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "default-runtime": "runc",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-ulimits": {
    "memlock": {
      "hard": -1,
      "soft": -1
    }
  }
}
EOF

sudo systemctl restart docker
```

### Docker Run Configuration

#### **Full Hardware Access**
```bash
#!/bin/bash
# run-openvino-docker.sh - Complete NPU/GPU passthrough

docker run -it --rm \
    --name openvino-ai \
    \
    --device /dev/accel/accel0:/dev/accel/accel0 \
    --device /dev/dri:/dev/dri \
    \
    --group-add render \
    --group-add video \
    \
    -v /opt/openvino:/opt/openvino:ro \
    -v $(pwd):/workspace \
    -v /tmp:/tmp \
    \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    \
    --privileged \
    --ipc=host \
    --network=host \
    \
    openvino/ubuntu20_dev:latest \
    /bin/bash
```

#### **Security-Hardened Version**
```bash
#!/bin/bash
# run-openvino-secure.sh - Minimal permissions

docker run -it --rm \
    --name openvino-ai \
    \
    --device /dev/accel/accel0 \
    --group-add $(getent group render | cut -d: -f3) \
    \
    -v /opt/openvino/runtime:/opt/intel/openvino/runtime:ro \
    -v $(pwd)/workspace:/workspace \
    \
    --cap-drop ALL \
    --cap-add SYS_ADMIN \
    --security-opt no-new-privileges \
    \
    -u $(id -u):$(id -g) \
    \
    --memory=8g \
    --cpus=8 \
    \
    openvino/ubuntu20_dev:latest \
    /bin/bash
```

### Docker Compose Configuration

```yaml
# docker-compose.openvino.yml
version: '3.8'

services:
  openvino-dev:
    image: openvino/ubuntu20_dev:latest
    container_name: openvino-ai-dev
    
    devices:
      - /dev/accel/accel0:/dev/accel/accel0
      - /dev/dri:/dev/dri
    
    group_add:
      - render
      - video
    
    volumes:
      - /opt/openvino:/opt/openvino:ro
      - ./workspace:/workspace
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
    
    environment:
      - DISPLAY=${DISPLAY}
      - INTEL_OPENVINO_DIR=/opt/intel/openvino
      - LD_LIBRARY_PATH=/opt/intel/openvino/runtime/lib/intel64
    
    working_dir: /workspace
    
    networks:
      - openvino-net
    
    stdin_open: true
    tty: true

networks:
  openvino-net:
    driver: bridge
```

## Kernel Integration Points

### Container Networking

#### **Host Network Mode**
```bash
# Direct host network access (fastest)
docker run --network=host openvino/ubuntu20_dev:latest

# Benefits:
# - No network performance penalty
# - Direct access to host services
# - Simple configuration

# Drawbacks:
# - Less isolation
# - Port conflicts possible
```

#### **Bridge Network with Port Mapping**
```bash
# Custom bridge network
docker network create \
    --driver bridge \
    --subnet=172.20.0.0/16 \
    openvino-net

# Run with port mapping
docker run \
    --network openvino-net \
    -p 8080:8080 \
    -p 8888:8888 \
    openvino/ubuntu20_dev:latest

# Benefits:
# - Network isolation
# - Controlled port exposure
# - Multiple container support
```

### Kernel Module Access

#### **Intel NPU Driver Integration**
```bash
# Inside container - verify NPU access
ls -la /dev/accel/accel0
lsmod | grep intel_vpu  # May not show in container

# Test NPU functionality
python3 -c "
import openvino as ov
ie = ov.Core()
print('Devices:', ie.available_devices)
"
```

#### **GPU Integration (Intel iGPU)**
```bash
# Verify GPU passthrough
ls -la /dev/dri/
# Expected: renderD128, card0, etc.

# Test GPU access
python3 -c "
import openvino as ov
ie = ov.Core()
if 'GPU' in ie.available_devices:
    name = ie.get_property('GPU', 'FULL_DEVICE_NAME')
    print(f'GPU: {name}')
else:
    print('GPU not available')
"
```

### Memory Management

#### **Shared Memory Configuration**
```bash
# Host shared memory setup
sudo sysctl -w kernel.shmmax=68719476736    # 64GB
sudo sysctl -w kernel.shmall=16777216       # 64GB in pages

# Docker shared memory
docker run \
    --shm-size=8g \
    --ipc=host \
    openvino/ubuntu20_dev:latest
```

#### **Memory Mapping for AI Workloads**
```bash
# Inside container - configure AI memory
echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf
echo 'vm.swappiness=10' >> /etc/sysctl.conf

# Apply (requires privileged container)
sysctl -p /etc/sysctl.conf
```

## Performance Optimization

### CPU Affinity and Scheduling

#### **Container CPU Binding**
```bash
# Bind to specific cores (P-cores for AI)
docker run \
    --cpuset-cpus="0-11" \
    --cpu-quota=1200000 \
    --cpu-period=100000 \
    openvino/ubuntu20_dev:latest

# P-cores: 0-11 (performance)
# E-cores: 12-21 (efficiency) - avoid for AI
```

#### **Real-time Scheduling**
```bash
# Enable real-time scheduling for AI containers
docker run \
    --ulimit rtprio=99 \
    --cap-add SYS_NICE \
    openvino/ubuntu20_dev:latest
```

### Thermal Management

#### **Container Thermal Monitoring**
```bash
#!/bin/bash
# thermal-monitor-docker.sh

docker exec -it openvino-ai-dev bash -c '
while true; do
    temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1)
    if [ -n "$temp" ]; then
        echo "Container Thermal: $((temp/1000))°C"
    fi
    sleep 5
done
'
```

### Storage Optimization

#### **High-Performance Storage**
```bash
# Use tmpfs for temporary AI data
docker run \
    --tmpfs /tmp:rw,noexec,nosuid,size=10g \
    --tmpfs /workspace/cache:rw,size=5g \
    openvino/ubuntu20_dev:latest
```

#### **Persistent AI Model Storage**
```bash
# Create named volume for models
docker volume create openvino-models

# Mount volume with optimizations
docker run \
    -v openvino-models:/workspace/models:rw,cached \
    openvino/ubuntu20_dev:latest
```

## Agent Framework Integration

### Docker-Based Agent Architecture

#### **Containerized Hardware Agents**
```bash
# Create hardware agent container
docker create \
    --name hardware-intel-agent \
    --device /dev/accel/accel0 \
    --group-add render \
    -v /opt/openvino:/opt/openvino:ro \
    openvino/ubuntu20_dev:latest \
    python3 /agents/HARDWARE-INTEL.py
```

#### **Agent Communication Bridge**
```python
# docker-agent-bridge.py
import docker
import asyncio

class DockerAgentBridge:
    def __init__(self):
        self.client = docker.from_env()
    
    async def invoke_agent(self, agent_name, prompt):
        """Invoke containerized agent"""
        container_name = f"agent-{agent_name.lower()}"
        
        try:
            container = self.client.containers.get(container_name)
            
            # Execute agent command
            result = container.exec_run(
                f"python3 /agents/{agent_name}.py --prompt '{prompt}'",
                stdout=True,
                stderr=True
            )
            
            return {
                "success": result.exit_code == 0,
                "output": result.output.decode(),
                "container": container_name
            }
            
        except docker.errors.NotFound:
            return {
                "success": False,
                "error": f"Agent container {container_name} not found"
            }

# Usage
bridge = DockerAgentBridge()
result = await bridge.invoke_agent("HARDWARE-INTEL", "optimize NPU for AI")
```

### Multi-Container Agent Orchestration

#### **Docker Compose for Agent Ecosystem**
```yaml
# docker-compose.agents.yml
version: '3.8'

services:
  hardware-base:
    image: openvino/ubuntu20_dev:latest
    container_name: agent-hardware
    privileged: true
    volumes:
      - /home/john/claude-backups/agents:/agents:ro
    command: python3 /agents/agent-server.py --port 8001
    
  hardware-intel:
    image: openvino/ubuntu20_dev:latest
    container_name: agent-hardware-intel
    devices:
      - /dev/accel/accel0:/dev/accel/accel0
    group_add:
      - render
    volumes:
      - /opt/openvino:/opt/openvino:ro
      - /home/john/claude-backups/agents:/agents:ro
    command: python3 /agents/agent-server.py --port 8002 --agent HARDWARE-INTEL
    
  orchestrator:
    image: openvino/ubuntu20_dev:latest
    container_name: agent-orchestrator
    depends_on:
      - hardware-base
      - hardware-intel
    volumes:
      - /home/john/claude-backups:/workspace:ro
    networks:
      - agents-net
    command: python3 /workspace/orchestration/docker-orchestrator.py

networks:
  agents-net:
    driver: bridge
```

## Kernel Use Cases

### 1. AI-Enhanced Kernel Compilation

#### **Container-Based Build**
```bash
# Kernel compilation with OpenVINO optimization
docker run \
    --privileged \
    --device /dev/accel/accel0 \
    -v /usr/src/linux:/workspace/kernel:ro \
    -v /opt/openvino:/opt/openvino:ro \
    -v $(pwd)/output:/workspace/output \
    --cpuset-cpus="0-11" \
    --memory=32g \
    openvino/ubuntu20_dev:latest \
    bash -c '
    cd /workspace/kernel
    
    # AI-optimized kernel configuration
    python3 /workspace/ai-kernel-optimizer.py \
        --config .config \
        --optimize-for intel-meteor-lake \
        --enable-npu-acceleration
    
    # Compile with OpenVINO-guided optimization
    make -j12 HOSTCC="gcc -O3 -march=native" \
              CC="gcc -O3 -march=native -mavx512f"
    
    # Output optimized kernel
    cp arch/x86/boot/bzImage /workspace/output/vmlinuz-ai-optimized
    '
```

#### **Benefits of Containerized Kernel Builds**
- **Clean Environment**: No host system contamination
- **Reproducible Builds**: Identical environment every time
- **Resource Isolation**: Controlled CPU/memory allocation
- **AI Integration**: OpenVINO optimization without host conflicts

### 2. NPU Driver Testing

#### **Container-Based Driver Validation**
```bash
# NPU driver stress test
docker run \
    --device /dev/accel/accel0 \
    --group-add render \
    -v /opt/openvino:/opt/openvino:ro \
    openvino/ubuntu20_dev:latest \
    python3 -c "
import openvino as ov
import numpy as np
import time

ie = ov.Core()
if 'NPU' in ie.available_devices:
    print('NPU available - running stress test')
    
    # Stress test NPU
    for i in range(100):
        tensor = ov.Tensor(ov.Type.f32, [1, 3, 224, 224])
        data = np.random.random((1, 3, 224, 224)).astype(np.float32)
        tensor.data[:] = data.flatten()
        
        if i % 10 == 0:
            print(f'NPU test iteration {i}')
    
    print('NPU stress test completed successfully')
else:
    print('NPU not available in container')
"
```

### 3. Kernel Module Hot-Loading

#### **Dynamic Kernel Module Testing**
```bash
# Test kernel modules with container isolation
docker run \
    --privileged \
    --pid=host \
    -v /lib/modules:/lib/modules:ro \
    -v /proc:/host/proc:ro \
    ubuntu:20.04 \
    bash -c '
    # Load Intel VPU driver
    modprobe intel_vpu
    
    # Verify loading
    lsmod | grep intel_vpu
    
    # Test device creation
    sleep 2
    ls -la /dev/accel/accel0
    
    echo "Kernel module test completed"
    '
```

## Monitoring and Diagnostics

### Container Performance Monitoring

#### **Docker Stats Integration**
```bash
#!/bin/bash
# docker-openvino-monitor.sh

echo "OpenVINO Container Monitoring"
echo "============================"

while true; do
    # Container resource usage
    docker stats --no-stream --format \
        "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" \
        openvino-ai-dev 2>/dev/null
    
    # NPU device status
    echo -n "NPU Device: "
    docker exec openvino-ai-dev ls -la /dev/accel/accel0 2>/dev/null | \
        awk '{print $3":"$4" "$1}' || echo "Not accessible"
    
    # OpenVINO device test
    echo -n "OpenVINO Devices: "
    docker exec openvino-ai-dev python3 -c \
        "import openvino as ov; print(ov.Core().available_devices)" 2>/dev/null || \
        echo "OpenVINO not accessible"
    
    echo "---"
    sleep 10
done
```

### Kernel Integration Health Check

#### **System Integration Validation**
```python
#!/usr/bin/env python3
# docker-kernel-health-check.py

import docker
import subprocess
import json

def check_kernel_integration():
    """Validate Docker-Kernel-OpenVINO integration"""
    
    client = docker.from_env()
    results = {}
    
    # 1. Host kernel NPU support
    try:
        result = subprocess.run(['lsmod'], capture_output=True, text=True)
        results['host_npu_driver'] = 'intel_vpu' in result.stdout
    except:
        results['host_npu_driver'] = False
    
    # 2. NPU device availability
    try:
        result = subprocess.run(['ls', '/dev/accel/accel0'], 
                              capture_output=True, text=True)
        results['npu_device'] = result.returncode == 0
    except:
        results['npu_device'] = False
    
    # 3. Container NPU access
    try:
        container = client.containers.get('openvino-ai-dev')
        exec_result = container.exec_run('ls -la /dev/accel/accel0')
        results['container_npu_access'] = exec_result.exit_code == 0
    except:
        results['container_npu_access'] = False
    
    # 4. OpenVINO functionality
    try:
        container = client.containers.get('openvino-ai-dev')
        exec_result = container.exec_run(
            'python3 -c "import openvino as ov; print(len(ov.Core().available_devices))"'
        )
        device_count = int(exec_result.output.decode().strip())
        results['openvino_devices'] = device_count >= 2  # CPU + GPU minimum
    except:
        results['openvino_devices'] = False
    
    return results

def generate_health_report(results):
    """Generate health report"""
    print("Docker-Kernel-OpenVINO Integration Health Check")
    print("=" * 50)
    
    status_map = {True: "✅ PASS", False: "❌ FAIL"}
    
    for check, status in results.items():
        print(f"{check.replace('_', ' ').title()}: {status_map[status]}")
    
    # Overall health
    all_passed = all(results.values())
    print(f"\nOverall Health: {status_map[all_passed]}")
    
    if not all_passed:
        print("\n🔧 Troubleshooting Steps:")
        if not results['host_npu_driver']:
            print("- Install Intel VPU driver: sudo modprobe intel_vpu")
        if not results['npu_device']:
            print("- Check NPU hardware: lspci | grep -i vpu")
        if not results['container_npu_access']:
            print("- Add device passthrough: --device /dev/accel/accel0")
        if not results['openvino_devices']:
            print("- Check OpenVINO installation in container")

if __name__ == "__main__":
    results = check_kernel_integration()
    generate_health_report(results)
```

## Best Practices

### Security

#### **Container Security Hardening**
```bash
# Minimal privilege container
docker run \
    --user $(id -u):$(id -g) \
    --cap-drop ALL \
    --cap-add SYS_ADMIN \
    --security-opt no-new-privileges \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid \
    openvino/ubuntu20_dev:latest
```

#### **Device Access Control**
```bash
# Controlled device access
docker run \
    --device /dev/accel/accel0:r \
    --device-cgroup-rule 'c 261:0 r' \
    openvino/ubuntu20_dev:latest
```

### Performance

#### **Resource Optimization**
- **CPU Binding**: Use P-cores (0-11) for AI workloads
- **Memory Limits**: Set appropriate limits based on workload
- **Network Mode**: Use host networking for performance
- **Storage**: Use tmpfs for temporary AI data

#### **Monitoring Integration**
- **Container Stats**: Monitor resource usage continuously
- **Hardware Metrics**: Track NPU/GPU utilization
- **Thermal Monitoring**: Watch temperature during AI workloads

## Conclusion

Docker integration provides a robust alternative to native OpenVINO compilation while maintaining hardware acceleration capabilities. The containerized approach offers:

- **Simplified Deployment**: No complex build processes
- **Consistent Environments**: Same setup across different systems  
- **Hardware Access**: Full NPU/GPU passthrough support
- **Kernel Integration**: Direct access to kernel modules and devices
- **Agent Framework**: Seamless integration with Claude agent ecosystem

This approach is particularly valuable for:
- **Development Systems**: Rapid OpenVINO environment setup
- **Testing Platforms**: Isolated AI workload validation
- **Production Deployment**: Controlled, reproducible AI acceleration
- **Multi-System Management**: Consistent environments across hardware variants

---
*Docker Kernel Integration Guide - Containerized AI Acceleration*  
*Version: 1.0 | Updated: 2025-08-30*