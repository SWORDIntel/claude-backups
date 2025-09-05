#!/usr/bin/env python3
"""
Context Chopping Hooks System
Integrates with Git, Claude Code, and existing shadowgit hooks for intelligent context management
"""

import os
import sys
import json
import hashlib
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Optional, Any, Set
import psycopg2
from psycopg2.extras import RealDictCursor

# Add agents directory to path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'agents', 'src', 'python'))

from intelligent_context_chopper import IntelligentContextChopper, ContextChunk
from permission_fallback_system import PermissionFallbackSystem
from rejection_reduction_integration import UnifiedClaudeOptimizer

class ContextChoppingHookManager:
    """
    Manages all context chopping hooks across the system
    Integrates with existing shadowgit hooks and Git workflow
    """
    
    def __init__(self, db_connection_string: str = None):
        self.chopper = IntelligentContextChopper(
            max_context_tokens=8000,
            security_mode=True,
            use_shadowgit=True
        )
        
        self.fallback_system = PermissionFallbackSystem()
        
        # Database connection for storing wider context
        self.db_conn_string = db_connection_string or self._get_db_connection()
        self.db_pool = None
        
        # Hook configuration
        self.enabled = True
        self.debug_mode = os.environ.get('CONTEXT_CHOPPER_DEBUG', 'false').lower() == 'true'
        
        # Statistics
        self.stats = {
            'total_requests': 0,
            'contexts_optimized': 0,
            'tokens_saved': 0,
            'security_redactions': 0,
            'rejections_prevented': 0
        }
    
    def _get_db_connection(self) -> str:
        """Get database connection string from environment or config"""
        # Always use Docker container connection (port 5433 mapped to container's 5432)
        return "host=localhost port=5433 dbname=claude_agents_auth user=claude_agent password=claude_secure_password"
    
    def _get_db_connection_sync(self):
        """Get synchronous database connection"""
        try:
            return psycopg2.connect(self.db_conn_string, cursor_factory=RealDictCursor)
        except Exception as e:
            if self.debug_mode:
                print(f"Database connection failed: {e}")
            return None
    
    def pre_commit_hook(self, repo_path: str, files_changed: List[str]) -> Dict[str, Any]:
        """
        Git pre-commit hook - analyze changed files and update context database
        Integrates with existing shadowgit hooks
        """
        if not self.enabled:
            return {"status": "disabled"}
        
        results = {
            "status": "success",
            "files_analyzed": 0,
            "chunks_stored": 0,
            "processing_time_ms": 0
        }
        
        start_time = time.time()
        
        try:
            # Use shadowgit for ultra-fast analysis if available
            if self.chopper.shadowgit_available:
                shadowgit_results = self._run_shadowgit_analysis(files_changed)
                results["shadowgit_analysis"] = shadowgit_results
            
            # Process each changed file
            for file_path in files_changed:
                if self._should_process_file(file_path):
                    chunks = self.chopper.chunk_file(file_path)
                    self._store_chunks_in_db(chunks, repo_path)
                    
                    results["files_analyzed"] += 1
                    results["chunks_stored"] += len(chunks)
            
            results["processing_time_ms"] = int((time.time() - start_time) * 1000)
            
        except Exception as e:
            results["status"] = "error"
            results["error"] = str(e)
            if self.debug_mode:
                print(f"Pre-commit hook error: {e}")
        
        return results
    
    def pre_request_hook(self, request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Hook before sending request to Claude API
        Replaces large context with intelligently selected chunks
        """
        if not self.enabled:
            return request_data
        
        self.stats['total_requests'] += 1
        original_context = request_data.get('context', '')
        original_tokens = len(original_context.split())
        
        # Check if context needs chopping (> 4000 tokens)
        if original_tokens < 4000:
            return request_data
        
        try:
            # Extract query from request
            query = request_data.get('prompt', '') or request_data.get('message', '')
            
            # Get project root
            project_root = request_data.get('project_root', '.')
            
            # Security check - use fallback system capabilities
            security_level = self._determine_security_level(request_data)
            
            # Get optimized context using intelligent chopper
            optimized_context = self.chopper.get_context_for_request(
                query=query,
                project_root=project_root,
                file_extensions=request_data.get('file_extensions')
            )
            
            # Update request with optimized context
            request_data['context'] = optimized_context
            request_data['original_context_tokens'] = original_tokens
            request_data['optimized_context_tokens'] = len(optimized_context.split())
            
            # Track savings
            tokens_saved = original_tokens - request_data['optimized_context_tokens']
            self.stats['contexts_optimized'] += 1
            self.stats['tokens_saved'] += tokens_saved
            
            # Record in database for learning
            self._record_context_usage(query, optimized_context, tokens_saved)
            
            if self.debug_mode:
                print(f"Context optimized: {original_tokens} -> {request_data['optimized_context_tokens']} tokens")
        
        except Exception as e:
            if self.debug_mode:
                print(f"Context optimization failed: {e}")
            # Fall back to original context
        
        return request_data
    
    def post_response_hook(self, response_data: Dict[str, Any], 
                          request_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Hook after receiving API response
        Learn from success/failure to improve context selection
        """
        if not self.enabled:
            return response_data
        
        try:
            # Determine if request was successful
            success = self._evaluate_response_success(response_data)
            
            # Check if rejection was avoided by context chopping
            rejection_avoided = (
                'optimized_context_tokens' in request_data and
                success and
                request_data['original_context_tokens'] > 8000
            )
            
            if rejection_avoided:
                self.stats['rejections_prevented'] += 1
            
            # Update learning system
            if 'context' in request_data:
                self._update_learning_feedback(
                    request_data.get('prompt', ''),
                    request_data['context'],
                    success,
                    rejection_avoided
                )
        
        except Exception as e:
            if self.debug_mode:
                print(f"Post-response hook error: {e}")
        
        return response_data
    
    def _run_shadowgit_analysis(self, files: List[str]) -> Dict[str, Any]:
        """Run shadowgit AVX2 analysis on changed files (930M lines/sec)"""
        try:
            # Use shadowgit's batch processing for speed
            cmd = ['shadowgit', 'analyze', '--batch', '--avx2'] + files
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=5  # Should be very fast with AVX2
            )
            
            if result.returncode == 0:
                return json.loads(result.stdout)
            
        except Exception as e:
            if self.debug_mode:
                print(f"Shadowgit analysis failed: {e}")
        
        return {"error": "shadowgit analysis failed", "fallback_used": True}
    
    def _should_process_file(self, file_path: str) -> bool:
        """Determine if file should be processed for context chunking"""
        
        # Skip binary and unwanted files
        skip_patterns = [
            '.git/', '__pycache__/', 'node_modules/', '.venv/',
            '.pyc', '.so', '.exe', '.bin', '.jpg', '.png', '.gif'
        ]
        
        if any(pattern in file_path for pattern in skip_patterns):
            return False
        
        # Process code and documentation files
        process_extensions = [
            '.py', '.js', '.ts', '.jsx', '.tsx', '.md', '.txt',
            '.yaml', '.yml', '.json', '.sql', '.sh', '.bat',
            '.rs', '.go', '.java', '.cpp', '.c', '.h'
        ]
        
        return any(file_path.endswith(ext) for ext in process_extensions)
    
    def _store_chunks_in_db(self, chunks: List[ContextChunk], repo_path: str):
        """Store context chunks in PostgreSQL database"""
        conn = self._get_db_connection_sync()
        if not conn:
            return
        
        try:
            with conn.cursor() as cur:
                for chunk in chunks:
                    # Generate content hash for deduplication
                    content_hash = hashlib.md5(chunk.content.encode()).hexdigest()
                    
                    # Insert or update chunk
                    cur.execute("""
                        INSERT INTO context_chopping.context_chunks (
                            file_path, project_path, content, content_hash,
                            start_line, end_line, token_count, 
                            base_relevance_score, current_relevance_score,
                            security_level, language, file_type
                        ) VALUES (
                            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                        ) ON CONFLICT (content_hash) DO UPDATE SET
                            current_relevance_score = EXCLUDED.current_relevance_score,
                            last_modified = NOW()
                    """, (
                        chunk.file_path, repo_path, chunk.content, content_hash,
                        chunk.start_line, chunk.end_line, chunk.token_count,
                        chunk.relevance_score, chunk.relevance_score,
                        chunk.security_level, self._detect_language(chunk.file_path),
                        Path(chunk.file_path).suffix
                    ))
            
            conn.commit()
            
        except Exception as e:
            if self.debug_mode:
                print(f"Database storage error: {e}")
            conn.rollback()
        finally:
            conn.close()
    
    def _record_context_usage(self, query: str, context: str, tokens_saved: int):
        """Record context usage for learning"""
        conn = self._get_db_connection_sync()
        if not conn:
            return
        
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO context_chopping.query_patterns (
                        query_text, total_tokens_used, tokens_saved
                    ) VALUES (%s, %s, %s)
                """, (query, len(context.split()), tokens_saved))
            
            conn.commit()
        except Exception as e:
            if self.debug_mode:
                print(f"Usage recording error: {e}")
        finally:
            conn.close()
    
    def _determine_security_level(self, request_data: Dict) -> str:
        """Determine security level from request context"""
        context = request_data.get('context', '').lower()
        
        if any(word in context for word in ['secret', 'password', 'key', 'token']):
            return 'sensitive'
        elif any(word in context for word in ['internal', 'private', 'confidential']):
            return 'internal'
        else:
            return 'public'
    
    def _evaluate_response_success(self, response_data: Dict) -> bool:
        """Evaluate if API response was successful"""
        # Check for common success indicators
        if response_data.get('error'):
            return False
        
        if response_data.get('status') == 'success':
            return True
        
        # Check response content for error indicators
        content = str(response_data.get('content', '')).lower()
        error_indicators = ['error', 'failed', 'cannot', 'unable', 'invalid']
        
        return not any(indicator in content for indicator in error_indicators)
    
    def _update_learning_feedback(self, query: str, context: str, 
                                 success: bool, rejection_avoided: bool):
        """Update learning system with feedback"""
        conn = self._get_db_connection_sync()
        if not conn:
            return
        
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO context_chopping.learning_feedback (
                        query_pattern_id, context_was_sufficient, 
                        task_completed, rejection_avoided
                    ) SELECT 
                        pattern_id, %s, %s, %s
                    FROM context_chopping.query_patterns 
                    WHERE query_text = %s 
                    ORDER BY timestamp DESC 
                    LIMIT 1
                """, (success, success, rejection_avoided, query))
            
            conn.commit()
        except Exception as e:
            if self.debug_mode:
                print(f"Learning feedback error: {e}")
        finally:
            conn.close()
    
    def _detect_language(self, file_path: str) -> str:
        """Detect programming language from file extension"""
        ext_map = {
            '.py': 'python', '.js': 'javascript', '.ts': 'typescript',
            '.rs': 'rust', '.go': 'go', '.java': 'java',
            '.cpp': 'cpp', '.c': 'c', '.h': 'c',
            '.sql': 'sql', '.sh': 'bash', '.yaml': 'yaml',
            '.yml': 'yaml', '.json': 'json', '.md': 'markdown'
        }
        
        ext = Path(file_path).suffix.lower()
        return ext_map.get(ext, 'unknown')
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get hook system statistics"""
        return {
            **self.stats,
            'enabled': self.enabled,
            'debug_mode': self.debug_mode,
            'shadowgit_available': self.chopper.shadowgit_available,
            'database_connected': self._get_db_connection_sync() is not None
        }

# Global hook manager instance
hook_manager = ContextChoppingHookManager()

# Entry points for different hooks
def git_pre_commit_hook(repo_path: str = None, files_changed: List[str] = None):
    """Git pre-commit hook entry point"""
    if repo_path is None:
        repo_path = os.getcwd()
    
    if files_changed is None:
        # Get changed files from git
        try:
            result = subprocess.run(
                ['git', 'diff', '--cached', '--name-only'],
                capture_output=True,
                text=True,
                cwd=repo_path
            )
            files_changed = result.stdout.strip().split('\n') if result.stdout.strip() else []
        except:
            files_changed = []
    
    return hook_manager.pre_commit_hook(repo_path, files_changed)

def claude_pre_request_hook(request_data: Dict[str, Any]) -> Dict[str, Any]:
    """Claude API pre-request hook entry point"""
    return hook_manager.pre_request_hook(request_data)

def claude_post_response_hook(response_data: Dict[str, Any], 
                             request_data: Dict[str, Any]) -> Dict[str, Any]:
    """Claude API post-response hook entry point"""
    return hook_manager.post_response_hook(response_data, request_data)

# CLI interface for testing
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Context Chopping Hooks System")
    parser.add_argument('--test-precommit', action='store_true', 
                       help='Test pre-commit hook')
    parser.add_argument('--stats', action='store_true', 
                       help='Show statistics')
    parser.add_argument('--debug', action='store_true', 
                       help='Enable debug mode')
    
    args = parser.parse_args()
    
    if args.debug:
        hook_manager.debug_mode = True
    
    if args.test_precommit:
        result = git_pre_commit_hook()
        print(f"Pre-commit hook result: {json.dumps(result, indent=2)}")
    
    if args.stats:
        stats = hook_manager.get_statistics()
        print(f"Hook system statistics: {json.dumps(stats, indent=2)}")