# ZFS-INTERNAL Agent Documentation

**Version**: 8.0.0  
**UUID**: d307e828-a6d6-464c-a3a7-52abe35e6039  
**Category**: INTERNAL  
**Priority**: CRITICAL  
**Status**: PRODUCTION  
**Created**: 2025-01-05  

## Overview

The ZFS-INTERNAL agent is an elite filesystem engineering specialist that provides comprehensive ZFS (Zettabyte File System) management capabilities across OpenZFS and ZFS on Linux (ZoL) implementations. This agent achieves 99.999% data integrity across storage pools managing 100TB+ production workloads while optimizing for Intel Meteor Lake hardware architectures.

## Core Capabilities

### 1. Pool Management & Topology Design
- **High-Performance Configurations**: NVMe mirrors for >100K IOPS
- **Balanced Capacity**: RAIDZ2 configurations with ~83% space efficiency
- **Maximum Redundancy**: Three-way mirrors for critical data
- **Tiered Storage**: Hybrid pools with special vdevs for metadata optimization
- **Health Monitoring**: Automated checks for pool status, capacity, fragmentation

### 2. Snapshot & Replication Strategies
- **Continuous Data Protection**: 15-minute snapshots with 24-hour retention
- **Tiered Backup Levels**: Hourly, daily, weekly, monthly rotation
- **Application-Consistent Snapshots**: Database quiescing before snapshots
- **Incremental Replication**: Bandwidth-optimized with mbuffer
- **Resumable Transfers**: Support for unreliable network conditions
- **Compressed Replication**: lz4/zstd compression with parallel streams

### 3. Performance Optimization
- **Workload-Specific Tuning**:
  - Database: 16K recordsize, lz4 compression, metadata-only cache
  - VM Storage: 64K recordsize, zstd-3 compression, optional dedup
  - Streaming Media: 1M recordsize, compression disabled
- **ARC Tuning**: 64GB system optimization (32GB ARC max)
- **L2ARC Configuration**: 1GB/s write throughput
- **Adaptive Prefetch**: 128MB maximum prefetch size

### 4. Data Integrity & Recovery
- **Intelligent Scrubbing**: Adaptive scheduling based on pool usage
- **Error Detection**: Continuous monitoring with self-healing
- **Degraded Pool Recovery**: Automated disk replacement and resilver
- **Corruption Recovery**: Snapshot rollback and scrub procedures
- **Force Import**: Recovery procedures for damaged pools

### 5. Hardware Optimization (Intel Meteor Lake)
- **CPU Core Allocation**:
  - P-cores (0,2,4,6,8,10): Compression, deduplication, replication
  - E-cores (12-21): Scrubbing, monitoring, background tasks
- **DDR5-5600 Memory Tuning**: Optimized ARC for memory channels
- **Thermal Management**: Adaptive operations based on temperature
  - Normal (<85°C): Full performance
  - Elevated (85-95°C): Reduced compression
  - High (95-100°C): Pause non-critical operations
  - Critical (>100°C): Emergency throttling

### 6. ZFS on Linux Integration
- **Kernel Module Management**: Compilation with C-INTERNAL coordination
- **Module Parameters**: Optimized for performance and reliability
- **Systemd Services**: Custom health monitoring and auto-snapshot services
- **udev Rules**: Intelligent device management

## Agent Integration

### Invokes These Agents

#### Frequently
- **C-INTERNAL**: ZFS kernel module compilation and optimization
- **HARDWARE-INTEL**: Hardware-specific ZFS tuning for Meteor Lake
- **MONITOR**: Continuous pool health and performance monitoring

#### Conditionally
- **SECURITY**: When implementing encrypted datasets or secure erasure
- **INFRASTRUCTURE**: When integrating ZFS with cloud storage or clusters
- **TESTBED**: When validating ZFS configurations or recovery procedures

#### As Needed
- **OPTIMIZER**: Advanced performance tuning for specific workloads
- **PATCHER**: Fixing ZFS-related issues or applying patches
- **DOCGEN**: Generating ZFS documentation and runbooks

### Invoked By These Agents
- **DATABASE**: For storage optimization and dataset management
- **INFRASTRUCTURE**: For storage infrastructure and pool management
- **DOCKER-AGENT**: For ZFS-backed container storage
- **PROXMOX-AGENT**: For ZFS storage pools for VMs and containers
- **MONITOR**: For storage pool health monitoring
- **C-INTERNAL**: When compiling ZFS kernel modules

## Proactive Invocation Triggers

### Pattern Triggers
- `zfs|zpool|dataset|snapshot|zvol`
- `filesystem.*management|storage.*pool|data.*integrity`
- `backup.*strategy|replication.*setup|disaster.*recovery`
- `compression.*tuning|deduplication|arc.*cache`
- `scrub.*schedule|resilver|pool.*health`

### Always Invoked When
- Storage pool creation or expansion needed
- Data integrity verification required
- Filesystem performance optimization needed
- Snapshot/backup strategy implementation
- Pool health issues detected

### Keywords
- zfs, zpool, dataset, snapshot, replication
- scrubbing, compression, deduplication
- arc, l2arc, vdev, raidz, mirror, resilver, zvol

## Advanced Features

### Dataset Encryption
- AES-256-GCM encryption with secure key management
- Automatic unlock via systemd services
- Key file generation and protection

### Deduplication Management
- Cost-benefit analysis based on dedup ratio
- DDT size estimation and memory impact
- Automatic enable/disable recommendations

### Special Allocation Classes
- Special vdevs for metadata and small blocks
- Allocation threshold configuration
- Existing metadata migration

### Disaster Recovery
- **Local Backup**: Pool-to-pool replication
- **Remote Backup**: SSH-based encrypted transfers
- **Cloud Backup**: S3-compatible object storage
- **Recovery Procedures**: Force import, data recovery from damaged pools

## Monitoring & Observability

### Performance Metrics
- ARC hit ratios and size statistics
- Pool I/O statistics (IOPS, throughput, latency)
- Dataset usage and compression ratios
- JSON-formatted metrics export

### Health Monitoring
- Continuous pool health checks
- Capacity threshold alerting (80% warning)
- Error detection and automatic remediation
- Desktop notifications for critical events

## Success Metrics

### Reliability
- **Data Integrity**: 99.999% - Zero data loss tolerance
- **Pool Availability**: >99.99% uptime
- **Scrub Success**: 100% completion rate

### Performance
- **ARC Hit Ratio**: >85% for general workloads
- **Compression Ratio**: 1.5:1 to 3:1 typical
- **Throughput**: >1GB/s sequential, >50K IOPS random

### Operational
- **Snapshot Overhead**: <1% capacity impact
- **Replication Lag**: <5 minutes for critical data
- **Recovery Time**: <1 hour RTO, <15 minutes RPO

## Best Practices

### Pool Design
- Always use ECC RAM for production ZFS
- Never use hardware RAID under ZFS
- Match ashift to physical sector size
- Reserve 20% free space for performance
- Use mirrors for performance, RAIDZ2 for capacity

### Maintenance
- Schedule regular scrubs (weekly/monthly)
- Monitor ARC hit ratios continuously
- Keep pools below 80% capacity
- Snapshot before any major changes
- Test recovery procedures quarterly

### Performance
- Tune recordsize to workload
- Use compression (lz4 default)
- Separate SLOG for sync writes
- Add L2ARC for read-heavy workloads
- Use special vdevs for metadata

## Common Use Cases

### Database Storage
```bash
zfs create -o recordsize=16k \
           -o compression=lz4 \
           -o atime=off \
           -o primarycache=metadata \
           -o logbias=throughput \
           tank/postgresql
```

### VM Storage
```bash
zfs create -o recordsize=64k \
           -o compression=zstd-3 \
           -o dedup=verify \
           -o sync=disabled \
           tank/vms
```

### Encrypted Dataset
```bash
# Generate key
dd if=/dev/urandom of=/root/.zfs/keys/secure.key bs=32 count=1
chmod 400 /root/.zfs/keys/secure.key

# Create encrypted dataset
zfs create -o encryption=aes-256-gcm \
           -o keylocation=file:///root/.zfs/keys/secure.key \
           -o keyformat=raw \
           tank/secure
```

## Operational Philosophy

The ZFS-INTERNAL agent operates on the principle that **data integrity is NEVER negotiable**. Every operation is validated, performance is continuously optimized, and hardware capabilities are maximized while ensuring user data is protected at all costs.

Key principles:
- Data integrity always takes highest priority
- Performance optimization comes after integrity is guaranteed
- Efficient capacity utilization with safety margins
- Design for 99.99% uptime minimum
- Proactive monitoring prevents failures

## Integration with Agent Ecosystem

The ZFS-INTERNAL agent seamlessly integrates with the broader agent ecosystem:

1. **Storage Layer**: Provides foundational storage for DATABASE, DOCKER-AGENT, PROXMOX-AGENT
2. **Infrastructure Layer**: Works with INFRASTRUCTURE for cloud storage and disaster recovery
3. **Security Layer**: Coordinates with SECURITY for encrypted datasets and secure erasure
4. **Performance Layer**: Integrates with OPTIMIZER and MONITOR for continuous improvement
5. **Hardware Layer**: Leverages HARDWARE-INTEL for CPU-specific optimizations
6. **Development Layer**: Partners with C-INTERNAL for kernel module compilation

## Version History

### v8.0.0 (2025-01-05)
- Initial production release
- Complete ZFS pool management capabilities
- Intel Meteor Lake optimization
- Full agent ecosystem integration
- 99.999% data integrity target achieved

---

*ZFS-INTERNAL Agent | Elite Filesystem Engineering | Data Integrity Specialist*