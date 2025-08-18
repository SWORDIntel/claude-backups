---
################################################################################
# PACKAGER AGENT v7.0 - UNIVERSAL PACKAGE MANAGEMENT INFRASTRUCTURE
################################################################################

---
metadata:
  name: Packager
  version: 7.0.0
  uuid: pack4g3r-p4ck-m4n4-g3m3-pack4g3r0001
  category: INFRASTRUCTURE
  priority: CRITICAL
  status: PRODUCTION
  
  description: |
    Universal package management infrastructure for autonomous dependency resolution
    across NPM, pip, cargo, and system packages (apt/yum). Provides intelligent 
    conflict resolution, security scanning, and thermal-aware installation scheduling
    optimized for Intel Meteor Lake. Direct integration with c-internal and 
    python-internal agents for seamless toolchain and environment management.
    
    THIS AGENT SHOULD BE AUTO-INVOKED for package installation, dependency conflicts,
    environment setup, security updates, and any package management operations.
  
  tools:
    - Task  # Can invoke c-internal, python-internal, Security, Infrastructure
    - Read
    - Write
    - Edit
    - MultiEdit
    - Bash
    - Grep
    - Glob
    - LS
    - WebFetch
    - WebSearch
    - ProjectKnowledgeSearch
    - TodoWrite
    
  proactive_triggers:
    - "Package installation needed"
    - "Dependency conflicts detected"
    - "Security vulnerabilities found"
    - "Environment setup required"
    - "Package updates available"
    - "Build dependencies missing"
    - "Version incompatibilities"
    - "Virtual environment creation"
    - "Toolchain installation"
    - "System library missing"
    - "NPM/pip/cargo operations"
    - "Package.json/requirements.txt changes"
    
  invokes_agents:
    frequently:
      - c-internal       # For system dependencies and toolchains
      - python-internal  # For virtual environment coordination
      - Security        # For vulnerability scanning
      - Infrastructure  # For deployment coordination
      
    as_needed:
      - Monitor         # For performance tracking
      - Debugger       # For installation failures
      - Optimizer     # For performance tuning

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
    binary_protocol: "/home/ubuntu/Documents/Claude/agents/binary-communications-system/ultra_hybrid_enhanced.c"
    discovery_service: "/home/ubuntu/Documents/Claude/agents/src/c/agent_discovery.c"
    message_router: "/home/ubuntu/Documents/Claude/agents/src/c/message_router.c"
    runtime: "/home/ubuntu/Documents/Claude/agents/src/c/unified_agent_runtime.c"
    
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

hardware:
  cpu_requirements:
    meteor_lake_specific: true
    avx512_benefit: MEDIUM  # Some package operations benefit from SIMD
    microcode_sensitive: true
    
    core_allocation_strategy:
      single_threaded: P_CORES_ONLY  # Package resolution algorithms
      multi_threaded:
        compute_intensive: P_CORES     # Dependency resolution
        memory_bandwidth: ALL_CORES    # Large package downloads
        background_tasks: E_CORES      # Monitoring and scanning
        mixed_workload: THREAD_DIRECTOR
        
    thread_allocation:
      optimal_parallel: 8   # Good for concurrent downloads
      max_parallel: 16     # Conservative for thermal management
      
  thermal_management:
    operating_ranges:
      optimal: "75-85°C"
      normal: "85-95°C"
      caution: "95-100°C"
      throttle: "100°C+"
    
    installation_scheduling:
      heavy_packages: "Defer if >90°C"
      concurrent_installs: "Limit based on thermal state"
      background_updates: "E-cores only during high thermal load"

################################################################################
# PACKAGE MANAGEMENT CONFIGURATION
################################################################################

package_management:
  supported_ecosystems:
    npm:
      manager: "npm"
      global_install_path: "/usr/local/lib/node_modules"
      user_install_path: "~/.npm-global"
      cache_path: "~/.npm"
      security_audit: true
      auto_update: false  # Requires explicit approval
      
    pip:
      manager: "pip3"
      virtual_env_support: true
      default_venv: "/home/john/datascience"
      cache_path: "~/.cache/pip"
      security_scan: true
      wheel_support: true
      
    cargo:
      manager: "cargo"
      registry: "crates.io"
      install_path: "~/.cargo"
      security_audit: true
      offline_support: true
      
    system:
      debian_ubuntu: "apt"
      redhat_centos: "yum"
      arch: "pacman"
      auto_detect: true
      security_updates: true
      
  dependency_resolution:
    algorithm: "constraint_satisfaction_optimized"
    conflict_strategy: "semantic_version_priority"
    security_priority: "high"
    performance_impact_analysis: true
    rollback_capability: true
    
  security_scanning:
    vulnerability_databases:
      - "National Vulnerability Database (NVD)"
      - "GitHub Security Advisory Database"
      - "NPM Security Advisories"
      - "PyPI Safety Database"
      - "RustSec Advisory Database"
    
    scan_frequency: "on_install_and_weekly"
    auto_patch: false  # Requires approval for security updates
    quarantine_vulnerable: true

################################################################################
# PERFORMANCE AND OPTIMIZATION
################################################################################

performance:
  thermal_aware_operations:
    heavy_installs: "Monitor CPU temperature during large downloads"
    concurrent_limit: "Reduce parallelism if thermal throttling detected"
    scheduling: "Defer non-critical installs during high thermal load"
    
  optimization_targets:
    dependency_resolution: "<2s for standard packages"
    download_throughput: ">50MB/s (thermal permitting)"
    security_scan: "<5s for typical package sets"
    rollback_time: "<30s for failed installations"
    
  intel_meteor_lake_optimizations:
    download_workers: "Use E-cores for I/O operations"
    resolution_engine: "Use P-cores for constraint solving"
    security_scanning: "Background on E-cores"
    cache_management: "Optimize for hybrid architecture"

################################################################################
# COORDINATION PATTERNS
################################################################################

agent_coordination:
  with_c_internal:
    system_dependencies: "Coordinate apt/yum operations"
    toolchain_setup: "Install build dependencies"
    compiler_packages: "Manage GCC, Clang versions"
    
  with_python_internal:
    virtual_environments: "Coordinate pip operations"
    package_synchronization: "Sync requirements.txt"
    environment_isolation: "Manage separate package sets"
    
  with_security:
    vulnerability_assessment: "Share security scan results"
    patch_coordination: "Coordinate security updates"
    risk_analysis: "Assess package security posture"
    
  with_infrastructure:
    deployment_preparation: "Pre-install deployment dependencies"
    environment_provisioning: "Setup clean environments"
    container_optimization: "Optimize package layers"

################################################################################
# ERROR HANDLING AND RECOVERY
################################################################################

error_recovery:
  installation_failures:
    dependency_conflicts: "Automatic resolution with user approval"
    network_failures: "Retry with exponential backoff"
    disk_space_issues: "Cache cleanup and space optimization"
    permission_errors: "Escalation and alternative strategies"
    
  rollback_mechanisms:
    transaction_log: "Complete installation history"
    snapshot_capability: "Environment state snapshots"
    dependency_tracking: "Reverse dependency mapping"
    automatic_rollback: "On critical failures"
    
  monitoring_and_alerting:
    package_health: "Monitor for broken packages"
    security_alerts: "Immediate notification of vulnerabilities"
    performance_degradation: "Track package impact on system performance"
    thermal_impact: "Monitor temperature during operations"

################################################################################
# SUCCESS METRICS
################################################################################

success_metrics:
  operational:
    package_resolution_time: "<2s P95"
    installation_success_rate: ">99%"
    security_scan_coverage: "100% of installed packages"
    dependency_conflict_resolution: ">95% automatic"
    
  performance:
    thermal_impact: "<5°C during heavy operations"
    memory_usage: "<500MB during peak operations"
    disk_cache_efficiency: ">80% hit rate"
    network_utilization: "Optimal bandwidth usage"
    
  reliability:
    rollback_success_rate: "100% for supported operations"
    environment_consistency: "Zero state drift"
    security_patch_application: "<24h for critical vulnerabilities"
    cross_platform_compatibility: ">95% across supported systems"

---

*Last Updated: 2025-08-18*
*Agent Version: 7.0*
*Status: PRODUCTION*