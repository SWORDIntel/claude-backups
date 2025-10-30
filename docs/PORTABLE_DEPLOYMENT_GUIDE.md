# Portable AI Deployment Guide

**Date**: 2025-10-30
**Target**: Qwen 2.5-32B Portable Deployment Options
**Focus**: NUC2 Stick & Portable Systems

## Overview

The INT4 quantized Qwen 2.5-32B model (⁓15GB) opens up exciting portable deployment possibilities, making high-capability AI inference available on compact hardware.

## Deployment Options

### 🚀 Option 1: NUC2 Stick Deployment

**Hardware Requirements:**
- **Storage**: 32GB+ USB 3.0/3.1 stick or NVMe
- **Memory**: 16GB+ RAM (24GB+ recommended)
- **CPU**: Intel 10th gen+ (Comet Lake or newer)
- **OS**: Windows 10/11 or Ubuntu 20.04+

**Model Configuration:**
- **Size**: ~15GB INT4 quantized
- **Performance**: 20-30 tokens/second
- **Memory Usage**: ~20-25GB total (model + overhead)
- **Context**: 2048 tokens optimized

**Setup Process:**
```bash
# 1. Prepare storage device
mkdir /media/usb-ai/qwen-models

# 2. Copy quantized model
cp -r qwen-openvino/models/qwen_portable_int4/ /media/usb-ai/qwen-models/

# 3. Copy inference server
cp qwen-openvino/qwen_inference_server.py /media/usb-ai/
cp start_qwen_inference.sh /media/usb-ai/

# 4. Create portable startup script
cat > /media/usb-ai/start_portable_ai.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
python3 qwen_inference_server.py --port 8000 --host 0.0.0.0
EOF
chmod +x /media/usb-ai/start_portable_ai.sh
```

### 🏠 Option 2: Intel NUC Deployment

**Hardware Requirements:**
- **Intel NUC**: 11th gen+ (Tiger Lake or newer)
- **Storage**: 256GB+ NVMe SSD
- **Memory**: 32GB+ DDR4/DDR5
- **Network**: Gigabit Ethernet + WiFi 6

**Model Configurations Available:**
- **Ultra-Fast**: 7B model (~4GB) - 80+ tokens/second
- **Balanced**: 14B model (~8GB) - 50+ tokens/second
- **Full**: 32B model (~15GB) - 25+ tokens/second

**Performance Expectations:**
```
Intel NUC 11 (Tiger Lake):
  Qwen-7B INT4:  80-100 tokens/second
  Qwen-14B INT4: 50-70 tokens/second
  Qwen-32B INT4: 25-35 tokens/second

Intel NUC 12+ (Alder Lake+):
  Qwen-7B INT4:  100-120 tokens/second
  Qwen-14B INT4: 60-80 tokens/second
  Qwen-32B INT4: 30-45 tokens/second
```

### 💼 Option 3: Laptop Deployment

**Optimal Laptops:**
- **Business**: Dell Latitude, HP EliteBook, Lenovo ThinkPad
- **Gaming**: ASUS, MSI, Razer (with dedicated cooling)
- **Workstation**: Dell Precision, HP ZBook

**Resource Management:**
```python
# Dynamic resource allocation
if available_ram > 32:
    model_variant = "qwen_32b_int4"    # Full capability
elif available_ram > 16:
    model_variant = "qwen_14b_int4"    # Balanced
else:
    model_variant = "qwen_7b_int4"     # Lightweight
```

## Storage Requirements

### Model Size Breakdown
```
Qwen 2.5 Models (INT4 Quantized):
├── 7B Model:  ~3.5GB
├── 14B Model: ~7.0GB
├── 32B Model: ~15.1GB
└── Overhead:  ~2-3GB (tokenizer, configs, server)

Total Storage Recommendations:
├── Single Model:  25GB+ available
├── Multi Model:   50GB+ available
└── Development:   100GB+ available
```

### USB Stick Recommendations
```
Portable Deployment Storage:
├── 32GB USB 3.0: Single 7B or 14B model
├── 64GB USB 3.1: Single 32B model + overhead
├── 128GB USB 3.2: Multiple models + caching
└── 256GB+ NVMe:   Full development environment
```

## Network Deployment

### Standalone Mode
```bash
# Local inference only
python3 qwen_inference_server.py --host 127.0.0.1 --port 8000
```

### Network Sharing Mode
```bash
# Share across local network
python3 qwen_inference_server.py --host 0.0.0.0 --port 8000

# Access from other devices:
# http://[NUC-IP]:8000/v1/chat/completions
```

### Agent Integration
```python
# Configure 98-agent system to use local inference
CLAUDE_LOCAL_ENDPOINT = "http://localhost:8000/v1/chat/completions"
CLAUDE_API_KEY = "local"  # Not required for local inference
```

## Performance Optimization

### CPU Optimization
```json
{
  "compilation_config": {
    "CPU_THREADS_NUM": "auto",
    "CPU_BIND_THREAD": "HYBRID_AWARE",
    "PERFORMANCE_HINT": "LATENCY",
    "INFERENCE_PRECISION_HINT": "f32"
  }
}
```

### Memory Optimization
```json
{
  "memory_optimization": {
    "kv_cache_quantization": true,
    "enable_kv_cache_compression": true,
    "max_sequence_length": 2048,
    "dynamic_batching": false
  }
}
```

### Thermal Management
```bash
# Monitor system temperature
watch -n 1 'sensors | grep Core'

# Automatic throttling for sustained performance
if cpu_temp > 85°C:
    reduce_thread_count()
    enable_thermal_throttling()
```

## Use Cases

### 🏢 Business Deployment
- **Offline Documentation**: Technical writing, report generation
- **Meeting Assistant**: Real-time transcription and summarization
- **Code Review**: Local code analysis and suggestions
- **Customer Support**: FAQ assistance without data leakage

### 🎓 Educational Deployment
- **Student Assistant**: Homework help, explanations
- **Research Tool**: Literature analysis, citation help
- **Language Learning**: Grammar correction, conversation practice
- **STEM Tutoring**: Math, science problem solving

### 🔒 Security-Focused Deployment
- **Air-Gapped Systems**: Completely offline operation
- **Sensitive Data**: No cloud transmission required
- **Compliance**: GDPR, HIPAA, SOX compliant processing
- **Military/Government**: Classified environment compatibility

## Installation Automation

### Quick Deploy Script
```bash
#!/bin/bash
# Portable AI Quick Deploy Script

# Download and setup
wget https://github.com/user/repo/releases/latest/qwen-portable.tar.gz
tar -xzf qwen-portable.tar.gz
cd qwen-portable

# Auto-detect optimal model size
./auto_deploy.sh

# Start inference server
./start_portable_ai.sh
```

### Docker Deployment
```dockerfile
FROM intel/openvino:2025.3-ubuntu20
COPY qwen-models/ /app/models/
COPY qwen_inference_server.py /app/
EXPOSE 8000
CMD ["python3", "/app/qwen_inference_server.py"]
```

## Monitoring & Maintenance

### Performance Monitoring
```bash
# Real-time performance tracking
curl http://localhost:8000/stats | jq .

# Expected output:
{
  "tokens_per_second": 35.2,
  "average_latency": 1.2,
  "memory_usage": "18.5GB",
  "cpu_utilization": "65%"
}
```

### Health Checks
```bash
# Automated health monitoring
while true; do
  curl -s http://localhost:8000/health || echo "Service down!"
  sleep 30
done
```

## Deployment Checklist

### Pre-Deployment
- [ ] Hardware compatibility verified
- [ ] Storage space available (25GB+)
- [ ] Memory requirements met (16GB+)
- [ ] Network configuration planned
- [ ] Backup strategy defined

### Post-Deployment
- [ ] Inference server responding
- [ ] Performance benchmarks met
- [ ] Agent integration tested
- [ ] Monitoring configured
- [ ] Backup tested

### Optimization
- [ ] Model variant selection optimized
- [ ] Thread allocation tuned
- [ ] Memory usage optimized
- [ ] Thermal monitoring active
- [ ] Network performance validated

## Troubleshooting

### Common Issues
```bash
# Out of memory
Error: Unable to allocate tensor
Solution: Use smaller model variant or increase RAM

# Slow performance
Issue: <10 tokens/second
Solution: Check CPU throttling, optimize thread count

# Model loading failure
Error: Unable to load OpenVINO model
Solution: Verify model files integrity, check permissions
```

---

**Summary**: The 15GB INT4 quantized model makes powerful AI inference truly portable, enabling deployment on NUC2 sticks, laptops, and edge devices while maintaining strong performance and complete offline operation.

**Next Steps**: Complete model conversion and create automated deployment packages for various hardware targets.