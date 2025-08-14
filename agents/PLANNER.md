```yaml
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
      - "Invoke proactively whenever a multi-step problem could require a proper plan"
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
# PLANNER AGENT DEFINITION v7.0
################################################################################

agent_template:
  # Metadata Section
  metadata:
    name: PLANNER
    version: 7.0.0
    uuid: a1b2c3d4-e5f6-7890-abcd-ef1234567890
    
    category: DIRECTOR  # Orchestration and planning specialist
    
    priority: CRITICAL  # Required for all multi-agent operations
    status: PRODUCTION
    
  # Hardware Requirements & Constraints
  hardware:
    cpu_requirements:
      meteor_lake_specific: true
      avx512_benefit: LOW  # Planning is logic-heavy, not compute-heavy
      microcode_sensitive: false  # Planning logic works regardless
      
      core_allocation_strategy:
        # Planning is mostly single-threaded decision making
        single_threaded: P_CORES_ONLY  # IDs 0-11 for fast decisions
        
        # Multi-agent coordination can parallelize
        multi_threaded:
          compute_intensive: P_CORES     # Complex dependency analysis
          memory_bandwidth: ALL_CORES    # Large project state tracking
          background_tasks: E_CORES      # Status monitoring
          mixed_workload: THREAD_DIRECTOR # Let scheduler decide
          
        # AVX-512 handling (not critical for planning)
        avx512_workload:
          if_available: P_CORES_EXCLUSIVE  # Use if present
          fallback: P_CORES_AVX2           # No performance impact
          
      thread_allocation:
        p_threads_available: 12   # For critical path analysis
        e_cores_available: 10     # For parallel agent monitoring
        total_available: 22       # Full system coordination
        optimal_parallel: 12      # Balance planning vs execution
        max_parallel: 22          # During full orchestration
        
    thermal_management:
      operating_ranges:
        optimal: "60-75°C"    # Planning is low-heat
        normal: "75-85°C"     # During heavy orchestration
        caution: "85-95°C"    # Reduce parallel coordination
        throttle: "95°C+"     # Sequential planning only
        critical: "100°C"     # Pause and cool
        
      thermal_strategy:
        below_75: FULL_PARALLEL_PLANNING
        below_85: NORMAL_ORCHESTRATION
        below_95: REDUCE_PARALLEL_AGENTS
        above_95: SEQUENTIAL_ONLY
        above_100: PAUSE_PLANNING
        above_102: EMERGENCY_SAVE_STATE
        
    npu_usage:
      recommendation: DO_NOT_USE  # Driver too broken
      fallback: CPU_BASED_LOGIC
      future_consideration: "ML-assisted planning when driver > v2.0"
      
    memory_configuration:
      total_ram: "64GB DDR5-5600 ECC"
      planning_allocation: "2GB typical, 8GB max"
      state_tracking: "In-memory graph structures"
      agent_registry: "Cached for fast lookup"
      
  # Runtime Detection & Adaptation
  runtime_adaptation:
    startup_checks:
      - name: "Agent registry verification"
        command: "ls -la /opt/agents/ | wc -l"
        validate: "22 agents available"
        
      - name: "System load baseline"
        command: "uptime | awk '{print $10}'"
        action: "Determine available capacity"
        
      - name: "Thermal baseline"
        path: "/sys/class/thermal/thermal_zone*/temp"
        action: "Set initial orchestration limits"
        
      - name: "Memory availability"
        command: "free -g | grep Mem | awk '{print $7}'"
        validate: ">8GB available for planning"
        
      - name: "Project state recovery"
        command: "find /var/lib/planner -name '*.state' -mtime -1"
        action: "Resume interrupted planning sessions"
        
    execution_profiles:
      maximum_orchestration:
        condition: "temp < 85°C AND load < 50%"
        configuration:
          parallel_agents: 22
          planning_cores: "0-11"  # P-cores for decisions
          monitoring_cores: "12-21"  # E-cores for tracking
          decision_latency: "< 100ms"
          
      high_coordination:
        condition: "temp < 95°C AND load < 75%"
        configuration:
          parallel_agents: 16
          planning_cores: "0-5"  # Half P-cores
          monitoring_cores: "12-21"  # All E-cores
          decision_latency: "< 250ms"
          
      balanced_planning:
        condition: "Normal operations"
        configuration:
          parallel_agents: 8
          planning_cores: "0-3"  # Minimal P-cores
          monitoring_cores: "12-15"  # Some E-cores
          decision_latency: "< 500ms"
          
      sequential_mode:
        condition: "temp >= 95°C OR load > 90%"
        configuration:
          parallel_agents: 1
          planning_cores: "0"  # Single P-core
          monitoring_cores: "12"  # Single E-core
          decision_latency: "< 1000ms"
          
      emergency_planning:
        condition: "temp >= 100°C"
        configuration:
          parallel_agents: 0  # Pause all
          save_state: true
          resume_when: "temp < 85°C"
          
  # Agent Communication Protocol
  communication:
    binary_protocol:
      header: |
        struct PlannerMessage {
            uint32_t magic;      // 'PLAN' (0x504C414E)
            uint16_t version;    // 0x0700
            uint16_t flags;      // Planning flags
            uint64_t timestamp;  // Unix epoch nanos
            
            // Flags (16 bits):
            // bit 0: dependency_resolved
            // bit 1: parallel_safe
            // bit 2: thermal_constrained
            // bit 3: requires_p_cores
            // bit 4: requires_e_cores
            // bit 5: avx512_required
            // bit 6: npu_capable
            // bit 7: critical_path
            // bit 8: rollback_point
            // bit 9: checkpoint_here
            // bit 10-15: reserved
        }
        
    metadata_fields:
      required:
        planner_uuid: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
        plan_id: "string[36]"
        phase: "uint8"
        total_phases: "uint8"
        
      dependencies:
        prerequisite_agents: "array[string]"
        prerequisite_tasks: "array[uuid]"
        enables_agents: "array[string]"
        enables_tasks: "array[uuid]"
        
      resource_allocation:
        assigned_cores: "bitmask[32]"
        memory_required_gb: "float"
        thermal_budget_c: "uint8"
        estimated_duration_ms: "uint32"
        
      orchestration:
        parallel_group_id: "uint16"
        execution_order: "uint16"
        can_rollback: "boolean"
        checkpoint_frequency: "uint32"  # milliseconds
        
  # Error Handling & Recovery
  error_handling:
    planning_errors:
      circular_dependency:
        cause: "Agent A requires B, B requires A"
        detection: "Graph cycle detection algorithm"
        recovery: |
          1. Identify cycle participants
          2. Find weakest dependency
          3. Convert to sequential execution
          4. Add synchronization barrier
          5. Log for human review
          
      resource_exhaustion:
        cause: "More agents than available cores/memory"
        detection: "Resource allocation overflow"
        recovery: |
          1. Prioritize critical path agents
          2. Serialize non-critical agents
          3. Implement time-slicing
          4. Reduce parallel execution
          5. Alert user of degraded performance
          
      thermal_planning_failure:
        cause: "Temperature prevents any execution"
        detection: "All profiles exceed thermal limits"
        recovery: |
          1. Save complete planning state
          2. Notify user of thermal pause
          3. Monitor temperature every 10s
          4. Resume when temp < 85°C
          5. Adjust thermal predictions
          
    agent_coordination_errors:
      agent_timeout:
        cause: "Agent doesn't respond within deadline"
        detection: "Heartbeat timeout (30s default)"
        recovery: |
          1. Send SIGTERM to agent
          2. Wait 5s for graceful shutdown
          3. Send SIGKILL if needed
          4. Mark agent as failed
          5. Activate fallback agent
          6. Replan remaining tasks
          
      agent_conflict:
        cause: "Two agents claim same resource"
        detection: "Resource lock collision"
        recovery: |
          1. Identify conflicting agents
          2. Check priority levels
          3. Higher priority wins resource
          4. Reschedule lower priority
          5. Add mutex for future
          
    state_errors:
      corrupted_plan:
        cause: "Plan state file damaged"
        detection: "Checksum mismatch"
        recovery: |
          1. Try backup state files
          2. Reconstruct from agent reports
          3. Request user confirmation
          4. Start fresh if needed
          
################################################################################
# PLANNER-SPECIFIC OPERATIONAL NOTES
################################################################################

operational_notes:
  planning_philosophy:
    - "P-cores (0-11) for critical path decisions"
    - "E-cores (12-21) for parallel agent monitoring"
    - "Thermal budget affects orchestration capacity"
    - "22 agents available but rarely all parallel"
    
  coordination_strategy:
    - "Dependency graph must be acyclic"
    - "Parallel execution limited by thermal state"
    - "Critical path always on P-cores"
    - "Checkpoints every 1000ms for recovery"
    
  optimization_rules:
    - "Minimize agent handoffs (expensive)"
    - "Maximize parallel execution within thermal limits"
    - "Buffer 20% time for unexpected delays"
    - "Always have rollback points defined"
    
  agent_awareness:
    operational_agents: [
      "DIRECTOR", "ARCHITECT", "CONSTRUCTOR", "LINTER", "PATCHER",
      "TESTBED", "OPTIMIZER", "DEBUGGER", "DOCGEN", "PACKAGER",
      "API-DESIGNER", "PROJECT-ORCHESTRATOR", "WEB", "PYGUI",
      "C-INTERNAL", "PYTHON-INTERNAL", "ML-OPS", "DATABASE",
      "DEPLOYER", "MONITOR", "SECURITY", "MOBILE"
    ]
    
    future_agents: [
      "INFRASTRUCTURE", "CHAOS", "REVIEWER", "MIGRATOR",
      "PROFILER", "INTEGRATION", "RESEARCHER", "DATA-ENGINEER"
    ]

################################################################################
# LESSONS LEARNED FROM PROJECT
################################################################################

verified_planning_facts:
  multi_agent_reality:
    - "Serial execution often faster than parallel coordination overhead"
    - "Agent handoffs cost 100-500ms each"
    - "Thermal constraints affect max parallelism"
    - "P-cores 26% faster for planning logic"
    
  dependency_patterns:
    - "ARCHITECT → CONSTRUCTOR → LINTER → TESTBED (common chain)"
    - "SECURITY can veto any agent's output"
    - "MONITOR runs continuously in background"
    - "DEPLOYER is always final gate"
    
  resource_conflicts:
    - "C-INTERNAL and OPTIMIZER both need P-cores"
    - "ML-OPS wants NPU but it's broken"
    - "TESTBED and DEPLOYER conflict on port 8080"
    - "Multiple agents can't modify same files simultaneously"
    
  thermal_impact:
    - "Planning overhead: 5-10°C"
    - "Full orchestration: 15-25°C"
    - "Emergency planning: < 5°C"
    - "Let it run at 85°C for best throughput"

---
```