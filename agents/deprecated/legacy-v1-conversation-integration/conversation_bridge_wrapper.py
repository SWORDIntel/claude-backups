#!/usr/bin/env python3
"""
Conversation Bridge Python Wrapper
High-performance Python interface to the C conversation-agent bridge

Provides:
- Pythonic API with async/await support
- Automatic memory management
- Type safety with dataclasses
- Integration with existing Python agent system
- Performance monitoring and debugging tools
"""

import asyncio
import ctypes
import json
import logging
import os
import threading
import time
import weakref
from ctypes import (
    c_char_p, c_int, c_uint64, c_uint32, c_float, c_size_t, c_void_p,
    Structure, POINTER, byref, create_string_buffer
)
from dataclasses import dataclass, field
from enum import Enum, IntEnum
from pathlib import Path
from typing import Dict, List, Any, Optional, Callable, AsyncGenerator, Union
import queue

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ConversationState(IntEnum):
    """Conversation states matching C enum"""
    ACTIVE = 0
    THINKING = 1
    AGENT_WORKING = 2
    STREAMING = 3
    COMPLETE = 4
    ERROR = 5


class IntegrationMode(IntEnum):
    """Integration modes matching C definitions"""
    TRANSPARENT = 0
    COLLABORATIVE = 1
    INTERACTIVE = 2
    DIAGNOSTIC = 3


# C structure definitions
class PerformanceStats(Structure):
    """Performance statistics structure"""
    _fields_ = [
        ("total_messages_processed", c_uint64),
        ("total_agent_invocations", c_uint64), 
        ("average_response_time_ns", c_uint64),
        ("peak_concurrent_conversations", c_uint32),
        ("active_conversations", c_uint32),
        ("uptime_seconds", c_uint64)
    ]


class StreamChunk(Structure):
    """Stream chunk structure"""
    _fields_ = [
        ("content", c_char_p),
        ("content_len", c_size_t),
        ("source_type", c_char_p),
        ("source_id", c_char_p),
        ("chunk_type", c_char_p),
        ("is_partial", c_int),
        ("timestamp_ns", c_uint64),
        ("metadata", c_void_p)
    ]


@dataclass
class PythonStreamChunk:
    """Python-friendly stream chunk"""
    content: str
    source_type: str  # "conversation", "agent", "system"
    source_id: str
    chunk_type: str  # "text", "code", "data", "metadata"
    is_partial: bool
    timestamp_ns: int
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ConversationMetrics:
    """Conversation-specific metrics"""
    conversation_id: str
    message_count: int
    agent_invocations: int
    total_response_time_ms: float
    average_response_time_ms: float
    active_agents: List[str]
    state: ConversationState
    created_at: float
    last_activity: float


class ConversationBridgeError(Exception):
    """Base exception for conversation bridge errors"""
    pass


class ConversationNotFoundError(ConversationBridgeError):
    """Conversation not found error"""
    pass


class QueueFullError(ConversationBridgeError):
    """Message queue full error"""
    pass


class ConversationBridge:
    """High-performance Python wrapper for conversation-agent integration"""
    
    def __init__(self, library_path: Optional[str] = None):
        self.library_path = library_path or self._find_library()
        self.lib = None
        self.initialized = False
        self.event_callbacks = {}
        self.stream_monitors = {}
        self._callback_refs = []  # Keep references to C callbacks
        
        # Performance monitoring
        self.start_time = time.time()
        self.message_count = 0
        self.error_count = 0
        
        # Thread safety
        self.lock = threading.RLock()
        
    def _find_library(self) -> str:
        """Find the conversation bridge shared library"""
        current_dir = Path(__file__).parent
        library_candidates = [
            current_dir / "libconversation_bridge.so",
            current_dir / "conversation_bridge.so",
            "/usr/local/lib/libconversation_bridge.so",
            "/usr/lib/libconversation_bridge.so"
        ]
        
        for lib_path in library_candidates:
            if lib_path.exists():
                return str(lib_path)
        
        # Try to compile if source exists
        source_path = current_dir / "conversation_agent_bridge.c"
        if source_path.exists():
            logger.info("Compiling conversation bridge library...")
            lib_path = current_dir / "libconversation_bridge.so"
            compile_cmd = (
                f"gcc -shared -fPIC -O3 -march=native -mtune=native "
                f"-flto -funroll-loops -DHAVE_LIBURING=1 "
                f"-o {lib_path} {source_path} "
                f"-lnuma -luring -lpthread -lm -ldl"
            )
            
            if os.system(compile_cmd) == 0:
                return str(lib_path)
            else:
                logger.warning("Failed to compile, using fallback implementation")
                return ""  # Will use fallback
        
        raise FileNotFoundError("Conversation bridge library not found")
    
    def initialize(self) -> None:
        """Initialize the conversation bridge"""
        if self.initialized:
            return
        
        if not self.library_path:
            logger.warning("Using fallback Python implementation")
            self._init_fallback()
            return
        
        # Load the C library
        try:
            self.lib = ctypes.CDLL(self.library_path)
        except OSError as e:
            logger.error(f"Failed to load library {self.library_path}: {e}")
            self._init_fallback()
            return
        
        # Define function signatures
        self._define_function_signatures()
        
        # Initialize the C system
        result = self.lib.conversation_bridge_init()
        if result != 0:
            raise ConversationBridgeError(f"Failed to initialize bridge: {result}")
        
        self.initialized = True
        logger.info("Conversation bridge initialized successfully")
    
    def _define_function_signatures(self):
        """Define C function signatures for proper calling"""
        if not self.lib:
            return
        
        # conversation_bridge_init
        self.lib.conversation_bridge_init.argtypes = []
        self.lib.conversation_bridge_init.restype = c_int
        
        # process_user_message
        self.lib.process_user_message.argtypes = [c_char_p, c_char_p, c_char_p, c_size_t]
        self.lib.process_user_message.restype = c_int
        
        # get_conversation_state
        self.lib.get_conversation_state.argtypes = [c_char_p]
        self.lib.get_conversation_state.restype = c_int
        
        # get_stream_chunk
        self.lib.get_stream_chunk.argtypes = [c_char_p, POINTER(StreamChunk)]
        self.lib.get_stream_chunk.restype = c_int
        
        # free_stream_chunk
        self.lib.free_stream_chunk.argtypes = [POINTER(StreamChunk)]
        self.lib.free_stream_chunk.restype = None
        
        # get_performance_stats (updated signature)
        self.lib.get_performance_stats.argtypes = [POINTER(PerformanceStats)]
        self.lib.get_performance_stats.restype = None
        
        # set_integration_mode
        self.lib.set_integration_mode.argtypes = [c_char_p, c_int]
        self.lib.set_integration_mode.restype = c_int
        
        # inject_agent_capability
        self.lib.inject_agent_capability.argtypes = [c_char_p, c_char_p, c_char_p, c_char_p, c_size_t]
        self.lib.inject_agent_capability.restype = c_int
        
        # conversation_bridge_shutdown
        self.lib.conversation_bridge_shutdown.argtypes = []
        self.lib.conversation_bridge_shutdown.restype = None
    
    def _init_fallback(self):
        """Initialize fallback Python implementation"""
        logger.info("Initializing fallback Python implementation")
        
        # Import the existing Python agent system
        try:
            from claude_conversation_integration import ConversationAgentBridge as FallbackBridge
            self.fallback = FallbackBridge()
            self.initialized = True
        except ImportError as e:
            logger.error(f"Failed to import fallback implementation: {e}")
            raise ConversationBridgeError("No implementation available")
    
    async def process_message(
        self,
        conversation_id: str,
        user_id: str,
        message: str,
        integration_mode: IntegrationMode = IntegrationMode.TRANSPARENT
    ) -> AsyncGenerator[PythonStreamChunk, None]:
        """Process user message and yield streaming responses"""
        
        if not self.initialized:
            self.initialize()
        
        self.message_count += 1
        
        if hasattr(self, 'fallback'):
            # Use fallback Python implementation
            async for response in self._process_message_fallback(
                conversation_id, user_id, message, integration_mode
            ):
                yield response
            return
        
        # Use C implementation
        try:
            # Set integration mode
            self.lib.set_integration_mode(
                conversation_id.encode('utf-8'),
                integration_mode.value
            )
            
            # Process message
            result = self.lib.process_user_message(
                conversation_id.encode('utf-8'),
                user_id.encode('utf-8'),
                message.encode('utf-8'),
                len(message.encode('utf-8'))
            )
            
            if result == -1:
                raise ConversationBridgeError("Failed to process message")
            elif result == -2:
                raise QueueFullError("Message queue is full")
            
            # Stream responses
            async for chunk in self._stream_responses(conversation_id):
                yield chunk
                
        except Exception as e:
            self.error_count += 1
            logger.error(f"Error processing message: {e}")
            
            # Yield error response
            yield PythonStreamChunk(
                content=f"Error processing message: {str(e)}",
                source_type="system",
                source_id="error_handler",
                chunk_type="text",
                is_partial=False,
                timestamp_ns=time.time_ns(),
                metadata={"error": True}
            )
    
    async def _process_message_fallback(
        self,
        conversation_id: str,
        user_id: str,
        message: str,
        integration_mode: IntegrationMode
    ) -> AsyncGenerator[PythonStreamChunk, None]:
        """Process message using fallback Python implementation"""
        
        try:
            # Start conversation if needed
            conv_context = await self.fallback.get_conversation_state(conversation_id)
            if not conv_context:
                conv_context = await self.fallback.start_conversation(
                    user_id=user_id,
                    session_id=None,
                    integration_mode=integration_mode
                )
            
            # Process message
            async for response in self.fallback.process_user_message(
                conversation_id, message
            ):
                yield PythonStreamChunk(
                    content=response.content,
                    source_type=response.source,
                    source_id=response.source_id,
                    chunk_type=response.chunk_type,
                    is_partial=response.is_partial,
                    timestamp_ns=int(response.timestamp.timestamp() * 1_000_000_000),
                    metadata=response.metadata
                )
                
        except Exception as e:
            logger.error(f"Fallback processing error: {e}")
            yield PythonStreamChunk(
                content=f"Fallback error: {str(e)}",
                source_type="system",
                source_id="fallback_error",
                chunk_type="text",
                is_partial=False,
                timestamp_ns=time.time_ns(),
                metadata={"error": True, "fallback": True}
            )
    
    async def _stream_responses(self, conversation_id: str) -> AsyncGenerator[PythonStreamChunk, None]:
        """Stream responses from C implementation"""
        
        chunk = StreamChunk()
        conversation_id_bytes = conversation_id.encode('utf-8')
        
        # Poll for chunks until conversation completes
        max_polls = 1000  # Prevent infinite loops
        poll_count = 0
        
        while poll_count < max_polls:
            result = self.lib.get_stream_chunk(conversation_id_bytes, byref(chunk))
            
            if result == 0:  # Chunk available
                # Convert C chunk to Python chunk
                python_chunk = PythonStreamChunk(
                    content=chunk.content.decode('utf-8') if chunk.content else "",
                    source_type=chunk.source_type.decode('utf-8') if chunk.source_type else "",
                    source_id=chunk.source_id.decode('utf-8') if chunk.source_id else "",
                    chunk_type=chunk.chunk_type.decode('utf-8') if chunk.chunk_type else "",
                    is_partial=bool(chunk.is_partial),
                    timestamp_ns=chunk.timestamp_ns,
                    metadata={}
                )
                
                # Parse metadata if available
                if chunk.metadata:
                    try:
                        metadata_str = ctypes.string_at(chunk.metadata).decode('utf-8')
                        python_chunk.metadata = json.loads(metadata_str)
                    except (json.JSONDecodeError, UnicodeDecodeError):
                        pass
                
                # Free the C chunk
                self.lib.free_stream_chunk(byref(chunk))
                
                yield python_chunk
                
                # Check if this is the final chunk
                if not python_chunk.is_partial and python_chunk.metadata.get("phase") == "complete":
                    break
                    
            elif result == -3:  # No chunks available
                # Wait a bit before polling again
                await asyncio.sleep(0.001)  # 1ms
                poll_count += 1
                
                # Check conversation state
                state = self.get_conversation_state(conversation_id)
                if state == ConversationState.COMPLETE or state == ConversationState.ERROR:
                    break
                    
            else:  # Error
                logger.error(f"Error getting stream chunk: {result}")
                break
    
    def get_conversation_state(self, conversation_id: str) -> ConversationState:
        """Get current conversation state"""
        
        if not self.initialized:
            self.initialize()
        
        if hasattr(self, 'fallback'):
            # Use fallback - map to our enum
            try:
                conv_context = asyncio.run(self.fallback.get_conversation_state(conversation_id))
                if not conv_context:
                    return ConversationState.ERROR
                
                # Map Python states to our enum
                state_mapping = {
                    "active": ConversationState.ACTIVE,
                    "thinking": ConversationState.THINKING,
                    "agent_working": ConversationState.AGENT_WORKING,
                    "streaming": ConversationState.STREAMING,
                    "complete": ConversationState.COMPLETE,
                    "error": ConversationState.ERROR
                }
                
                return state_mapping.get(conv_context.state.value, ConversationState.ERROR)
                
            except Exception as e:
                logger.error(f"Error getting fallback state: {e}")
                return ConversationState.ERROR
        
        # Use C implementation
        result = self.lib.get_conversation_state(conversation_id.encode('utf-8'))
        
        if result >= 0:
            return ConversationState(result)
        else:
            raise ConversationNotFoundError(f"Conversation {conversation_id} not found")
    
    def set_integration_mode(self, conversation_id: str, mode: IntegrationMode) -> None:
        """Set conversation integration mode"""
        
        if not self.initialized:
            self.initialize()
        
        if hasattr(self, 'fallback'):
            # Use fallback
            try:
                asyncio.run(self.fallback.update_integration_mode(conversation_id, mode))
            except Exception as e:
                logger.error(f"Error setting fallback integration mode: {e}")
            return
        
        # Use C implementation
        result = self.lib.set_integration_mode(
            conversation_id.encode('utf-8'),
            mode.value
        )
        
        if result != 0:
            raise ConversationBridgeError(f"Failed to set integration mode: {result}")
    
    async def inject_agent_capability(
        self,
        conversation_id: str,
        capability_name: str,
        parameters: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Inject specific agent capability into conversation"""
        
        if not self.initialized:
            self.initialize()
        
        if hasattr(self, 'fallback'):
            # Use fallback
            try:
                return await self.fallback.inject_agent_capability(
                    conversation_id, capability_name, parameters
                )
            except Exception as e:
                logger.error(f"Error injecting fallback capability: {e}")
                return {"error": str(e)}
        
        # Use C implementation
        parameters_json = json.dumps(parameters)
        result_buffer = create_string_buffer(4096)  # 4KB buffer
        
        result = self.lib.inject_agent_capability(
            conversation_id.encode('utf-8'),
            capability_name.encode('utf-8'),
            parameters_json.encode('utf-8'),
            result_buffer,
            4096
        )
        
        if result == 0:
            try:
                return json.loads(result_buffer.value.decode('utf-8'))
            except json.JSONDecodeError:
                return {"result": result_buffer.value.decode('utf-8')}
        else:
            raise ConversationBridgeError(f"Failed to inject capability: {result}")
    
    def get_performance_stats(self) -> Dict[str, Any]:
        """Get current performance statistics"""
        
        if not self.initialized:
            self.initialize()
        
        if hasattr(self, 'fallback'):
            # Return Python implementation stats
            uptime = time.time() - self.start_time
            return {
                "total_messages_processed": self.message_count,
                "total_agent_invocations": 0,  # Not tracked in fallback
                "average_response_time_ms": 0.0,  # Not tracked in fallback
                "peak_concurrent_conversations": 1,  # Simplified
                "active_conversations": len(getattr(self.fallback, 'active_conversations', {})),
                "uptime_seconds": int(uptime),
                "error_count": self.error_count,
                "implementation": "python_fallback"
            }
        
        # Use C implementation
        stats = PerformanceStats()
        self.lib.get_performance_stats(byref(stats))
        
        return {
            "total_messages_processed": stats.total_messages_processed,
            "total_agent_invocations": stats.total_agent_invocations,
            "average_response_time_ms": stats.average_response_time_ns / 1_000_000.0,
            "peak_concurrent_conversations": stats.peak_concurrent_conversations,
            "active_conversations": stats.active_conversations,
            "uptime_seconds": stats.uptime_seconds,
            "error_count": self.error_count,
            "implementation": "c_optimized"
        }
    
    def cleanup_inactive_conversations(self, max_inactive_seconds: int = 3600) -> int:
        """Clean up inactive conversations"""
        
        if not self.initialized:
            return 0
        
        if hasattr(self, 'fallback'):
            # Fallback cleanup
            try:
                asyncio.run(self.fallback._cleanup_inactive_conversations())
                return 1  # Simplified
            except Exception as e:
                logger.error(f"Fallback cleanup error: {e}")
                return 0
        
        # Use C implementation (would need to implement this function in C)
        # For now, return 0
        return 0
    
    def shutdown(self) -> None:
        """Shutdown the conversation bridge"""
        
        if not self.initialized:
            return
        
        if hasattr(self, 'fallback'):
            # No specific shutdown needed for fallback
            pass
        elif self.lib:
            self.lib.conversation_bridge_shutdown()
        
        self.initialized = False
        logger.info("Conversation bridge shut down")
    
    def __enter__(self):
        self.initialize()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.shutdown()


# Convenience functions for easy usage
_global_bridge = None

def get_bridge() -> ConversationBridge:
    """Get global conversation bridge instance"""
    global _global_bridge
    
    if _global_bridge is None:
        _global_bridge = ConversationBridge()
        _global_bridge.initialize()
    
    return _global_bridge


async def process_conversation_message(
    conversation_id: str,
    user_id: str,
    message: str,
    integration_mode: IntegrationMode = IntegrationMode.TRANSPARENT
) -> AsyncGenerator[PythonStreamChunk, None]:
    """Convenience function to process a message"""
    
    bridge = get_bridge()
    async for chunk in bridge.process_message(
        conversation_id, user_id, message, integration_mode
    ):
        yield chunk


# Demo and testing functions
async def demo_integration():
    """Demonstrate the conversation bridge integration"""
    
    print("Claude Conversation-Agent Bridge Demo")
    print("=====================================")
    
    bridge = ConversationBridge()
    
    try:
        bridge.initialize()
        print(f"Bridge initialized: {bridge.initialized}")
        
        # Show initial stats
        stats = bridge.get_performance_stats()
        print(f"Implementation: {stats['implementation']}")
        print(f"Initial stats: {stats}")
        
        # Process a test message
        conversation_id = "demo_conversation_001"
        user_id = "demo_user"
        message = "Analyze my Python code for performance issues and security vulnerabilities"
        
        print(f"\nUser: {message}")
        print("Claude (with agent coordination):")
        
        # Stream the response
        chunk_count = 0
        async for chunk in bridge.process_message(
            conversation_id, user_id, message, IntegrationMode.COLLABORATIVE
        ):
            if chunk.chunk_type == "text" and chunk.content.strip():
                print(chunk.content, end=" ", flush=True)
                chunk_count += 1
            
            # Show agent coordination updates
            if chunk.source_type == "agent":
                print(f"\n[Agent {chunk.source_id} update]", flush=True)
        
        print(f"\n\nResponse complete! ({chunk_count} chunks)")
        
        # Show final stats
        final_stats = bridge.get_performance_stats()
        print(f"Final stats: {final_stats}")
        
        # Show conversation state
        state = bridge.get_conversation_state(conversation_id)
        print(f"Conversation state: {state.name}")
        
    except Exception as e:
        print(f"Demo error: {e}")
        import traceback
        traceback.print_exc()
        
    finally:
        bridge.shutdown()
        print("\nDemo completed.")


if __name__ == "__main__":
    asyncio.run(demo_integration())