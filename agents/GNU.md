```yaml
################################################################################
# GAUSSIAN PROCESSING UNIT (GNA) AGENT DEFINITION v7.0
################################################################################

agent_template:
  # Metadata Section
  metadata:
    name: GAUSSIAN_PROCESSOR
    version: 7.0.0
    uuid: g4u55-14n-pr0c-3550r-gna0x7d1e
    
    category: ML-OPS  # Machine learning operations specialized for GNA
    priority: HIGH
    status: PRODUCTION
    
    description: |
      Ultra-low power neural inference agent for Intel GNA (Gaussian Neural Accelerator).
      Specializes in continuous AI workloads, anomaly detection, pattern recognition,
      and always-on inference with minimal power consumption (<0.5W typical).
      
  # Hardware Requirements & Constraints
  hardware:
    cpu_requirements:
      meteor_lake_specific: true
      avx512_benefit: NONE  # GNA operates independently
      microcode_sensitive: false
      
      gna_specifications:
        device_id: "8086:7e4c"  # Intel GNA device
        architecture: "Gaussian Neural Accelerator v3.0"
        memory: "4MB dedicated SRAM"
        peak_performance: "1 TOPS (INT8)"
        power_consumption: "0.1-0.5W typical"
        precision_support:
          - INT8  # Primary
          - INT16 # Secondary
          - INT4  # Experimental
          
      core_allocation_strategy:
        # GNA operates independently but needs CPU for data transfer
        single_threaded: E_CORES      # Use E-cores for data prep
        multi_threaded: NOT_APPLICABLE # GNA is single-stream
        background_tasks: IDEAL        # Perfect for background AI
        mixed_workload: GNA_OFFLOAD    # Offload appropriate workloads
        
    thermal_management:
      operating_ranges:
        optimal: "25-45°C"    # Ultra-low heat generation
        normal: "45-65°C"     # Still efficient
        caution: "65-75°C"    # Rarely reached
        throttle: "75°C+"     # Automatic frequency reduction
        critical: "85°C"      # Shutdown (unlikely)
        
      thermal_strategy:
        # GNA generates minimal heat - ideal for continuous operation
        below_45: MAXIMUM_PERFORMANCE
        below_65: NORMAL_OPERATION
        below_75: MONITOR_ONLY
        above_75: REDUCE_FREQUENCY
        
    npu_usage:
      relationship: COMPLEMENTARY  # GNA + NPU work together
      workload_distribution: |
        GNA: Always-on, low-power inference (voice, anomaly)
        NPU: Burst inference, vision models, transformers
        CPU: Preprocessing, fallback, complex operations
        
    memory_configuration:
      gna_memory: "4MB SRAM"
      dma_capable: true
      zero_copy: true  # Direct memory access
      
  # Runtime Detection & Adaptation
  runtime_adaptation:
    startup_checks:
      - name: "GNA device detection"
        command: "lspci | grep -i 'gaussian\\|gna\\|7e4c'"
        validate: "Device 8086:7e4c present"
        
      - name: "GNA driver verification"
        command: "lsmod | grep gna"
        validate: "gna module loaded"
        
      - name: "OpenVINO GNA plugin"
        command: "python -c 'from openvino.runtime import Core; print(\"GNA\" in Core().available_devices)'"
        validate: "GNA device available"
        
      - name: "Memory allocation check"
        path: "/sys/class/gna/gna0/mem_total"
        validate: "4194304"  # 4MB in bytes
        
      - name: "Power state verification"
        path: "/sys/class/gna/gna0/power_state"
        validate: "D0"  # Active state
        
    execution_profiles:
      ultra_low_power:
        condition: "Battery mode OR always-on inference"
        configuration:
          device: "GNA"
          precision: "INT8"
          frequency: "200MHz"
          power_budget: "0.1W"
          use_cases:
            - "Wake word detection"
            - "Continuous anomaly monitoring"
            - "Background noise suppression"
            
      balanced_efficiency:
        condition: "Normal operation with power constraints"
        configuration:
          device: "GNA"
          precision: "INT8"
          frequency: "400MHz"
          power_budget: "0.3W"
          use_cases:
            - "Voice activity detection"
            - "Pattern recognition"
            - "Sensor fusion"
            
      maximum_performance:
        condition: "AC power AND critical inference"
        configuration:
          device: "GNA"
          precision: "INT16"  # Higher precision
          frequency: "600MHz"
          power_budget: "0.5W"
          use_cases:
            - "Real-time speech recognition"
            - "Complex pattern matching"
            - "Multi-stream processing"
            
      hybrid_mode:
        condition: "Complex workload requiring multiple accelerators"
        configuration:
          primary: "GNA"  # For continuous monitoring
          secondary: "NPU"  # For burst processing
          fallback: "CPU"  # For unsupported ops
          coordination: "Pipeline parallelism"
          
  # Agent Communication Protocol
  communication:
    gna_message_format:
      header: |
        struct GNAMessage {
            uint32_t magic;        // 'GNA0' (0x474E4130)
            uint16_t version;      // 0x0700
            uint16_t flags;        // Status flags
            uint32_t stream_id;    // Continuous stream identifier
            uint64_t timestamp;    // Unix epoch nanos
            float anomaly_score;   // 0.0-1.0 detection score
            uint8_t precision;     // INT4/INT8/INT16
            uint32_t inference_us; // Inference time in microseconds
            
            // Flags (16 bits):
            // bit 0: stream_active
            // bit 1: anomaly_detected  
            // bit 2: low_power_mode
            // bit 3: continuous_mode
            // bit 4: pattern_match
            // bit 5: voice_detected
            // bit 6: buffer_overflow
            // bit 7: precision_reduced
            // bit 8-15: reserved
        }
        
    metadata_fields:
      required:
        agent_uuid: "string[36]"
        stream_id: "uint32"
        model_hash: "string[64]"  # SHA256 of loaded model
        
      performance:
        power_mw: "uint16"        # Current power in milliwatts
        fps: "float"              # Inferences per second
        latency_us: "uint32"      # Microseconds per inference
        accuracy: "float"         # Current accuracy metric
        
      capabilities:
        models_loaded: "uint8"     # Number of concurrent models
        streams_active: "uint8"    # Active inference streams
        memory_used_kb: "uint32"   # SRAM usage in KB
        
  # GNA-Specific Operations
  gna_operations:
    supported_layers:
      - "1D/2D Convolution (small kernels)"
      - "Fully Connected (up to 8K neurons)"
      - "Recurrent layers (LSTM, GRU)"
      - "Activation functions (ReLU, Sigmoid, Tanh)"
      - "Pooling (Max, Average)"
      - "Batch normalization"
      
    optimized_models:
      speech_models:
        - "Kaldi acoustic models"
        - "DeepSpeech variants"
        - "Wav2Vec2 (quantized)"
        - "Whisper-tiny (INT8)"
        
      anomaly_detection:
        - "Autoencoders"
        - "Isolation forests"
        - "One-class SVM"
        - "LSTM anomaly detectors"
        
      signal_processing:
        - "Noise suppression networks"
        - "Echo cancellation"
        - "Beamforming networks"
        - "Audio enhancement"
        
  # OpenVINO Integration
  openvino_integration:
    initialization: |
      ```python
      from openvino.runtime import Core
      
      # Initialize OpenVINO with GNA
      core = Core()
      
      # GNA-specific configuration
      config = {
          "GNA_DEVICE_MODE": "GNA_SW_FP32",  # or GNA_HW for hardware
          "GNA_PRECISION": "I8",              # INT8 precision
          "GNA_PERFORMANCE_HINT": "LATENCY",  # or THROUGHPUT
          "GNA_PWL_MAX_ERROR_PERCENT": "1.0", # Piecewise linear approximation
      }
      
      # Load model to GNA
      model = core.read_model("anomaly_detector.xml")
      compiled = core.compile_model(model, "GNA", config)
      ```
      
    inference_example: |
      ```python
      import numpy as np
      
      def gna_continuous_inference(compiled_model, audio_stream):
          """Continuous inference on audio stream"""
          
          infer_request = compiled_model.create_infer_request()
          
          for audio_chunk in audio_stream:
              # Prepare input (INT8 quantization)
              input_data = np.array(audio_chunk, dtype=np.int8)
              
              # Run inference
              results = infer_request.infer({0: input_data})
              
              # Check for anomalies
              anomaly_score = results[0][0]
              if anomaly_score > 0.8:
                  yield {"timestamp": time.time(), 
                        "anomaly": True, 
                        "score": anomaly_score}
      ```
      
  # Error Handling & Recovery
  error_handling:
    gna_errors:
      memory_overflow:
        cause: "Model too large for 4MB SRAM"
        detection: "GNA_ERROR_MEMORY_OVERFLOW"
        recovery: |
          1. Quantize model to INT8
          2. Reduce model size via pruning
          3. Split model into smaller chunks
          4. Fallback to NPU or CPU
          
      unsupported_operation:
        cause: "Layer type not supported by GNA"
        detection: "GNA_ERROR_UNSUPPORTED_LAYER"
        recovery: |
          1. Check supported operations list
          2. Replace unsupported layers
          3. Use graph partitioning (GNA + CPU)
          4. Convert to supported equivalent
          
      precision_loss:
        cause: "INT8 quantization accuracy loss"
        detection: "Accuracy below threshold"
        recovery: |
          1. Try INT16 precision
          2. Retrain with quantization-aware training
          3. Use hybrid precision (mixed INT8/INT16)
          4. Fallback to NPU for critical sections
          
  # Performance Benchmarks
  performance_metrics:
    inference_latency:
      speech_recognition: "5ms per frame"
      anomaly_detection: "1ms per sample"
      pattern_matching: "2ms per pattern"
      
    throughput:
      continuous_streams: "10 concurrent"
      samples_per_second: "100,000"
      
    power_efficiency:
      idle: "0.05W"
      active: "0.1-0.3W"
      peak: "0.5W"
      efficiency: "2000 inferences/joule"
      
    model_sizes:
      maximum: "4MB"
      optimal: "1-2MB"
      minimum: "100KB"
      
################################################################################
# OPERATIONAL NOTES
################################################################################

operational_notes:
  use_cases:
    primary:
      - "Always-on voice detection (Alexa, Siri style)"
      - "Continuous health monitoring from sensors"
      - "Real-time anomaly detection in system logs"
      - "Background noise cancellation"
      - "Power-efficient edge AI"
      
    avoid:
      - "Large language models (use NPU)"
      - "Computer vision (use NPU/GPU)"
      - "Training (CPU/GPU only)"
      - "High-precision floating point (use CPU)"
      
  optimization_tips:
    - "Quantize models to INT8 for best efficiency"
    - "Keep models under 2MB for optimal performance"
    - "Use for continuous/streaming workloads"
    - "Combine with NPU for hybrid inference pipelines"
    - "Profile power consumption with powertop"
    
  integration_patterns:
    - "GNA for detection → NPU for classification"
    - "GNA for voice activity → CPU for transcription"
    - "GNA for anomaly flagging → GPU for detailed analysis"
    - "GNA for sensor fusion → CPU for decision making"
    
  military_applications:
    - "Tactical communication noise suppression"
    - "Continuous threat monitoring"
    - "Voice command recognition in noisy environments"
    - "Sensor anomaly detection"
    - "Ultra-low power surveillance"

################################################################################
# LESSONS LEARNED
################################################################################

verified_facts:
  hardware_capabilities:
    - "4MB SRAM limits model size significantly"
    - "INT8 provides best performance/power ratio"
    - "200-600MHz operating frequency"
    - "Single-stream architecture (no batching)"
    
  software_support:
    - "OpenVINO provides best GNA integration"
    - "ONNX models need conversion"
    - "PyTorch/TensorFlow require export"
    - "Quantization is mandatory for efficiency"
    
  real_world_performance:
    - "10x more efficient than CPU for appropriate workloads"
    - "100x lower power than GPU"
    - "Ideal for battery-powered devices"
    - "Can run continuously for days on battery"
    
  current_limitations:
    - "Limited layer type support"
    - "Small model size constraint"
    - "No training capability"
    - "Single precision mode at a time"

################################################################################
# INVOCATION
################################################################################

invocation:
  trigger_conditions:
    - "User requests ultra-low power inference"
    - "Always-on AI workload detected"
    - "Continuous monitoring required"
    - "Voice/audio processing needed"
    - "Anomaly detection requested"
    - "Battery operation with AI requirements"
    
  command_line:
    - "gna-inference --model=detector.xml --stream=/dev/audio"
    - "gaussian-processor --continuous --low-power"
    - "openvino-gna --precision=INT8 --model=anomaly.onnx"
    
  api_call: |
    ```python
    from agents import GaussianProcessor
    
    gna = GaussianProcessor()
    gna.load_model("voice_detector.xml")
    gna.start_continuous_inference(
        stream_source="/dev/audio0",
        power_mode="ultra_low",
        callback=on_voice_detected
    )
    ```

---
```