#!/usr/bin/env python3
"""
Real-time Learning Data Synchronization System v3.1
Continuously syncs log files to PostgreSQL database
"""

import asyncio
import asyncpg
import json
import time
import logging
import hashlib
import os
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime
import uuid
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LearningDataSyncer(FileSystemEventHandler):
    """Real-time sync of learning logs to database"""
    
    def __init__(self, db_connection_string: str):
        self.db_connection_string = db_connection_string
        self.pool: Optional[asyncpg.pool.Pool] = None
        self.processed_lines = set()
        self.sync_queue = asyncio.Queue()
        
    async def initialize(self):
        """Initialize database connection pool"""
        try:
            self.pool = await asyncpg.create_pool(
                self.db_connection_string,
                min_size=2,
                max_size=10,
                command_timeout=30
            )
            logger.info("Database connection pool initialized")
            
            # Start background sync task
            asyncio.create_task(self.process_sync_queue())
            
        except Exception as e:
            logger.error(f"Failed to initialize database pool: {e}")
            
    async def sync_execution_log(self, log_entry: Dict[str, Any]):
        """Sync single execution log to database"""
        if not self.pool:
            logger.warning("Database pool not initialized")
            return
            
        try:
            async with self.pool.acquire() as conn:
                # Handle start event
                if log_entry.get('event') == 'start':
                    await conn.execute("""
                        INSERT INTO learning.agent_metrics 
                        (agent_name, task_id, session_id, execution_start, status, execution_context)
                        VALUES ($1, $2, $3, $4, 'started', $5)
                        ON CONFLICT (session_id) DO UPDATE SET
                        execution_start = EXCLUDED.execution_start
                    """, 
                        log_entry.get('agent', 'direct'),
                        log_entry.get('session_id'),
                        log_entry.get('session_id'),
                        datetime.fromisoformat(log_entry.get('timestamp', '').replace('Z', '+00:00')),
                        json.dumps({
                            'prompt_hash': log_entry.get('prompt_hash'),
                            'args_count': log_entry.get('args_count', 0)
                        })
                    )
                
                # Handle end event  
                elif log_entry.get('event') == 'end':
                    duration_ms = int(float(log_entry.get('duration', 0)) * 1000)
                    success_score = 1.0 if log_entry.get('success') else 0.0
                    status = 'completed' if log_entry.get('success') else 'failed'
                    
                    await conn.execute("""
                        UPDATE learning.agent_metrics 
                        SET execution_end = $1, 
                            duration_ms = $2, 
                            status = $3,
                            success_score = $4,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE session_id = $5
                    """,
                        datetime.fromisoformat(log_entry.get('timestamp', '').replace('Z', '+00:00')),
                        duration_ms,
                        status,
                        success_score,
                        log_entry.get('session_id')
                    )
                    
                logger.info(f"Synced {log_entry.get('event')} for session {log_entry.get('session_id')}")
                
        except Exception as e:
            logger.error(f"Failed to sync log entry: {e}")
            
    async def process_sync_queue(self):
        """Background task to process sync queue"""
        while True:
            try:
                log_entry = await self.sync_queue.get()
                await self.sync_execution_log(log_entry)
                self.sync_queue.task_done()
            except Exception as e:
                logger.error(f"Error processing sync queue: {e}")
                await asyncio.sleep(1)
                
    def on_modified(self, event):
        """Handle file modification events"""
        if event.is_directory:
            return
            
        if event.src_path.endswith('executions.jsonl'):
            asyncio.create_task(self.sync_log_file(event.src_path))
            
    async def sync_log_file(self, file_path: str):
        """Sync entire log file to database"""
        try:
            with open(file_path, 'r') as f:
                for line_num, line in enumerate(f, 1):
                    line = line.strip()
                    if not line:
                        continue
                        
                    # Create unique identifier for this line
                    line_id = f"{file_path}:{line_num}:{hashlib.md5(line.encode()).hexdigest()[:8]}"
                    
                    if line_id in self.processed_lines:
                        continue
                        
                    try:
                        log_entry = json.loads(line)
                        await self.sync_queue.put(log_entry)
                        self.processed_lines.add(line_id)
                        
                    except json.JSONDecodeError as e:
                        logger.warning(f"Invalid JSON in log file {file_path}:{line_num}: {e}")
                        
        except FileNotFoundError:
            logger.warning(f"Log file not found: {file_path}")
        except Exception as e:
            logger.error(f"Error syncing log file {file_path}: {e}")

async def main():
    """Main synchronization loop"""
    # Configuration
    db_conn_string = "postgresql://claude_agent:claude_secure_password@localhost:5433/claude_agents_auth"
    learning_logs_path = Path.home() / ".claude-home" / "learning_logs"
    
    # Ensure log directory exists
    learning_logs_path.mkdir(parents=True, exist_ok=True)
    
    # Initialize syncer
    syncer = LearningDataSyncer(db_conn_string)
    await syncer.initialize()
    
    # Set up file watcher
    observer = Observer()
    observer.schedule(syncer, str(learning_logs_path), recursive=True)
    observer.start()
    
    logger.info(f"Learning data syncer started, watching {learning_logs_path}")
    
    # Initial sync of existing logs
    for log_file in learning_logs_path.glob("*.jsonl"):
        await syncer.sync_log_file(str(log_file))
    
    try:
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        logger.info("Shutting down learning data syncer")
        observer.stop()
        observer.join()
        
        if syncer.pool:
            await syncer.pool.close()

if __name__ == "__main__":
    # Install watchdog if not available
    try:
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
    except ImportError:
        print("Installing watchdog for file monitoring...")
        import subprocess
        subprocess.check_call(["pip3", "install", "watchdog"])
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
    
    asyncio.run(main())