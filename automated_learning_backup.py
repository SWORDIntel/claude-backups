#!/usr/bin/env python3
"""
Automated Learning Data Backup and Export System v3.1
Comprehensive data preservation and analysis preparation
"""

import asyncio
import asyncpg
import json
import gzip
import os
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any, Optional
import logging
import subprocess
import tarfile
import csv

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class LearningDataBackupSystem:
    """Automated backup and export for learning data"""
    
    def __init__(self):
        self.db_connection_string = "postgresql://claude_agent:claude_secure_password@localhost:5433/claude_agents_auth"
        self.backup_dir = Path.home() / ".claude-home" / "learning_backups"
        self.export_dir = Path.home() / ".claude-home" / "learning_exports"
        self.db_pool = None
        
        # Ensure directories exist
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.export_dir.mkdir(parents=True, exist_ok=True)
        
    async def initialize(self):
        """Initialize database connection"""
        try:
            self.db_pool = await asyncpg.create_pool(
                self.db_connection_string,
                min_size=2,
                max_size=5
            )
            logger.info("Backup system initialized")
        except Exception as e:
            logger.error(f"Failed to initialize backup system: {e}")
            
    async def backup_database_full(self) -> Dict[str, Any]:
        """Complete database backup using pg_dump"""
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        backup_file = self.backup_dir / f"claude_learning_full_{timestamp}.sql.gz"
        
        try:
            # Use Docker exec to run pg_dump inside container
            cmd = [
                "docker", "exec", "claude-postgres",
                "pg_dump", "-U", "claude_agent", "-d", "claude_agents_auth",
                "--schema=learning", "--data-only", "--no-owner"
            ]
            
            # Run pg_dump and compress output
            with gzip.open(backup_file, 'wt') as gz_file:
                process = subprocess.run(cmd, stdout=gz_file, stderr=subprocess.PIPE, text=True)
                
            if process.returncode == 0:
                file_size = backup_file.stat().st_size
                logger.info(f"Database backup created: {backup_file} ({file_size} bytes)")
                
                return {
                    "success": True,
                    "backup_file": str(backup_file),
                    "size_bytes": file_size,
                    "timestamp": timestamp
                }
            else:
                logger.error(f"pg_dump failed: {process.stderr}")
                return {"success": False, "error": process.stderr}
                
        except Exception as e:
            logger.error(f"Database backup failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def export_learning_data_json(self, days_back: int = 30) -> Dict[str, Any]:
        """Export learning data as structured JSON"""
        if not self.db_pool:
            return {"success": False, "error": "Database not initialized"}
            
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        export_file = self.export_dir / f"learning_data_{timestamp}.json.gz"
        
        try:
            async with self.db_pool.acquire() as conn:
                # Export agent metrics
                since_date = datetime.utcnow() - timedelta(days=days_back)
                
                agent_metrics = await conn.fetch("""
                    SELECT * FROM learning.agent_metrics 
                    WHERE created_at >= $1
                    ORDER BY created_at DESC
                """, since_date)
                
                # Export task embeddings
                task_embeddings = await conn.fetch("""
                    SELECT id, task_description, agent_name, success_rate, 
                           avg_duration_ms, metadata, created_at
                    FROM learning.task_embeddings
                    WHERE created_at >= $1
                """, since_date)
                
                # Export interaction logs  
                interaction_logs = await conn.fetch("""
                    SELECT * FROM learning.interaction_logs
                    WHERE timestamp >= $1
                    ORDER BY timestamp DESC
                """, since_date)
                
                # Export learning feedback
                learning_feedback = await conn.fetch("""
                    SELECT * FROM learning.learning_feedback
                    WHERE created_at >= $1
                """, since_date)
                
                # Export model performance
                model_performance = await conn.fetch("""
                    SELECT * FROM learning.model_performance
                    WHERE training_date >= $1
                """, since_date)
                
                # Structure export data
                export_data = {
                    "export_info": {
                        "timestamp": datetime.utcnow().isoformat(),
                        "days_back": days_back,
                        "since_date": since_date.isoformat()
                    },
                    "tables": {
                        "agent_metrics": [dict(row) for row in agent_metrics],
                        "task_embeddings": [dict(row) for row in task_embeddings],
                        "interaction_logs": [dict(row) for row in interaction_logs],
                        "learning_feedback": [dict(row) for row in learning_feedback],
                        "model_performance": [dict(row) for row in model_performance]
                    },
                    "summary": {
                        "agent_metrics_count": len(agent_metrics),
                        "task_embeddings_count": len(task_embeddings),
                        "interaction_logs_count": len(interaction_logs),
                        "learning_feedback_count": len(learning_feedback),
                        "model_performance_count": len(model_performance)
                    }
                }
                
                # Write compressed JSON
                with gzip.open(export_file, 'wt') as gz_file:
                    json.dump(export_data, gz_file, indent=2, default=str)
                    
                file_size = export_file.stat().st_size
                logger.info(f"Learning data exported: {export_file} ({file_size} bytes)")
                
                return {
                    "success": True,
                    "export_file": str(export_file),
                    "size_bytes": file_size,
                    "records_exported": sum(export_data["summary"].values()),
                    "summary": export_data["summary"]
                }
                
        except Exception as e:
            logger.error(f"JSON export failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def export_learning_data_csv(self, days_back: int = 30) -> Dict[str, Any]:
        """Export learning data as CSV for analysis"""
        if not self.db_pool:
            return {"success": False, "error": "Database not initialized"}
            
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        csv_dir = self.export_dir / f"learning_csv_{timestamp}"
        csv_dir.mkdir(exist_ok=True)
        
        try:
            async with self.db_pool.acquire() as conn:
                since_date = datetime.utcnow() - timedelta(days=days_back)
                
                # Agent metrics CSV
                metrics_file = csv_dir / "agent_metrics.csv"
                metrics_data = await conn.fetch("""
                    SELECT agent_name, task_id, execution_start, execution_end,
                           duration_ms, status, success_score, cpu_usage_percent,
                           memory_usage_mb, coordination_depth, retry_count,
                           hardware_platform, parallel_execution, created_at
                    FROM learning.agent_metrics 
                    WHERE created_at >= $1
                    ORDER BY created_at DESC
                """, since_date)
                
                with open(metrics_file, 'w', newline='') as csvfile:
                    if metrics_data:
                        fieldnames = list(metrics_data[0].keys())
                        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                        writer.writeheader()
                        for row in metrics_data:
                            writer.writerow(dict(row))
                
                # Task embeddings CSV (without vector data)
                embeddings_file = csv_dir / "task_embeddings.csv"
                embeddings_data = await conn.fetch("""
                    SELECT id, task_description, agent_name, success_rate,
                           avg_duration_ms, created_at
                    FROM learning.task_embeddings
                    WHERE created_at >= $1
                """, since_date)
                
                with open(embeddings_file, 'w', newline='') as csvfile:
                    if embeddings_data:
                        fieldnames = list(embeddings_data[0].keys())
                        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                        writer.writeheader()
                        for row in embeddings_data:
                            writer.writerow(dict(row))
                
                # Create compressed archive
                archive_file = self.export_dir / f"learning_csv_{timestamp}.tar.gz"
                with tarfile.open(archive_file, "w:gz") as tar:
                    tar.add(csv_dir, arcname=f"learning_csv_{timestamp}")
                
                # Cleanup temporary directory
                shutil.rmtree(csv_dir)
                
                file_size = archive_file.stat().st_size
                logger.info(f"CSV export created: {archive_file} ({file_size} bytes)")
                
                return {
                    "success": True,
                    "export_file": str(archive_file),
                    "size_bytes": file_size,
                    "records_exported": len(metrics_data) + len(embeddings_data)
                }
                
        except Exception as e:
            logger.error(f"CSV export failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def backup_log_files(self) -> Dict[str, Any]:
        """Backup raw log files"""
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        log_backup_file = self.backup_dir / f"learning_logs_{timestamp}.tar.gz"
        
        log_dir = Path.home() / ".claude-home" / "learning_logs"
        
        if not log_dir.exists() or not list(log_dir.glob("*.jsonl")):
            return {
                "success": False, 
                "error": "No log files found to backup"
            }
        
        try:
            with tarfile.open(log_backup_file, "w:gz") as tar:
                for log_file in log_dir.glob("*.jsonl"):
                    tar.add(log_file, arcname=log_file.name)
            
            file_size = log_backup_file.stat().st_size
            log_count = len(list(log_dir.glob("*.jsonl")))
            
            logger.info(f"Log files backed up: {log_backup_file} ({file_size} bytes, {log_count} files)")
            
            return {
                "success": True,
                "backup_file": str(log_backup_file),
                "size_bytes": file_size,
                "log_files_count": log_count
            }
            
        except Exception as e:
            logger.error(f"Log backup failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def cleanup_old_backups(self, keep_days: int = 30) -> Dict[str, Any]:
        """Clean up old backup files"""
        cutoff_date = datetime.utcnow() - timedelta(days=keep_days)
        
        cleaned_files = []
        total_size_freed = 0
        
        try:
            # Cleanup backup directory
            for backup_file in self.backup_dir.glob("*"):
                if backup_file.is_file():
                    file_time = datetime.fromtimestamp(backup_file.stat().st_mtime)
                    if file_time < cutoff_date:
                        file_size = backup_file.stat().st_size
                        backup_file.unlink()
                        cleaned_files.append(str(backup_file))
                        total_size_freed += file_size
            
            # Cleanup export directory
            for export_file in self.export_dir.glob("*"):
                if export_file.is_file():
                    file_time = datetime.fromtimestamp(export_file.stat().st_mtime)
                    if file_time < cutoff_date:
                        file_size = export_file.stat().st_size
                        export_file.unlink()
                        cleaned_files.append(str(export_file))
                        total_size_freed += file_size
            
            logger.info(f"Cleaned up {len(cleaned_files)} old backup files, freed {total_size_freed} bytes")
            
            return {
                "success": True,
                "files_removed": len(cleaned_files),
                "size_freed_bytes": total_size_freed,
                "removed_files": cleaned_files
            }
            
        except Exception as e:
            logger.error(f"Cleanup failed: {e}")
            return {"success": False, "error": str(e)}
    
    async def run_comprehensive_backup(self) -> Dict[str, Any]:
        """Run all backup operations"""
        logger.info("Starting comprehensive backup...")
        
        results = {
            "backup_timestamp": datetime.utcnow().isoformat(),
            "operations": {}
        }
        
        # Database backup
        results["operations"]["database_backup"] = await self.backup_database_full()
        
        # JSON export  
        results["operations"]["json_export"] = await self.export_learning_data_json()
        
        # CSV export
        results["operations"]["csv_export"] = await self.export_learning_data_csv()
        
        # Log files backup
        results["operations"]["log_backup"] = await self.backup_log_files()
        
        # Cleanup old files
        results["operations"]["cleanup"] = await self.cleanup_old_backups()
        
        # Calculate summary
        successful_ops = sum(1 for op in results["operations"].values() if op.get("success"))
        total_ops = len(results["operations"])
        
        results["summary"] = {
            "successful_operations": successful_ops,
            "total_operations": total_ops,
            "overall_success": successful_ops == total_ops
        }
        
        logger.info(f"Comprehensive backup completed: {successful_ops}/{total_ops} operations successful")
        
        return results

async def main():
    """Main backup interface"""
    backup_system = LearningDataBackupSystem()
    await backup_system.initialize()
    
    import sys
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == "full":
            result = await backup_system.run_comprehensive_backup()
        elif command == "database":
            result = await backup_system.backup_database_full()
        elif command == "json":
            days = int(sys.argv[2]) if len(sys.argv) > 2 else 30
            result = await backup_system.export_learning_data_json(days)
        elif command == "csv":
            days = int(sys.argv[2]) if len(sys.argv) > 2 else 30
            result = await backup_system.export_learning_data_csv(days)
        elif command == "logs":
            result = await backup_system.backup_log_files()
        elif command == "cleanup":
            days = int(sys.argv[2]) if len(sys.argv) > 2 else 30
            result = await backup_system.cleanup_old_backups(days)
        else:
            print(f"Unknown command: {command}")
            print("Available commands: full, database, json [days], csv [days], logs, cleanup [days]")
            return
            
        print(json.dumps(result, indent=2))
    else:
        # Default: run comprehensive backup
        result = await backup_system.run_comprehensive_backup()
        print(json.dumps(result, indent=2))

if __name__ == "__main__":
    asyncio.run(main())