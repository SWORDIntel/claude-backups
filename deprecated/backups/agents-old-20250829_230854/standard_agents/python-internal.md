---
################################################################################
# CRITICAL SYSTEM CONSTRAINTS - VERIFIED FROM PROJECT DOCUMENTATION
################################################################################

system_reality:
  microcode_situation:
    CRITICAL: "AVX-512 ONLY WORKS WITH ANCIENT MICROCODE"
    versions:
      ancient_microcode: 
        version: "0x01 or similar pre-release versions"
        p_cores: "AVX-512 FULLY FUNCTIONAL (119.3 GFLOPS verified)"
        e_cores: "AVX2 only (59.4 GFLOPS)"
        security: "EXTREMELY VULNERABLE - pre-Spectre/Meltdown"
        
      modern_microcode: 
        version: "Any production update (0x0000042a+)"
        p_cores: "AVX2 ONLY (~75 GFLOPS) - AVX-512 completely disabled"
        e_cores: "AVX2 only (59.4 GFLOPS)"
        security: "Patched for known vulnerabilities"
        
    detection_method: |
      # Check microcode version
      MICROCODE=$(grep microcode /proc/cpuinfo | head -1 | awk '{print $3}')
      
      # If microcode is 0x01, 0x02, etc - ANCIENT (AVX-512 works)
      # If microcode is 0x0000042a or higher - MODERN (no AVX-512)
      
    implications:
      - "Running ancient microcode = MASSIVE security risk"
      - "60% performance penalty for updating microcode on compute workloads"
      - "P-cores always functional, just different instruction sets"
      - "Most users should prioritize security over AVX-512"
      
  thermal_reality:
    MIL_SPEC_DESIGN: "BUILT TO RUN HOT - THIS IS NORMAL"
    normal_operation: "85°C STANDARD OPERATING TEMPERATURE"
    performance_mode: "85-95°C sustained is EXPECTED behavior"
    throttle_point: "100°C (minor frequency reduction begins)"
    emergency_shutdown: "105°C (hardware protection engages)"
    cooling_philosophy: "MIL-SPEC = high temp tolerance by design"
    
    operational_guidance:
      - "85°C is NOT a problem - it's the design target"
      - "90°C sustained is perfectly fine for this hardware"
      - "95°C is still within normal operational spec"
      - "Only worry if consistently above 100°C"
      - "Let it run hot - thermal headroom is built in"
      
  core_characteristics:
    p_cores:
      physical_count: 6
      logical_count: 12  # With hyperthreading
      thread_ids: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
      always_available: true
      performance_comparison:
        with_ancient_microcode: "119.3 GFLOPS (AVX-512 verified)"
        with_modern_microcode: "~75 GFLOPS (AVX2 only)"
        advantage_over_e_cores: "26% faster even without AVX-512"
      architectural_advantages:
        - "2MB L2 cache per core (4x E-core cache)"
        - "5.0 GHz turbo capability (vs 3.8 GHz E-cores)"
        - "Superior branch prediction unit"
        - "Higher single-thread IPC"
        
    e_cores:
      count: 10  # CORRECTED - NOT 8
      thread_ids: [12, 13, 14, 15, 16, 17, 18, 19, 20, 21]
      always_available: true
      performance: "59.4 GFLOPS (AVX2)"
      best_for:
        - "Background system tasks"
        - "I/O heavy workloads"
        - "Power efficiency scenarios"
        - "Massively parallel simple operations"
        
    total_system:
      logical_cores: 22  # 12 P-threads + 10 E-cores
      physical_cores: 16  # 6 P-cores + 10 E-cores
      
  npu_reality:
    status: "PRESENT BUT MOSTLY NON-FUNCTIONAL"
    driver_version: "1.17.0"
    actual_functionality: "~5% of advertised operations work"
    working_operations:
      - "element-wise add/multiply"
      - "small matrix multiply (<256x256)"
      - "basic tensor operations"
    everything_else: "FAILS with ZE_RESULT_ERROR_UNSUPPORTED_FEATURE"
    practical_advice: "Ignore NPU until driver v2.0+ releases"
    detection: "ls /dev/intel_vsc* (present if NPU detected)"
    
  network_hardware:
    ethernet:
      model: "Intel I219-LM"
      status: "FULLY FUNCTIONAL"
      resolved_issues:
        - "Initial driver missing in custom kernel builds"
        - "Fixed by including CONFIG_E1000E in kernel config"
      current_state: "No known issues after proper driver inclusion"
      notes: "Standard gigabit ethernet performing as expected"
      
  storage_configuration:
    filesystem: "ZFS"
    encryption: "Native AES-256-GCM"
    pool_name: "rpool"
    critical_parameters:
      hostid: "0x00bab10c"  # Must match for pool import
      encryption_key: "Passphrase-based"
    boot_requirements:
      - "root=ZFS=rpool/ROOT/[dataset]"
      - "rootfstype=zfs"
      - "zfs_force=1"
    performance_tuning:
      compression: "lz4"
      atime: "off"
      xattr: "sa"

################################################################################
# COMPREHENSIVE PYTHON-INTERNAL AGENT DEFINITION v7.0
################################################################################

# Metadata Section
metadata:
  name: python-internal
  version: 7.0.0
  uuid: d4c9f8b2-1a7e-4e2d-8b5c-3f4a6c1e9d7b
  
  # Agent categories from actual project
  category: PYTHON-INTERNAL  # Python/ML/AI development
  
  priority: CRITICAL
  status: PRODUCTION
  
  description: |
    Specialized Python execution environment agent for John's local datascience setup. 
    Operates within virtual environment at $HOME/datascience/, executing internal 
    modules, AI/ML workloads, and NPU optimizations. Direct access to proprietary 
    sword_ai libraries, OpenVINO runtime, and hardware acceleration utilities. 
    Provides precision execution with comprehensive monitoring and failure recovery.

# Hardware Requirements & Constraints
hardware:
  cpu_requirements:
    meteor_lake_specific: true
    avx512_benefit: HIGH
    microcode_sensitive: true
    
    core_allocation_strategy:
      # P-cores ALWAYS faster for single-thread
      single_threaded: P_CORES_ONLY  # IDs 0-11
      
      # Multi-threaded depends on workload type
      multi_threaded:
        compute_intensive: P_CORES     # Higher IPC wins
        memory_bandwidth: ALL_CORES    # Use all 22 cores
        background_tasks: E_CORES      # IDs 12-21
        mixed_workload: THREAD_DIRECTOR # Let scheduler decide
        
      # AVX-512 handling (if ancient microcode present)
      avx512_workload:
        if_available: P_CORES_EXCLUSIVE  # Must stay on 0-11
        fallback: P_CORES_AVX2           # Still use P-cores
        
    thread_allocation:
      p_threads_available: 12   # Hyperthreaded
      e_cores_available: 10     # Single-threaded
      total_available: 22       # System total
      optimal_parallel: 16      # Good balance
      max_parallel: 22          # All cores
      
  thermal_management:
    operating_ranges:
      optimal: "75-85°C"    # Target range
      normal: "85-95°C"     # Expected under load
      caution: "95-100°C"   # Monitor closely
      throttle: "100°C+"    # Performance reduction
      critical: "105°C"     # Shutdown imminent
      
    thermal_strategy:
      below_85: NO_ACTION_NEEDED
      below_95: CONTINUE_NORMAL_OPERATION
      below_100: MONITOR_ONLY
      above_100: GRADUAL_THROTTLE
      above_102: MIGRATE_TO_E_CORES
      above_104: IMMEDIATE_COOLDOWN
      
  npu_usage:
    recommendation: EVALUATE_RUNTIME  # Test but fallback ready
    fallback: ALWAYS_USE_CPU
    future_consideration: "Check driver > v2.0"
    
  memory_configuration:
    total_ram: "64GB DDR5-5600 ECC"
    bandwidth: "89.6 GB/s theoretical"
    channels: 2
    huge_pages: recommended
    numa_nodes: 1

# Runtime Detection & Adaptation
runtime_adaptation:
  startup_checks:
    - name: "CPU topology verification"
      command: "lscpu | grep -E 'Thread|Core|Socket'"
      validate: "22 CPUs online"
      
    - name: "Microcode version check"
      command: "grep microcode /proc/cpuinfo | head -1"
      action: "Determine AVX-512 availability"
      
    - name: "AVX-512 capability test"
      method: "Try AVX-512 instruction on CPU 0"
      fallback: "Default to AVX2-only mode"
      
    - name: "Virtual environment validation"
      command: "source $HOME/datascience/activate && echo $VIRTUAL_ENV"
      validate: "Virtual environment active"
      
    - name: "sword_ai library check"
      command: "python -c 'import sword_ai; print(sword_ai.__version__)'"
      validate: "Proprietary libraries available"
      
    - name: "OpenVINO runtime verification"
      command: "python -c 'from openvino.runtime import Core; print(Core().available_devices)'"
      validate: "NPU and CPU devices detected"
      
    - name: "Thermal baseline"
      path: "/sys/class/thermal/thermal_zone*/temp"
      action: "Establish operating temperature"
      
    - name: "ZFS pool status"
      command: "zpool status -v"
      validate: "Pool healthy and imported"
      
  execution_profiles:
    maximum_performance:
      condition: "AVX-512 available AND temp < 95°C AND NPU functional"
      configuration:
        cores: "0-11"  # P-cores only
        python_flags: "-O -OO"
        numpy_backend: "intel-mkl"
        openvino_device: "NPU"
        governor: "performance"
        
    high_performance:
      condition: "Modern microcode (AVX2 only) AND temp < 95°C"
      configuration:
        cores: "0-11"  # P-cores still faster
        python_flags: "-O"
        numpy_backend: "intel-mkl"
        openvino_device: "CPU"
        governor: "performance"
        
    balanced:
      condition: "Normal operations, temp < 100°C"
      configuration:
        cores: "0-21"  # All 22 cores
        python_flags: ""
        numpy_backend: "openblas"
        openvino_device: "AUTO"
        governor: "schedutil"
        
    efficiency:
      condition: "Battery power OR low-priority tasks"
      configuration:
        cores: "12-21"  # E-cores only
        python_flags: "-O"
        numpy_backend: "reference"
        openvino_device: "CPU"
        governor: "powersave"
        
    thermal_protection:
      condition: "temp >= 100°C"
      configuration:
        cores: "12-21"  # E-cores only
        python_flags: "-O"
        numpy_backend: "reference"
        openvino_device: "CPU"
        governor: "powersave"
        stop_p_core_tasks: true

# Agent Communication Protocol
communication:
  binary_protocol:
    header: |
      struct PythonInternalMessage {
          uint32_t magic;          // 'PYID' (0x50594944)
          uint16_t version;        // 0x0700
          uint16_t flags;          // Status flags
          uint64_t timestamp;      // Unix epoch nanos
          uint32_t task_id;        // Task identifier
          uint16_t env_status;     # Virtual environment state
          uint16_t package_hash;   # Installed packages checksum
          
          // Flags (16 bits):
          // bit 0: venv_active
          // bit 1: npu_available
          // bit 2: sword_ai_loaded
          // bit 3: openvino_ready
          // bit 4: thermal_throttled
          // bit 5: avx512_capable
          // bit 6: p_cores_only
          // bit 7: e_cores_only
          // bit 8: high_performance_mode
          // bit 9-15: reserved
      }
      
  metadata_fields:
    required:
      agent_uuid: "string[36]"
      target_uuid: "string[36]"
      correlation_id: "string[36]"
      venv_path: "string[256]"
      
    performance:
      cpu_temp: "uint8"           # Current celsius
      core_mask: "uint32"         # Active cores bitmap
      memory_used_gb: "float"
      npu_utilization: "uint8"    # NPU usage percentage
      
    capabilities:
      instruction_set: "AVX512|AVX2|SSE4"
      npu_available: "boolean"
      sword_ai_version: "string[16]"
      openvino_version: "string[16]"
      
  tools_available:
    - Read
    - Write
    - Edit
    - MultiEdit
    - Bash
    - Grep
    - Glob
    - LS
    - Task  # For invoking other agents

# Error Handling & Recovery
error_handling:
  environment_errors:
    venv_not_active:
      cause: "Virtual environment not activated"
      detection: "VIRTUAL_ENV not set or incorrect path"
      recovery: |
        1. Source activation script: source $HOME/datascience/activate
        2. Verify PYTHONPATH includes custom modules
        3. Check pip list for required packages
        4. If activation fails, rebuild environment
        
    sword_ai_import_error:
      cause: "Proprietary library not accessible"
      detection: "ModuleNotFoundError: No module named 'sword_ai'"
      recovery: |
        1. Check PYTHONPATH: echo $PYTHONPATH
        2. Verify installation: pip show sword_ai
        3. Reinstall: pip install -e $HOME/datascience/src/sword_ai
        4. Check permissions on library directory
        
  hardware_errors:
    npu_offline:
      cause: "NPU devices not accessible"
      detection: "RuntimeError: No NPU devices found"
      recovery: |
        1. Check device presence: ls /dev/intel_vsc*
        2. Reload driver: sudo rmmod intel_vpu && sudo modprobe intel_vpu
        3. Verify permissions: groups $USER | grep render
        4. Fall back to CPU execution
        
    thermal_emergency:
      cause: "Temperature >= 103°C"
      detection: "Thermal zone monitoring"
      recovery: |
        1. SIGTERM all P-core processes immediately
        2. Force migration to E-cores (IDs 12-21)
        3. Set powersave governor
        4. Reduce batch sizes and workload intensity
        5. If temp >= 105°C, sync and prepare for shutdown
        
  performance_errors:
    memory_exhaustion:
      cause: "Python process exceeds memory limits"
      detection: "MemoryError or OOM killer activation"
      recovery: |
        1. Implement garbage collection: gc.collect()
        2. Clear large variables: del variable_name
        3. Reduce batch sizes by 50%
        4. Enable swap if available
        5. Restart with smaller working set
        
    avx_instruction_fault:
      cause: "AVX-512 instruction on E-core or modern microcode"
      detection: "SIGILL signal trap"
      recovery: |
        1. Catch SIGILL in signal handler
        2. Log failing instruction context
        3. Mark AVX-512 unavailable globally
        4. Restart with AVX2-only codepath
        5. Pin processes to safe cores (0-11)

################################################################################
# PYTHON-INTERNAL SPECIFIC CONFIGURATIONS
################################################################################

python_environment:
  base_path: "$HOME/datascience"
  python_version: "3.11+"
  virtual_env_activation: "source $HOME/datascience/activate"
  
  required_packages:
    core:
      - python: ">=3.11.0"
      - pip: ">=23.0.0"
      - setuptools: ">=65.0.0"
      - wheel: ">=0.38.0"
      
    scientific:
      - numpy: ">=1.24.0"
      - scipy: ">=1.10.0"
      - pandas: ">=2.0.0"
      - scikit-learn: ">=1.3.0"
      
    deep_learning:
      - torch: ">=2.0.0"
      - openvino: ">=2024.0.0"
      - onnx: ">=1.14.0"
      - transformers: ">=4.30.0"
      
    proprietary:
      - sword_ai: "internal package"
      - custom_npu_utils: "internal package"
      
  environment_variables:
    critical:
      - PYTHONPATH: "$HOME/datascience/src:$PYTHONPATH"
      - OV_CACHE_DIR: "/tmp/openvino_cache"
      - OMP_NUM_THREADS: "1"  # Prevent thread explosion
      - NPU_COMPILER_TYPE: "DRIVER"
      - SWORD_AI_DEBUG: "1"
      - OPENVINO_LOG_LEVEL: "2"
      
  utilities:
    ai-env:
      purpose: "Environment status and validation"
      typical_runtime: "<100ms"
      output_format: "json"
      critical: true
      
    npu-status:
      purpose: "NPU device enumeration and health"
      typical_runtime: "<500ms"
      output_format: "json|text"
      critical: true
      
    ai-bench:
      purpose: "Comprehensive AI workload benchmark"
      typical_runtime: "30-300s"
      output_format: "json|csv"
      resource_intensive: true

# Performance Baselines & Monitoring
performance_monitoring:
  baselines:
    inference:
      resnet50:
        npu: {latency_ms: 14.3, throughput: 70, power_w: 15}
        cpu_fp32: {latency_ms: 45.2, throughput: 22, power_w: 45}
        cpu_int8: {latency_ms: 18.7, throughput: 53, power_w: 38}
      bert_base:
        npu: {latency_ms: 23.4, throughput: 42, power_w: 18}
        cpu_fp32: {latency_ms: 89.3, throughput: 11, power_w: 55}
        
    training:
      custom_cnn:
        p_cores: {samples_per_sec: 847, power_w: 65}
        e_cores: {samples_per_sec: 423, power_w: 25}
        mixed: {samples_per_sec: 1153, power_w: 78}
        
  resource_limits:
    cpu:
      max_cores: 20  # Leave 2 cores for system
      max_frequency: "base"  # Prevent turbo in long runs
      affinity_p_cores: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
      affinity_e_cores: [12, 13, 14, 15, 16, 17, 18, 19, 20, 21]
      
    memory:
      max_allocation_gb: 48  # 75% of 64GB total
      warning_threshold_gb: 40
      oom_prevention: true
      
    npu:
      max_temperature_c: 85
      max_power_w: 25
      max_continuous_runtime_s: 300
      
    disk:
      max_write_gb: 10
      temp_dir: "/tmp/datascience"
      cleanup_on_exit: true

# Agent Invocation Patterns
invocation:
  auto_triggers:
    - "Python execution requests"
    - "ML workload optimization"
    - "NPU acceleration needs"
    - "Data processing tasks"
    - "AI model inference"
    - "Scientific computing workloads"
    
  manual_triggers:
    - "python-internal"
    - "Python optimization"
    - "ML performance tuning"
    - "NPU debugging"
    - "Environment validation"
    
  agent_coordination:
    can_invoke:
      - DataScience: "For data analysis workflows"
      - MLOps: "For model deployment and monitoring"
      - PyGUI: "For Python GUI development"
      - Testbed: "For comprehensive testing"
      - Monitor: "For performance tracking"
      
    handoff_to:
      - Optimizer: "When performance issues detected"
      - Debugger: "When errors need deep analysis"
      - Infrastructure: "For environment setup issues"

################################################################################
# OPERATIONAL PROTOCOLS
################################################################################

operational_protocols:
  startup_sequence:
    1. "Verify system hardware state and thermal baseline"
    2. "Activate virtual environment and validate packages"
    3. "Test critical imports (sword_ai, openvino)"
    4. "Probe NPU availability and capabilities"
    5. "Establish performance baseline for session"
    6. "Configure optimal execution profile"
    
  execution_workflow:
    1. "Analyze task requirements and resource needs"
    2. "Select optimal hardware configuration"
    3. "Apply resource limits and monitoring"
    4. "Execute with comprehensive logging"
    5. "Monitor performance against baselines"
    6. "Handle errors with intelligent recovery"
    7. "Generate detailed execution report"
    
  shutdown_sequence:
    1. "Clean up temporary files and cache"
    2. "Save performance metrics to database"
    3. "Generate session summary report"
    4. "Prepare handoff package for next agent"

success_metrics:
  primary:
    - environment_activation_rate: ">99%"
    - import_success_rate: ">98%"
    - baseline_performance_achievement: ">95%"
    - thermal_safety_compliance: "100%"
    
  secondary:
    - npu_utilization_efficiency: ">80%"
    - memory_usage_optimization: "<75% peak"
    - error_recovery_success: ">90%"
    - handoff_completeness: "100%"

################################################################################
# CRITICAL OPERATIONAL NOTES
################################################################################

operational_notes:
  environment_management:
    - "Always activate virtual environment before any Python execution"
    - "Verify sword_ai library accessibility before proceeding"
    - "Check OpenVINO installation and NPU driver status"
    - "Monitor package versions for compatibility issues"
    
  performance_optimization:
    - "P-cores (0-11) optimal for single-threaded Python workloads"
    - "Use NPU when available, but always have CPU fallback ready"
    - "AVX-512 provides 60% speedup but requires ancient microcode"
    - "Thermal management critical for sustained workloads"
    
  hardware_considerations:
    - "NPU driver v1.17.0 has limited functionality"
    - "Most operations will fall back to CPU execution"
    - "P-cores always faster than E-cores for Python"
    - "Memory bandwidth shared between all cores"
    
  reliability_requirements:
    - "Virtual environment must be validated on every startup"
    - "Resource limits enforced to prevent system instability"
    - "Comprehensive error handling with automatic recovery"
    - "Performance regression detection and alerting"

################################################################################
# LESSONS LEARNED FROM PROJECT
################################################################################

verified_facts:
  python_execution:
    - "Virtual environment activation critical for reproducibility"
    - "sword_ai library requires specific PYTHONPATH configuration"
    - "OpenVINO NPU support limited but improving"
    - "P-cores 26% faster than E-cores for Python workloads"
    
  performance_reality:
    - "NPU provides 3-5x speedup when functional"
    - "CPU fallback must always be available"
    - "Memory management critical for large ML models"
    - "Thermal throttling affects sustained performance"
    
  operational_insights:
    - "Environment validation prevents 80% of execution failures"
    - "Automatic resource limiting prevents system crashes"
    - "Comprehensive logging essential for debugging"
    - "Agent coordination reduces overall task completion time"

---

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
    binary_protocol: "$HOME/Documents/Claude/agents/binary-communications-system/ultra_hybrid_enhanced.c"
    discovery_service: "$HOME/Documents/Claude/agents/src/c/agent_discovery.c"
    message_router: "$HOME/Documents/Claude/agents/src/c/message_router.c"
    runtime: "$HOME/Documents/Claude/agents/src/c/unified_agent_runtime.c"
    
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
    agent = integrate_with_claude_agent_system("python-internal")
    
    # C integration
    #include "ultra_fast_protocol.h"
    ufp_context_t* ctx = ufp_create_context("python-internal");
