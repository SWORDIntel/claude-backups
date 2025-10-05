#!/usr/bin/env python3
"""
Rejection Reduction Integration System
Connects the rejection reducer with existing context chopping and learning systems
"""

import os
import sys
import json
import asyncio
import logging
from typing import Dict, List, Optional, Any, Tuple

# Import existing systems
sys.path.append(os.path.join(os.path.dirname(__file__)))
from claude_rejection_reducer import ClaudeRejectionReducer, StrategyResult
from intelligent_context_chopper import IntelligentContextChopper, ContextWindow, ContextChunk
from permission_fallback_system import PermissionFallbackSystem

# Database integration for learning
try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
    DB_AVAILABLE = True
except ImportError:
    DB_AVAILABLE = False
    logging.warning("psycopg2 not available - learning features disabled")

logger = logging.getLogger('rejection_integration')

class UnifiedClaudeOptimizer:
    """
    Unified system that combines:
    - 85x Context Chopping performance
    - Rejection Reduction strategies 
    - PostgreSQL Learning integration
    - Permission Fallback system
    """
    
    def __init__(self, 
                 max_context_tokens: int = 8000,
                 enable_rejection_reduction: bool = True,
                 enable_learning: bool = True,
                 db_connection_string: str = None):
        """Initialize the unified optimizer"""
        
        # Core components
        self.context_chopper = IntelligentContextChopper(
            max_context_tokens=max_context_tokens,
            security_mode=True,
            use_shadowgit=True
        )
        
        self.rejection_reducer = ClaudeRejectionReducer(
            db_connection_string=db_connection_string,
            enable_learning=enable_learning
        ) if enable_rejection_reduction else None
        
        self.permission_system = PermissionFallbackSystem()
        
        # Configuration
        self.enable_rejection_reduction = enable_rejection_reduction
        self.enable_learning = enable_learning
        self.db_connection = db_connection_string or self._get_db_connection()
        
        # Performance tracking
        self.performance_metrics = {
            'total_requests': 0,
            'context_optimized': 0,
            'rejections_reduced': 0,
            'permission_bypassed': 0,
            'average_processing_time': 0.0,
            'acceptance_rate': 0.0,
            'context_reduction_ratio': 0.0
        }
        
        # Integration status
        self.systems_status = {
            'context_chopping': True,
            'rejection_reduction': enable_rejection_reduction,
            'learning_system': enable_learning and DB_AVAILABLE,
            'permission_fallback': True
        }
        
        logger.info("Unified Claude Optimizer initialized")
        logger.info(f"Systems enabled: {[k for k, v in self.systems_status.items() if v]}")
    
    async def optimize_for_claude(self,
                                content: str,
                                file_paths: List[str] = None,
                                request_type: str = "general",
                                context_hint: str = None) -> Tuple[str, Dict[str, Any]]:
        """
        Main optimization pipeline with tiered, auto-escalating strategies.
        """
        import time
        start_time = time.time()
        self.performance_metrics['total_requests'] += 1

        metadata = {
            'original_length': len(content), 'original_token_count': self._estimate_tokens(content),
            'optimizations_applied': [], 'processing_time': 0.0,
            'acceptance_predicted': True, 'systems_used': [], 'tier_used': 1
        }

        # Initial content processing (permissions, context chopping)
        if file_paths and self.systems_status['permission_fallback']:
            permission_note = await self._handle_file_permissions(file_paths)
            if permission_note:
                content = f"{permission_note}\n\n{content}"
                metadata['optimizations_applied'].append('permission_optimization')

        code_chunks = [ContextChunk(content, "input.py", 0, 0, 0.0, 0, "")]
        if self.systems_status['context_chopping']:
            code_chunks = await self._apply_enhanced_context_chopping(content, file_paths, request_type, context_hint)
            metadata['systems_used'].append('context_chopping')
            if len(code_chunks) > 1 or (code_chunks and code_chunks[0].content != content):
                 metadata['optimizations_applied'].append('intelligent_context_chopping')

        # Tiered auto-escalation loop
        final_chunks = []
        max_tier = 3
        for tier in range(1, max_tier + 1):
            metadata['tier_used'] = tier
            tier_successful = True
            processed_chunks_for_tier = []

            for chunk in code_chunks:
                chunk_content = chunk.content
                if self.systems_status['rejection_reduction'] and self.rejection_reducer:
                    reduced_content, res = await self.rejection_reducer.process_request(
                        chunk_content, request_type, [chunk.file_path], tier=tier
                    )
                    if res == StrategyResult.REJECTED:
                        tier_successful = False
                        logger.warning(f"Tier {tier} failed for chunk {chunk.file_path}. Escalating...")
                        break  # Escalate to next tier for all chunks
                    
                    chunk_content = reduced_content
                    if 'rejection_reduction' not in metadata['optimizations_applied']:
                        metadata['optimizations_applied'].append('rejection_reduction')

                header = f"# File: {chunk.file_path} (lines {chunk.start_line}-{chunk.end_line})"
                processed_chunks_for_tier.append(f"{header}\n{chunk_content}")

            if tier_successful:
                final_chunks = processed_chunks_for_tier
                break  # Success, exit the tier loop

            if not tier_successful and tier == max_tier:
                logger.error("All tiers failed to process the content. Returning original.")
                final_chunks = [f"# File: {c.file_path}\n{c.content}" for c in code_chunks] # Fallback
                metadata['acceptance_predicted'] = False


        final_content = "\n\n".join(final_chunks)

        # Finalize and record
        metadata['final_length'] = len(final_content)
        metadata['final_token_count'] = self._estimate_tokens(final_content)
        metadata['compression_ratio'] = metadata['final_length'] / (metadata['original_length'] or 1)
        metadata['processing_time'] = time.time() - start_time
        self._update_performance_metrics(metadata)

        if self.systems_status['learning_system']:
            await self._store_optimization_result(content, final_content, metadata, request_type)

        return final_content, metadata

    async def _handle_file_permissions(self, file_paths: List[str]) -> Optional[str]:
        """Handle file permission issues and return a note if any are found."""
        for file_path in file_paths:
            if not os.path.exists(file_path):
                return f"# PERMISSION ISSUE: File not found: {file_path}"
            if not os.access(file_path, os.R_OK):
                return f"# PERMISSION ISSUE: No read access: {file_path}"
        return None
    
    async def _apply_enhanced_context_chopping(self,
                                             content: str,
                                             file_paths: List[str] = None,
                                             request_type: str = "general",
                                             context_hint: str = None) -> List[ContextChunk]:
        """
        Apply context chopping and return a list of content chunks.
        """
        chopping_config = {
            'max_tokens': 8000,
            'preserve_structure': True,
            'security_filtering': True,
        }
        
        import tempfile
        import os

        effective_file_paths = file_paths or []
        tmp_path = None

        # If we only have content, write it to a temp file for the chopper
        if not effective_file_paths and len(content) > 0:
            try:
                with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=".py") as tmp:
                    tmp.write(content)
                    tmp_path = tmp.name
                effective_file_paths.append(tmp_path)
            except Exception as e:
                logger.warning(f"Could not create temp file for context chopping: {e}")

        try:
            context_window = await self.context_chopper.get_optimized_context(
                query=context_hint or request_type,
                files=effective_file_paths,
                max_tokens=chopping_config['max_tokens'],
                security_mode=chopping_config['security_filtering']
            )
            
            if context_window and context_window.chunks:
                return context_window.chunks
            
        except Exception as e:
            logger.warning(f"Enhanced context chopping failed: {e}")
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)

        # Fallback to returning the original content as a single chunk
        pseudo_path = (file_paths[0] if file_paths else "input.py")
        return [ContextChunk(
            content=content,
            file_path=pseudo_path,
            start_line=0,
            end_line=content.count('\n'),
            relevance_score=0.5,  # Default relevance
            token_count=self._estimate_tokens(content),
            security_level="cleared"
        )]
    
    async def _store_optimization_result(self, 
                                       original_content: str,
                                       optimized_content: str,
                                       metadata: Dict[str, Any],
                                       request_type: str):
        """Store optimization results in learning system"""
        
        if not DB_AVAILABLE:
            return
        
        try:
            # Connect to PostgreSQL Docker container
            conn = psycopg2.connect(self.db_connection)
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
            # Store optimization metrics
            insert_query = """
            INSERT INTO optimization_results (
                original_length, optimized_length, compression_ratio,
                processing_time, optimizations_applied, request_type,
                acceptance_predicted, systems_used, created_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
            """
            
            cursor.execute(insert_query, (
                metadata['original_length'],
                metadata['final_length'],
                metadata['compression_ratio'],
                metadata['processing_time'],
                json.dumps(metadata['optimizations_applied']),
                request_type,
                metadata['acceptance_predicted'],
                json.dumps(metadata['systems_used'])
            ))
            
            conn.commit()
            cursor.close()
            conn.close()
            
        except Exception as e:
            logger.warning(f"Failed to store optimization result: {e}")
    
    def _update_performance_metrics(self, metadata: Dict[str, Any]):
        """Update internal performance tracking"""
        
        # Update averages
        total = self.performance_metrics['total_requests']
        current_avg_time = self.performance_metrics['average_processing_time']
        
        self.performance_metrics['average_processing_time'] = (
            (current_avg_time * (total - 1) + metadata['processing_time']) / total
        )
        
        # Update context reduction ratio
        if metadata['compression_ratio'] < 1.0:
            current_ratio = self.performance_metrics['context_reduction_ratio']
            self.performance_metrics['context_reduction_ratio'] = (
                (current_ratio * (total - 1) + metadata['compression_ratio']) / total
            )
        
        # Update acceptance rate prediction
        if metadata['acceptance_predicted']:
            success_count = sum([
                self.performance_metrics['context_optimized'],
                self.performance_metrics['rejections_reduced'],
                self.performance_metrics['permission_bypassed']
            ])
            self.performance_metrics['acceptance_rate'] = success_count / total
    
    def _estimate_tokens(self, content: str) -> int:
        """Estimate token count (same as rejection reducer)"""
        word_count = len(content.split())
        return int(word_count * 0.75)
    
    def _get_db_connection(self) -> str:
        """Get database connection string for PostgreSQL Docker container"""
        return "postgresql://claude_agent:secure_password@localhost:5433/claude_agents_auth"
    
    async def get_system_status(self) -> Dict[str, Any]:
        """Get comprehensive system status"""
        
        status = {
            'systems_enabled': self.systems_status,
            'performance_metrics': self.performance_metrics,
            'component_status': {
                'context_chopper': 'operational' if self.context_chopper else 'disabled',
                'rejection_reducer': 'operational' if self.rejection_reducer else 'disabled', 
                'permission_system': 'operational' if self.permission_system else 'disabled',
                'learning_system': 'operational' if DB_AVAILABLE else 'unavailable'
            },
            'optimization_effectiveness': {
                'context_reduction': f"{(1 - self.performance_metrics['context_reduction_ratio']) * 100:.1f}%",
                'predicted_acceptance': f"{self.performance_metrics['acceptance_rate'] * 100:.1f}%",
                'avg_processing_time': f"{self.performance_metrics['average_processing_time']:.3f}s"
            }
        }
        
        return status
    
    async def optimize_claude_wrapper_content(self, 
                                            content: str, 
                                            **kwargs) -> str:
        """Simplified interface for Claude wrapper integration"""
        
        optimized_content, metadata = await self.optimize_for_claude(
            content, **kwargs
        )
        
        # Log optimization for debugging
        if metadata['optimizations_applied']:
            logger.info(f"Applied optimizations: {metadata['optimizations_applied']}")
            logger.info(f"Compression: {metadata['compression_ratio']:.2f}, "
                       f"Time: {metadata['processing_time']:.3f}s")
        
        return optimized_content


class ClaudeWrapperIntegration:
    """
    Integration layer for existing Claude wrappers and tools
    Provides simple interfaces while maintaining full optimization power
    """
    
    def __init__(self):
        self.optimizer = UnifiedClaudeOptimizer(
            enable_rejection_reduction=True,
            enable_learning=True
        )
    
    async def process_claude_request(self, 
                                   content: str,
                                   command_type: str = "general",
                                   files: List[str] = None) -> str:
        """
        Simple interface for Claude wrapper integration
        
        Usage in existing wrappers:
        ```python
        from rejection_reduction_integration import ClaudeWrapperIntegration
        
        integration = ClaudeWrapperIntegration()
        optimized_content = await integration.process_claude_request(
            content=user_input,
            command_type="code_analysis", 
            files=["file1.py", "file2.js"]
        )
        # Send optimized_content to Claude instead of raw content
        ```
        """
        
        return await self.optimizer.optimize_claude_wrapper_content(
            content=content,
            request_type=command_type,
            file_paths=files or []
        )
    
    def get_integration_status(self) -> Dict[str, Any]:
        """Get status for wrapper integration"""
        return asyncio.run(self.optimizer.get_system_status())


# Global instance for easy integration
_global_integration = None

def get_claude_optimizer() -> ClaudeWrapperIntegration:
    """Get global Claude optimizer instance"""
    global _global_integration
    if _global_integration is None:
        _global_integration = ClaudeWrapperIntegration()
    return _global_integration

# Convenience functions for direct integration
async def optimize_for_claude_simple(content: str, 
                                   files: List[str] = None,
                                   request_type: str = "general") -> str:
    """Simple function for direct integration with existing tools"""
    integration = get_claude_optimizer()
    return await integration.process_claude_request(content, request_type, files)

def get_optimization_status() -> Dict[str, Any]:
    """Get current optimization system status"""
    integration = get_claude_optimizer()
    return integration.get_integration_status()


if __name__ == "__main__":
    # Test the integration system
    async def test_integration():
        print("Testing Unified Claude Optimizer Integration...")
        
        integration = ClaudeWrapperIntegration()
        
        test_content = """
        # Example security analysis
        def check_vulnerabilities():
            password = "admin123"
            api_key = "sk-proj-abcd1234"
            
            # This would normally trigger rejections
            exploit_data = create_payload()
            backdoor_access = establish_connection()
            
            return analyze_security_issues()
        """
        
        optimized = await integration.process_claude_request(
            content=test_content,
            command_type="security_analysis",
            files=["security_check.py"]
        )
        
        print(f"\nOriginal length: {len(test_content)}")
        print(f"Optimized length: {len(optimized)}")
        print(f"Compression: {len(optimized)/len(test_content):.2f}")
        
        status = integration.get_integration_status()
        print(f"\nSystem Status:")
        print(f"- Systems enabled: {list(status['systems_enabled'].keys())}")
        print(f"- Processing time: {status['performance_metrics']['average_processing_time']:.3f}s")
        print(f"- Predicted acceptance: {status['optimization_effectiveness']['predicted_acceptance']}")
        
        print("\nOptimized content preview:")
        print("="*50)
        print(optimized[:300] + "..." if len(optimized) > 300 else optimized)
    
    asyncio.run(test_integration())