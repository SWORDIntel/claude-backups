# 🔨 BUILD & DEPLOYMENT GUIDE
## Adversarial Simulation Framework

---

## Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 20.04+ recommended)
- **CPU**: Intel Core Ultra 7 or equivalent (P-cores + E-cores)
- **RAM**: 16GB minimum, 64GB recommended
- **GPU**: NVIDIA with CUDA support (optional)
- **Python**: 3.8+
- **GCC**: 9.0+
- **Node.js**: 16+ (for visualization)

### Required Libraries
```bash
# System packages
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    python3-dev \
    python3-pip \
    libzmq3-dev \
    libssl-dev \
    libevent-dev \
    postgresql-dev \
    redis-server \
    nginx

# Python packages
pip3 install -r requirements.txt
```

---

## Quick Start

### 1. One-Command Build & Run
```bash
# Complete build and start all components
./build_and_run.sh --all
```

### 2. Manual Step-by-Step

#### Build C Components
```bash
cd ADVERSARIAL_SIMULATIONS/INTEGRATION
make clean
make all

# Test C bridge
make test
```

#### Install Python Dependencies
```bash
cd ADVERSARIAL_SIMULATIONS
pip3 install -r requirements.txt

# For GPU support
pip3 install numba cudatoolkit
```

#### Start Components
```bash
# 1. Start Integration Bridge (C)
cd INTEGRATION
./simulation_c_bridge &

# 2. Start Python Bridge
python3 agent_bridge.py &

# 3. Start Orchestrator
cd ../ORCHESTRATOR
python3 simulation_orchestrator.py &

# 4. Start Visualization
cd ../VISUALIZATION
python3 realtime_visualization.py &

# 5. Access Dashboard
# Open browser: http://localhost:5000
```

---

## Component-Specific Builds

### Orchestrator
```bash
cd ADVERSARIAL_SIMULATIONS/ORCHESTRATOR

# Install dependencies
pip3 install asyncio pyyaml networkx numpy psutil

# Run orchestrator
python3 simulation_orchestrator.py

# Or with custom config
python3 simulation_orchestrator.py --config custom.yaml
```

### Visualization Dashboard
```bash
cd ADVERSARIAL_SIMULATIONS/VISUALIZATION

# Install dependencies
pip3 install flask flask-socketio plotly psutil

# Create templates directory
mkdir -p templates

# Start server
python3 realtime_visualization.py

# Access at http://localhost:5000
```

### Integration Bridge (C)
```bash
cd ADVERSARIAL_SIMULATIONS/INTEGRATION

# Build with optimizations
make CFLAGS="-O3 -march=native -mtune=native"

# Run with specific ports
./simulation_c_bridge --agent-port 4242 --sim-port 5555
```

### Integration Bridge (Python)
```bash
cd ADVERSARIAL_SIMULATIONS/INTEGRATION

# Install ZMQ
pip3 install pyzmq

# Run bridge
python3 agent_bridge.py

# With custom ports
python3 agent_bridge.py --agent-port 4242 --sim-port 5555
```

### Performance Tools
```bash
cd ADVERSARIAL_SIMULATIONS/PERFORMANCE

# Install optimization packages
pip3 install numba psutil pynvml

# For CUDA support
pip3 install cupy-cuda11x  # Replace with your CUDA version

# Run optimizer
python3 optimizer.py
```

---

## Docker Deployment

### Build Docker Images
```bash
cd ADVERSARIAL_SIMULATIONS

# Build all images
docker-compose build

# Or individual components
docker build -t sim-orchestrator -f docker/Dockerfile.orchestrator .
docker build -t sim-visualization -f docker/Dockerfile.visualization .
docker build -t sim-bridge -f docker/Dockerfile.bridge .
```

### Run with Docker Compose
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## Configuration

### Create Configuration Files

#### `config.yaml` for Orchestrator
```yaml
max_concurrent_simulations: 5
max_workers: 16
checkpoint_interval: 300
metrics_interval: 60
auto_escalation: true
adaptive_tactics: true
real_time_visualization: true
threat_intel_integration: true
```

#### `requirements.txt`
```txt
asyncio
numpy>=1.20.0
networkx>=2.6
pyyaml>=5.4
flask>=2.0.0
flask-socketio>=5.0.0
plotly>=5.0.0
psutil>=5.8.0
pyzmq>=22.0.0
numba>=0.54.0
aiofiles>=0.8.0
redis>=4.0.0
```

---

## Running Simulations

### Execute Beijing Smart City Attack
```bash
cd ADVERSARIAL_SIMULATIONS

# Start framework
./start_framework.sh

# Load scenario
python3 -c "
from ORCHESTRATOR.simulation_orchestrator import SimulationOrchestrator
import asyncio

async def run():
    orchestrator = SimulationOrchestrator()
    await orchestrator.load_scenario('scenarios/beijing_smart_city.yaml')
    result = await orchestrator.execute_scenario('beijing_smart_city')
    print(f'Result: {result}')

asyncio.run(run())
"
```

### Execute with Performance Monitoring
```bash
# Run with profiling
python3 PERFORMANCE/optimizer.py --scenario beijing_smart_city --profile

# Monitor in real-time
watch -n 1 'curl http://localhost:5000/api/status'
```

---

## Verification

### Test All Components
```bash
cd ADVERSARIAL_SIMULATIONS

# Run test suite
./run_tests.sh

# Expected output:
# ✓ C Bridge: Connected
# ✓ Python Bridge: Active
# ✓ Orchestrator: Running
# ✓ Visualization: Serving
# ✓ Performance: Optimized
```

### Check Component Status
```bash
# Check processes
ps aux | grep -E "simulation_c_bridge|agent_bridge|orchestrator|visualization"

# Check ports
netstat -tlnp | grep -E "4242|5000|5555|5556"

# Check logs
tail -f logs/*.log
```

---

## Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Find and kill process using port
sudo lsof -i :5000
sudo kill -9 <PID>
```

#### C Bridge Compilation Error
```bash
# Install missing dependencies
sudo apt-get install libzmq3-dev

# Use compatible compiler
export CC=gcc-9
make clean && make
```

#### Python Import Errors
```bash
# Set Python path
export PYTHONPATH=$PYTHONPATH:/home/ubuntu/Documents/Claude/ADVERSARIAL_SIMULATIONS

# Reinstall dependencies
pip3 install --upgrade -r requirements.txt
```

#### GPU Not Detected
```bash
# Check CUDA installation
nvidia-smi

# Install CUDA toolkit
pip3 install cudatoolkit=11.2  # Match your CUDA version
```

---

## Performance Tuning

### CPU Optimization
```bash
# Set CPU governor to performance
sudo cpupower frequency-set -g performance

# Pin processes to P-cores
taskset -c 0,2,4,6,8,10 ./simulation_c_bridge
```

### Memory Optimization
```bash
# Enable huge pages
sudo sysctl -w vm.nr_hugepages=1024

# Increase limits
ulimit -n 65535  # File descriptors
ulimit -l unlimited  # Memory locking
```

### Network Optimization
```bash
# Increase socket buffers
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
```

---

## Production Deployment

### Systemd Service Files

#### `/etc/systemd/system/sim-orchestrator.service`
```ini
[Unit]
Description=Simulation Orchestrator
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/Documents/Claude/ADVERSARIAL_SIMULATIONS
ExecStart=/usr/bin/python3 ORCHESTRATOR/simulation_orchestrator.py
Restart=always

[Install]
WantedBy=multi-user.target
```

#### Enable Services
```bash
sudo systemctl daemon-reload
sudo systemctl enable sim-orchestrator
sudo systemctl start sim-orchestrator
sudo systemctl status sim-orchestrator
```

---

## Monitoring

### Prometheus Metrics
```bash
# Start Prometheus exporter
python3 monitoring/prometheus_exporter.py &

# Metrics available at http://localhost:9090/metrics
```

### Grafana Dashboard
```bash
# Import dashboard
curl -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @monitoring/grafana-dashboard.json
```

---

## Security

### Run in Isolated Environment
```bash
# Create network namespace
sudo ip netns add simulation

# Run in namespace
sudo ip netns exec simulation ./simulation_c_bridge
```

### Limit Resource Usage
```bash
# CPU limit
sudo systemd-run --uid=ubuntu --gid=ubuntu \
  --property=CPUQuota=50% \
  ./simulation_orchestrator.py

# Memory limit
sudo systemd-run --uid=ubuntu --gid=ubuntu \
  --property=MemoryMax=8G \
  ./simulation_orchestrator.py
```

---

## Clean Up

```bash
# Stop all components
pkill -f simulation_c_bridge
pkill -f agent_bridge
pkill -f simulation_orchestrator
pkill -f realtime_visualization

# Clean build artifacts
cd ADVERSARIAL_SIMULATIONS
make clean
rm -rf __pycache__ *.pyc

# Remove logs
rm -rf logs/*
```

---

**Need help?** Check logs in `ADVERSARIAL_SIMULATIONS/logs/` or run diagnostics:
```bash
./diagnostics.sh --full
```