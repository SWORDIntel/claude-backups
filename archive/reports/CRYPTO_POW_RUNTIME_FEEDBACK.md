# Crypto-POW Engine - Runtime Feedback Mechanisms
**System:** Real-time cryptographic operations monitoring
**Mode:** Continuous background operation
**Purpose:** Track crypto-pow work completion during live operation

---

## Runtime Operation Overview

When crypto-pow engine runs in production, it provides continuous feedback through multiple channels:

---

## 1. Real-Time Performance Monitor

**File:** `hooks/crypto-pow/crypto_performance_monitor.py`

**Operation:**
```python
async def run_monitoring_loop(self):
    while self.running:
        # Every 3 seconds:
        metrics = await self.collect_metrics()

        # Console output
        self.logger.info(
            f"Performance: {metrics.vps:.1f} vps (pred: {metrics.prediction:.1f}), "
            f"CPU: {metrics.cpu_usage:.1f}%, Memory: {metrics.memory_mb:.0f}MB"
        )

        # Store to database (batch of 50)
        if len(self.metrics_cache) >= 50:
            await self.store_metrics_batch(self.metrics_cache)

        await asyncio.sleep(3)  # 3-second interval
```

**Real-time Output Example:**
```
2025-10-11 16:30:15 - INFO - Performance: 87.3 vps (pred: 92.1), CPU: 45.2%, Memory: 234MB
2025-10-11 16:30:18 - INFO - Performance: 89.1 vps (pred: 91.8), CPU: 46.1%, Memory: 235MB
2025-10-11 16:30:21 - INFO - Performance: 91.4 vps (pred: 93.2), CPU: 44.8%, Memory: 233MB
```

**Metrics Tracked:**
- `vps` - Verifications per second (work throughput)
- `cpu_usage` - CPU utilization percentage
- `memory_mb` - Memory consumption
- `success_rate` - Percentage of successful verifications
- `queue_depth` - Pending work items
- `prediction` - ML-predicted next performance

---

## 2. Live Status File

**Location:** `/tmp/crypto_startup_cache.json`

**Updated:** Every optimization cycle
**Format:**
```json
{
  "total_startup_time": 2.34,
  "phases": {
    "system_readiness": 0.12,
    "database_connection": 0.89,
    "service_startup": 1.33
  },
  "performance_tuning": {
    "batch_size": 50,
    "interval": 3,
    "threads": 4
  },
  "optimization_timestamp": 1697045678.91
}
```

**Usage:** Check current runtime configuration
```bash
cat /tmp/crypto_startup_cache.json | jq '.phases'
```

---

## 3. Database Metrics Stream

**Table:** `crypto_learning.verification_performance`

**Real-time Inserts:**
```sql
INSERT INTO crypto_learning.verification_performance
  (timestamp, verifications_per_second, cpu_usage, memory_usage_mb,
   success_rate, difficulty_level, hash_algorithm)
VALUES
  (NOW(), 87.3, 45.2, 234, 98.5, 16, 'SHA256')
```

**Batch Storage:** Every 50 metrics (every ~2.5 minutes)

**Query Live Status:**
```sql
SELECT
  verifications_per_second as vps,
  cpu_usage,
  success_rate,
  timestamp
FROM crypto_learning.verification_performance
WHERE timestamp >= NOW() - INTERVAL '5 minutes'
ORDER BY timestamp DESC;
```

**Shows:** Last 5 minutes of operation

---

## 4. Logging Output

**File:** `/tmp/crypto_auto_start_optimizer.log`

**Continuous Logging:**
```
2025-10-11 16:30:00 - INFO - Starting crypto auto-start optimization
2025-10-11 16:30:00 - INFO - Optimizing CPU governor for crypto performance
2025-10-11 16:30:00 - INFO - CPU temperature optimal: 67°C
2025-10-11 16:30:01 - INFO - Database connection optimized with 10 connections
2025-10-11 16:30:02 - INFO - Applied performance parameters: {'batch_size': 50, 'interval': 3, 'threads': 4}
```

**Runtime Updates:**
```
2025-10-11 16:30:15 - INFO - Performance: 87.3 vps, CPU: 45%, Memory: 234MB
2025-10-11 16:30:18 - INFO - Performance: 89.1 vps, CPU: 46%, Memory: 235MB
```

**Tail to Watch:**
```bash
tail -f /tmp/crypto_auto_start_optimizer.log
```

---

## 5. Performance Reports (Every 10 Minutes)

**Generated Automatically:**
```python
# Every 10 minutes
if int(time.time()) % 600 == 0:
    report = await self.generate_optimization_report()
    self.logger.info(f"Efficiency: {report['efficiency']:.1f}%")
```

**Report Output:**
```
2025-10-11 16:40:00 - INFO - Efficiency: 87.3%
2025-10-11 16:40:00 - INFO - Performance below 80% of target - consider optimization
```

**Full Report Format:**
```json
{
  "status": "success",
  "current_performance": {
    "avg_vps": 87.3,
    "avg_cpu": 45.2,
    "avg_memory": 234
  },
  "target_vps": 100,
  "efficiency": 87.3,
  "recommendations": [
    "Performance below 80% of target - consider optimization"
  ]
}
```

---

## 6. Results File (After Each Verification)

**Location:** `hooks/crypto-pow/results/crypto_optimization_results.json`

**Updated:** After each crypto operation completes

**Format:**
```json
{
  "verification_count": 1247,
  "success_count": 1223,
  "failure_count": 24,
  "success_rate": 98.1,
  "avg_verification_time_ms": 1234.56,
  "total_runtime_seconds": 86400,
  "last_verification": {
    "timestamp": "2025-10-11T16:30:45Z",
    "component": "shadowgit_engine",
    "confidence": 0.847,
    "status": "AUTHENTIC"
  }
}
```

**Check Work Status:**
```bash
cat hooks/crypto-pow/results/crypto_optimization_results.json | jq '.last_verification'
```

---

## 7. Live Console Dashboard (Optional)

**File:** `hooks/crypto-pow/crypto_analytics_dashboard.py`

**Run:**
```bash
python3 hooks/crypto-pow/crypto_analytics_dashboard.py
```

**Output:**
```
Crypto Verification Analytics Summary
====================================
Timestamp: 2025-10-11 16:30:45
Performance Grade: GOOD
Efficiency Score: 87.3%
Trend Direction: stable

Predictions:
  next_hour_vps: 92.1
  confidence: 0.75
  trend: stable

Recommendations:
• Performance below 80% of target - consider optimization
• System performing optimally

Anomalies:
⚠ CPU usage anomaly: 65.3% (expected ~45.2%)
```

**Refresh:** Generates new report on each run

---

## 8. Python Callbacks (Integration Layer)

**File:** `hooks/crypto-pow/crypto_system_optimizer.py`

**Event-Driven Feedback:**
```python
class CryptoSystemOptimizer:
    def __init__(self):
        self.callbacks = {
            'on_work_start': [],
            'on_work_progress': [],
            'on_work_complete': [],
            'on_work_error': []
        }

    async def run_verification(self, component):
        # Trigger start callbacks
        self._notify('on_work_start', {'component': component})

        # During work - progress updates
        for progress in range(0, 100, 20):
            self._notify('on_work_progress', {
                'component': component,
                'progress': progress,
                'phase': self._current_phase
            })

        # On completion
        result = await self._complete_verification()
        self._notify('on_work_complete', {
            'component': component,
            'result': result,
            'status': 'AUTHENTIC' if result.confidence >= 0.7 else 'REJECTED'
        })
```

**Usage:**
```python
optimizer = CryptoSystemOptimizer()

@optimizer.on('on_work_progress')
def show_progress(data):
    print(f"Progress: {data['progress']}% - Phase: {data['phase']}")

@optimizer.on('on_work_complete')
def handle_completion(data):
    print(f"✅ Work complete: {data['status']}")
    print(f"Confidence: {data['result']['confidence']}")
```

---

## 9. System Signals (Process Communication)

**Signal Handling:**
```python
signal.signal(signal.SIGINT, self.shutdown)   # Ctrl+C
signal.signal(signal.SIGTERM, self.shutdown)  # Kill
```

**On Shutdown:**
```python
def shutdown(self, signum=None, frame=None):
    self.logger.info("Shutting down monitor...")
    self.running = False

    # Flush remaining metrics
    if self.metrics_cache:
        asyncio.create_task(self.store_metrics_batch(self.metrics_cache))

    # Close database pool
    asyncio.create_task(self.pool.close())
```

**Feedback:** Logs shutdown, ensures data is saved

---

## 10. Work Queue Status

**Real-time Queue Depth:**
```python
async def collect_metrics(self) -> PerformanceMetrics:
    crypto_metrics = self.measure_crypto_performance()

    return PerformanceMetrics(
        queue_depth=crypto_metrics.get("queue_depth", 0),  # ← Work remaining
        vps=crypto_metrics.get("vps", 0),                   # ← Work rate
        success_rate=crypto_metrics.get("success_rate", 0)  # ← Quality
    )
```

**Indicates:**
- `queue_depth = 0` → All work complete
- `queue_depth > 0` → Work pending
- `vps > 0` → Engine actively processing

---

## How to Monitor Runtime

### Check if Running:
```bash
# Check for crypto monitor process
ps aux | grep crypto_performance_monitor
```

### Watch Real-time Status:
```bash
# Tail the log
tail -f /tmp/crypto_auto_start_optimizer.log

# Watch metrics file
watch -n 1 'cat /tmp/crypto_startup_cache.json | jq ".performance_tuning"'
```

### Check Database Metrics:
```bash
docker exec claude-postgres psql -U claude_user -d claude_auth -c "
  SELECT
    TO_CHAR(timestamp, 'HH24:MI:SS') as time,
    verifications_per_second as vps,
    cpu_usage,
    success_rate
  FROM crypto_learning.verification_performance
  WHERE timestamp >= NOW() - INTERVAL '5 minutes'
  ORDER BY timestamp DESC
  LIMIT 10;
"
```

### Generate Analytics Report:
```bash
python3 hooks/crypto-pow/crypto_analytics_dashboard.py
```

---

## Work Completion Detection During Runtime

### Method 1: Monitor Log Output
```bash
tail -f /tmp/crypto_auto_start_optimizer.log | grep "vps"
```
**When vps > 0:** Work is being processed
**When vps = 0 for extended period:** No work or engine idle

### Method 2: Check Queue Depth
```python
metrics = await monitor.collect_metrics()
if metrics.queue_depth == 0:
    print("✅ All work completed")
else:
    print(f"⏳ {metrics.queue_depth} items remaining")
```

### Method 3: Database Query
```sql
SELECT COUNT(*) as pending_work
FROM crypto_learning.verification_queue
WHERE status = 'pending';
```
**Result = 0:** All work complete

### Method 4: Check Results File
```bash
# Last verification timestamp
cat hooks/crypto-pow/results/crypto_optimization_results.json | \
  jq -r '.last_verification.timestamp'

# If timestamp is recent (< 10 seconds ago), engine is active
```

### Method 5: Performance Grade
```python
report = await dashboard.generate_comprehensive_report()
if report.performance_grade in ['EXCELLENT', 'GOOD']:
    print("✅ Engine performing well")
elif report.performance_grade == 'CRITICAL':
    print("⚠️ Engine struggling or idle")
```

---

## Automatic Notifications

### Log Notifications:
- Every 3 seconds: Performance metrics
- Every 10 minutes: Efficiency report
- On anomaly: Warning logged
- On error: Error logged

### Database Notifications:
- Every ~2.5 minutes: Batch insert of 50 metrics
- Triggers can be added for:
  - Success rate drops below 95%
  - VPS drops below 80% of target
  - Queue depth exceeds threshold

### Python Callbacks:
```python
# Register for notifications
optimizer.on_work_complete.append(my_callback)

# Callback receives:
def my_callback(result):
    print(f"Work done: {result['component']}")
    print(f"Status: {result['status']}")
    print(f"Confidence: {result['confidence']}")
    # Can trigger next action based on completion
```

---

## Status Indicators Summary

| Indicator | Location | Update Frequency | Shows |
|-----------|----------|------------------|-------|
| **Console Log** | stdout/stderr | 3 seconds | VPS, CPU, memory, predictions |
| **Log File** | /tmp/*.log | 3 seconds | All events, errors, warnings |
| **Status File** | /tmp/crypto_startup_cache.json | On change | Current configuration |
| **Database** | crypto_learning.verification_performance | ~2.5 min batches | Historical metrics |
| **Results File** | results/crypto_optimization_results.json | After each verification | Last completion |
| **Analytics** | On-demand | On request | Trends, predictions, grade |
| **Callbacks** | In-memory | Immediate | Events, completion, errors |
| **Queue Depth** | Metrics object | 3 seconds | Pending work count |

---

## Example: Monitoring a Running Crypto-POW Engine

### Start the Monitor:
```bash
python3 hooks/crypto-pow/crypto_performance_monitor.py &
PID=$!
```

### Watch Progress:
```bash
# Terminal 1: Real-time log
tail -f /tmp/crypto_auto_start_optimizer.log

# Terminal 2: Watch metrics
watch -n 1 'cat /tmp/crypto_startup_cache.json | jq'

# Terminal 3: Database queries
watch -n 5 'docker exec claude-postgres psql -U claude_user -d claude_auth \
  -c "SELECT COUNT(*) FROM crypto_learning.verification_performance
      WHERE timestamp >= NOW() - INTERVAL '"'"'1 minute'"'"';" \
  -t'
```

### Check Work Completion:
```bash
# Method 1: Check if any recent activity
tail -1 /tmp/crypto_auto_start_optimizer.log

# Method 2: Query last verification
cat hooks/crypto-pow/results/crypto_optimization_results.json | \
  jq '.last_verification | {timestamp, status, confidence}'

# Method 3: Database check
docker exec claude-postgres psql -U claude_user -d claude_auth -c \
  "SELECT
    MAX(timestamp) as last_activity,
    COUNT(*) as total_verifications,
    AVG(success_rate) as avg_success
   FROM crypto_learning.verification_performance
   WHERE timestamp >= NOW() - INTERVAL '1 hour';"
```

---

## Completion Signals

### Engine Signals "Work Complete" When:

1. **Queue Depth = 0**
   ```python
   if metrics.queue_depth == 0:
       # No pending work
   ```

2. **VPS Drops to 0**
   ```
   Performance: 0.0 vps (pred: 0.0), CPU: 5%, Memory: 100MB
   ```
   **Indicates:** Engine idle, no work

3. **Success Count Stops Increasing**
   ```json
   {
     "success_count": 1247,  // Same for 10+ minutes
     "timestamp": "old"
   }
   ```

4. **Callback Fired**
   ```python
   on_work_complete([{
       'status': 'idle',
       'queue_depth': 0,
       'last_verification': '10 minutes ago'
   }])
   ```

5. **Database Shows No Recent Inserts**
   ```sql
   SELECT MAX(timestamp) FROM verification_performance;
   -- If > 5 minutes ago, engine idle
   ```

---

## Integration with Main System

### How Installer Enables Runtime Feedback:

**Step 6.6.1:** Compiles crypto-pow objects
- Enables verification capability

**Runtime Activation (Manual):**
```bash
# Start performance monitor
python3 hooks/crypto-pow/crypto_performance_monitor.py &

# Start optimizer
python3 hooks/crypto-pow/crypto_system_optimizer.py &

# Start dashboard
python3 hooks/crypto-pow/crypto_analytics_dashboard.py &
```

**Or via Wrapper:**
```bash
# If CRYPTO_POW_ENABLED=true in env
export CRYPTO_POW_ENABLED=true
export CRYPTO_POW_AUTO_START=true

claude task "your task"
# Crypto-POW starts automatically, provides feedback during operation
```

---

## Feedback Frequency

**Immediate (< 1s):**
- Python callbacks
- Console output (when verbose)

**Fast (3s):**
- Performance monitor updates
- Log file updates

**Regular (2-5 min):**
- Database batch inserts
- Metrics cache flush

**Periodic (10 min):**
- Efficiency reports
- Analytics updates

**On-Demand:**
- Dashboard queries
- Status file reads
- Database queries

---

## Summary

**During runtime**, crypto-pow provides feedback through:

1. **Real-time console** (every 3s: VPS, CPU, memory, predictions)
2. **Log files** (continuous append with all events)
3. **Status file** (/tmp/crypto_startup_cache.json)
4. **Database stream** (batch inserts every ~2.5 min)
5. **Results file** (updated after each verification)
6. **Analytics dashboard** (on-demand comprehensive report)
7. **Python callbacks** (event-driven notifications)
8. **Queue depth** (shows pending work count)

**Work completion detected by:**
- Queue depth = 0
- VPS = 0 (idle)
- No recent database inserts
- Callbacks fired
- Log shows idle state

The engine provides **continuous, multi-channel feedback** during runtime operation, allowing real-time monitoring of work progress and completion!
