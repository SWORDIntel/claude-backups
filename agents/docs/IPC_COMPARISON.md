# IPC Method Comparison for Agent Communication

## 1. Shared Memory

### Pros ✅
- **Fastest possible** - Zero copy, direct memory access
- **Lowest latency** - No kernel involvement after setup
- **Best throughput** - Can achieve memory bandwidth speeds (100+ GB/s)
- **CPU efficient** - No syscalls for data transfer
- **Cache friendly** - Can use huge pages, NUMA optimization

### Cons ❌
- **Complex synchronization** - Need locks/atomics for coordination
- **No built-in flow control** - Must implement manually
- **Single machine only** - Cannot work across network
- **Crash recovery hard** - Shared state can be corrupted
- **Security concerns** - All processes can read/write

### Best For
- High-frequency trading systems
- Real-time audio/video processing
- Intra-node agent communication
- Our P-core ↔ E-core communication

### Implementation
```c
// Our ring buffer already uses this
typedef struct {
    _Atomic uint64_t write_pos;
    _Atomic uint64_t read_pos;
    uint8_t* buffer;  // mmap'd shared memory
} shared_mem_channel_t;
```

---

## 2. Unix Domain Sockets

### Pros ✅
- **Reliable** - Kernel handles buffering and flow control
- **Bidirectional** - Full duplex communication
- **Familiar API** - Same as network sockets
- **Access control** - File system permissions
- **Works with select/epoll/io_uring** - Async I/O ready

### Cons ❌
- **Kernel overhead** - Syscalls for send/recv
- **Memory copies** - Data copied to/from kernel
- **Higher latency** - ~1-10 microseconds typically
- **Limited throughput** - ~5-10 GB/s max
- **File descriptor limits** - OS limits on open sockets

### Best For
- Service communication
- Client-server within machine
- When reliability > speed
- Cross-language IPC

### Implementation
```c
// Standard socket approach
int sock = socket(AF_UNIX, SOCK_STREAM, 0);
struct sockaddr_un addr = {
    .sun_family = AF_UNIX,
    .sun_path = "/tmp/agent.sock"
};
```

---

## 3. Memory-Mapped Files

### Pros ✅
- **Persistent** - Survives process crashes
- **Shareable** - Multiple readers/writers
- **Large capacity** - Can map huge files
- **Page cache** - OS manages caching
- **Lazy loading** - Only accessed pages loaded

### Cons ❌
- **I/O overhead** - Disk access on page faults
- **Synchronization needed** - Like shared memory
- **File system overhead** - Metadata updates
- **Slower than pure memory** - Disk bounded
- **Cleanup required** - Files persist after crash

### Best For
- Large datasets
- Persistent queues
- Crash recovery needed
- Sharing between many processes

### Implementation
```c
int fd = open("/tmp/agent_queue", O_RDWR | O_CREAT);
void* map = mmap(NULL, size, PROT_READ | PROT_WRITE, 
                 MAP_SHARED, fd, 0);
```

---

## 4. Pipes (Named/Anonymous)

### Pros ✅
- **Simple** - Unidirectional stream
- **Automatic blocking** - Built-in flow control
- **Low overhead** - Kernel optimized
- **Works with shell** - Script integration

### Cons ❌
- **Unidirectional** - Need two for bidirectional
- **Limited buffer** - Usually 64KB
- **No message boundaries** - Stream oriented
- **Sequential only** - No random access
- **Single reader/writer** - Not for multiple agents

### Best For
- Parent-child communication
- Shell script integration
- Simple producer-consumer

---

## 5. Linux-Specific: io_uring with shared buffers

### Pros ✅
- **Zero syscall** data path (SQPOLL mode)
- **Shared memory** efficiency
- **Async everything** - No blocking
- **Batch operations** - Amortize overhead
- **Modern** - Designed for current hardware

### Cons ❌
- **Linux 5.1+ only** - Not portable
- **Complex API** - Steep learning curve
- **Memory overhead** - Ring buffers per connection
- **Still evolving** - API changes

### Best For
- High-performance servers
- Batch processing
- Modern Linux systems

---

# Recommendation for Our Agent System

## Hybrid Approach (BEST)

Use **different methods for different priorities**:

```c
typedef struct {
    // CRITICAL: Shared memory ring buffer (P-cores)
    shared_mem_channel_t* critical_channel;  // <100ns latency
    
    // HIGH: io_uring with shared buffers
    struct io_uring* high_priority_ring;     // <1μs latency
    
    // NORMAL: Unix domain sockets
    int normal_socket_fd;                    // <10μs latency
    
    // LOW: Memory-mapped queue file
    void* low_priority_mmap;                 // <100μs latency
    
    // BATCH: Direct memory for GPU/NPU
    void* batch_dma_region;                  // DMA capable
} agent_ipc_channels_t;
```

## Why Hybrid?

1. **Critical messages** (P-core) need absolute minimum latency → Shared memory
2. **High priority** needs async and batching → io_uring
3. **Normal traffic** needs reliability → Unix sockets
4. **Low priority** can use persistent queue → mmap
5. **AI/GPU** needs pinned memory → DMA regions

## Performance Comparison

| Method | Latency | Throughput | CPU Usage | Reliability |
|--------|---------|------------|-----------|-------------|
| Shared Memory | 50ns | 100GB/s | Lowest | Manual |
| io_uring | 500ns | 50GB/s | Low | High |
| Unix Socket | 2μs | 10GB/s | Medium | Highest |
| mmap File | 10μs | 5GB/s | Medium | Persistent |
| Pipe | 1μs | 2GB/s | Low | High |

## Implementation Priority

1. **Start with shared memory** for critical path (DONE ✅)
2. **Add Unix sockets** for control plane
3. **Integrate io_uring** for async operations
4. **Use mmap** for persistent state
5. **Keep pipes** for shell integration

## Code Example: Adaptive IPC

```c
// Select IPC method based on message priority and size
int send_agent_message(agent_msg_t* msg) {
    if (msg->priority == PRIORITY_CRITICAL) {
        // Use shared memory ring buffer
        return ring_buffer_write(shared_ring, msg);
        
    } else if (msg->priority == PRIORITY_HIGH && msg->size > 64KB) {
        // Use io_uring for large async
        return io_uring_send(uring, msg);
        
    } else if (msg->needs_reliability) {
        // Use Unix socket
        return send(unix_sock, msg, msg->size, 0);
        
    } else {
        // Use mmap'd queue
        return mmap_queue_append(mmap_queue, msg);
    }
}
```

## Conclusion

**Don't choose one - use the right tool for each job!**

Our enhanced protocol should:
1. Keep shared memory for ultra-fast critical path ✅
2. Add Unix sockets for reliable control
3. Integrate io_uring for modern async
4. Use mmap for persistence
5. Support pipes for scripting

This gives us:
- **Minimum latency** where needed (50ns)
- **Maximum throughput** for bulk (100GB/s)
- **Reliability** for control messages
- **Persistence** for state
- **Compatibility** with existing tools