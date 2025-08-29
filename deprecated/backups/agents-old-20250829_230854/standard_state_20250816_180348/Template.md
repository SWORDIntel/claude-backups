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
# COMPREHENSIVE AGENT DEFINITION TEMPLATE v7.0
################################################################################

agent_template:
  # Metadata Section
  metadata:
    name: AgentName
    version: 7.0.0
    uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    
    # Agent categories from actual project
    category: |
      C-INTERNAL      # C/C++ systems programming
      PYTHON-INTERNAL # Python/ML/AI development
      TESTBED        # Testing infrastructure
      PATCHER        # Bug fixes and patches
      DEPLOYER       # Deployment operations
      INFRASTRUCTURE # System setup/config
      DIRECTOR       # Orchestration
      SECURITY       # Security analysis
      MONITOR        # Observability
      DATABASE       # Data architecture
      API-DESIGNER   # API development
      WEB           # Frontend development
      ML-OPS        # ML operations
      
    priority: CRITICAL|HIGH|MEDIUM|LOW
    status: PRODUCTION|BETA|EXPERIMENTAL|DEPRECATED
    
  # Hardware Requirements & Constraints
  hardware:
    cpu_requirements:
      meteor_lake_specific: true
      avx512_benefit: HIGH|MEDIUM|LOW|NONE
      microcode_sensitive: true|false
      
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
      recommendation: DO_NOT_USE  # Driver too broken
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
        
      - name: "Thermal baseline"
        path: "/sys/class/thermal/thermal_zone*/temp"
        action: "Establish operating temperature"
        
      - name: "ZFS pool status"
        command: "zpool status -v"
        validate: "Pool healthy and imported"
        
    execution_profiles:
      maximum_performance:
        condition: "AVX-512 available AND temp < 95°C"
        configuration:
          cores: "0-11"  # P-cores only
          compiler_flags: "-march=native -mavx512f -O3 -fopenmp"
          governor: "performance"
          
      high_performance:
        condition: "Modern microcode (AVX2 only) AND temp < 95°C"
        configuration:
          cores: "0-11"  # P-cores still faster
          compiler_flags: "-march=alderlake -mavx2 -O3 -fopenmp"
          governor: "performance"
          
      balanced:
        condition: "Normal operations, temp < 100°C"
        configuration:
          cores: "0-21"  # All 22 cores
          compiler_flags: "-march=alderlake -O2"
          governor: "schedutil"
          
      efficiency:
        condition: "Battery power OR low-priority tasks"
        configuration:
          cores: "12-21"  # E-cores only
          compiler_flags: "-march=alderlake -Os"
          governor: "powersave"
          
      thermal_protection:
        condition: "temp >= 100°C"
        configuration:
          cores: "12-21"  # E-cores only
          compiler_flags: "-O1"
          governor: "powersave"
          stop_p_core_tasks: true
          
  # Agent Communication Protocol
  communication:
    binary_protocol:
      header: |
        struct AgentMessage {
            uint32_t magic;      // 'CL7D' (0x434C3744)
            uint16_t version;    // 0x0700
            uint16_t flags;      // Status flags
            uint64_t timestamp;  // Unix epoch nanos
            
            // Flags (16 bits):
            // bit 0: compression_enabled
            // bit 1: encryption_enabled
            // bit 2: high_priority
            // bit 3: requires_ack
            // bit 4: thermal_throttled
            // bit 5: avx512_capable
            // bit 6: p_cores_only
            // bit 7: e_cores_only
            // bit 8-15: reserved
        }
        
    metadata_fields:
      required:
        agent_uuid: "string[36]"
        target_uuid: "string[36]"
        correlation_id: "string[36]"
        
      performance:
        cpu_temp: "uint8"       # Current celsius
        core_mask: "uint32"     # Active cores bitmap
        memory_used_gb: "float"
        
      capabilities:
        instruction_set: "AVX512|AVX2|SSE4"
        npu_available: "boolean"
        zfs_healthy: "boolean"
        
  # Error Handling & Recovery
  error_handling:
    cpu_errors:
      illegal_instruction:
        cause: "AVX-512 instruction on E-core or modern microcode"
        detection: "SIGILL signal trap"
        recovery: |
          1. Catch SIGILL in handler
          2. Log failing instruction
          3. Mark AVX-512 unavailable
          4. Restart with AVX2 codepath
          5. Pin to safe cores if needed
          
      thermal_emergency:
        cause: "Temperature >= 103°C"
        detection: "Thermal zone monitoring"
        recovery: |
          1. SIGTERM all P-core processes
          2. Force migration to E-cores
          3. Set powersave governor
          4. If temp >= 105°C, sync and prepare for shutdown
          
    npu_errors:
      unsupported_operation:
        cause: "Driver v1.17.0 limitations"
        detection: "ZE_RESULT_ERROR_UNSUPPORTED_FEATURE"
        recovery: "Immediate CPU fallback, no retry"
        
    zfs_errors:
      pool_import_failure:
        cause: "Hostid mismatch or encryption key"
        detection: "zpool import failure"
        recovery: |
          1. Check /etc/hostid matches pool
          2. Verify encryption key available
          3. Try force import with -f
          4. Check zpool.cache presence

################################################################################
# CRITICAL OPERATIONAL NOTES
################################################################################

operational_notes:
  performance:
    - "P-cores (0-11) are ALWAYS faster for single-thread work"
    - "Use all 22 cores only for highly parallel workloads"
    - "AVX-512 provides 60% speedup but requires ancient microcode"
    - "Thermal throttling only begins at 100°C, not before"
    
  reliability:
    - "ZFS encryption requires exact hostid match"
    - "Boot parameters must include root=ZFS format"
    - "NPU should be ignored until driver updates"
    - "Network is stable after proper driver inclusion"
    
  optimization:
    - "Compile with -march=alderlake for safety"
    - "Use -mno-avx512f to prevent E-core crashes"
    - "Let system run at 85-95°C for best performance"
    - "Profile actual workload for core assignment"

################################################################################
# LESSONS LEARNED FROM PROJECT
################################################################################

verified_facts:
  cpu_topology:
    - "6 P-cores with HT = 12 logical cores (0-11)"
    - "10 E-cores = 10 logical cores (12-21)"
    - "Total = 22 logical cores, not 20"
    
  performance_reality:
    - "AVX-512 vs AVX2 is 119 vs 75 GFLOPS (verified)"
    - "P-cores 26% faster than E-cores even without AVX-512"
    - "5GHz turbo exists but hard to sustain (power/thermal limits)"
    
  thermal_behavior:
    - "85°C is normal, not concerning"
    - "System designed for sustained 90°C operation"
    - "Throttling minimal until 100°C"
    
  driver_status:
    - "NPU driver 1.17.0 mostly broken"
    - "Network I219-LM works fine with proper drivers"
    - "ZFS native encryption fully functional"

---
