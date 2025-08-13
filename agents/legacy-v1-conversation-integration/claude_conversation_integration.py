#!/usr/bin/env python3
"""
Claude Conversation-Agent Deep Integration System
Real-time coordination between conversation system and agent orchestration

Features:
- Real-time agent coordination during user conversations
- Context sharing between conversation and agent systems
- Streaming response integration from agents to conversations
- Agent task spawning from conversation context
- Unified session management and state synchronization
- Message bridging between conversation and agent protocols
- Low-latency conversation integration with transparent orchestration
"""

import asyncio
import json
import uuid
import time
from typing import Dict, List, Any, Optional, AsyncGenerator, Callable, Union
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
import logging
from collections import defaultdict
import weakref
from contextlib import asynccontextmanager
import threading
from concurrent.futures import ThreadPoolExecutor
import queue
import traceback

# Import existing agent system
from ENHANCED_AGENT_INTEGRATION import (
    AgentOrchestrator, AgentCommunicationBridge, AgentMessage, 
    Priority, AgentStatus
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ConversationState(Enum):
    """Conversation states"""
    ACTIVE = "active"
    THINKING = "thinking"
    AGENT_WORKING = "agent_working"
    STREAMING = "streaming"
    COMPLETE = "complete"
    ERROR = "error"


class IntegrationMode(Enum):
    """Integration modes for different interaction types"""
    TRANSPARENT = "transparent"  # Agents work invisibly
    COLLABORATIVE = "collaborative"  # User sees agent coordination
    INTERACTIVE = "interactive"  # User can interact with agents
    DIAGNOSTIC = "diagnostic"  # Full visibility for debugging


@dataclass
class ConversationContext:
    """Enhanced conversation context with agent integration"""
    conversation_id: str
    user_id: str
    session_id: str
    state: ConversationState = ConversationState.ACTIVE
    integration_mode: IntegrationMode = IntegrationMode.TRANSPARENT
    
    # Conversation data
    messages: List[Dict[str, Any]] = field(default_factory=list)
    user_intent: Optional[str] = None
    current_task: Optional[str] = None
    
    # Agent coordination
    active_agents: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    agent_results: Dict[str, Any] = field(default_factory=dict)
    spawned_workflows: List[str] = field(default_factory=list)
    
    # Real-time streaming
    response_stream: Optional[AsyncGenerator] = None
    agent_streams: Dict[str, AsyncGenerator] = field(default_factory=dict)
    
    # Context preservation
    shared_context: Dict[str, Any] = field(default_factory=dict)
    conversation_embeddings: Optional[List[float]] = None
    
    # Performance tracking
    created_at: datetime = field(default_factory=datetime.now)
    last_activity: datetime = field(default_factory=datetime.now)
    response_times: List[float] = field(default_factory=list)


@dataclass
class StreamingResponse:
    """Streaming response from conversation or agents"""
    source: str  # "conversation", "agent", "system"
    source_id: str
    content: str
    chunk_type: str  # "text", "code", "data", "metadata"
    is_partial: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.now)


class ConversationAgentBridge:
    """Bridge between Claude conversation system and agent orchestration"""
    
    def __init__(self, max_concurrent_sessions: int = 100):
        # Agent system integration
        self.orchestrator = AgentOrchestrator()
        self.agent_bridge = AgentCommunicationBridge(self.orchestrator)
        
        # Conversation management
        self.active_conversations: Dict[str, ConversationContext] = {}
        self.session_registry: Dict[str, List[str]] = defaultdict(list)
        self.max_concurrent_sessions = max_concurrent_sessions
        
        # Real-time coordination
        self.event_bus = asyncio.Queue(maxsize=10000)
        self.stream_multiplexer = StreamMultiplexer()
        self.context_synchronizer = ContextSynchronizer()
        
        # Performance optimization
        self.response_cache = TTLCache(maxsize=1000, ttl=300)
        self.agent_pool = ThreadPoolExecutor(max_workers=20)
        
        # State management
        self.state_lock = asyncio.Lock()
        self.cleanup_interval = 300  # 5 minutes
        
        # Start background tasks
        self._start_background_tasks()
    
    def _start_background_tasks(self):
        """Start background coordination tasks"""
        asyncio.create_task(self._event_processor())
        asyncio.create_task(self._state_cleanup_task())
        asyncio.create_task(self._performance_monitor())
    
    async def start_conversation(
        self,
        user_id: str,
        session_id: Optional[str] = None,
        integration_mode: IntegrationMode = IntegrationMode.TRANSPARENT,
        context: Optional[Dict[str, Any]] = None
    ) -> ConversationContext:
        """Start a new conversation with agent integration"""
        
        conversation_id = str(uuid.uuid4())
        session_id = session_id or str(uuid.uuid4())
        
        # Check session limits
        if len(self.session_registry[user_id]) >= self.max_concurrent_sessions:
            await self._cleanup_oldest_session(user_id)
        
        # Create conversation context
        conv_context = ConversationContext(
            conversation_id=conversation_id,
            user_id=user_id,
            session_id=session_id,
            integration_mode=integration_mode,
            shared_context=context or {}
        )
        
        # Register conversation
        async with self.state_lock:
            self.active_conversations[conversation_id] = conv_context
            self.session_registry[user_id].append(conversation_id)
        
        # Initialize agent context sharing
        await self.context_synchronizer.initialize_conversation(conv_context)
        
        logger.info(f"Started conversation {conversation_id} for user {user_id}")
        return conv_context
    
    async def process_user_message(
        self,
        conversation_id: str,
        message: str,
        message_type: str = "text",
        metadata: Optional[Dict[str, Any]] = None
    ) -> AsyncGenerator[StreamingResponse, None]:
        """Process user message with real-time agent coordination"""
        
        conv_context = self.active_conversations.get(conversation_id)
        if not conv_context:
            raise ValueError(f"Conversation {conversation_id} not found")
        
        # Update conversation state
        conv_context.state = ConversationState.THINKING
        conv_context.last_activity = datetime.now()
        
        # Add message to history
        user_message = {
            "role": "user",
            "content": message,
            "type": message_type,
            "metadata": metadata or {},
            "timestamp": datetime.now()
        }
        conv_context.messages.append(user_message)
        
        try:
            # Analyze user intent and determine if agents needed
            analysis = await self._analyze_user_intent(conv_context, message)
            
            # Start response stream
            response_generator = self._create_response_stream(
                conv_context, analysis
            )
            
            async for response in response_generator:
                yield response
                
        except Exception as e:
            logger.error(f"Error processing message in {conversation_id}: {e}")
            conv_context.state = ConversationState.ERROR
            
            yield StreamingResponse(
                source="system",
                source_id="error_handler",
                content=f"I encountered an error: {str(e)}",
                chunk_type="text",
                is_partial=False,
                metadata={"error": True}
            )
    
    async def _analyze_user_intent(
        self, 
        conv_context: ConversationContext, 
        message: str
    ) -> Dict[str, Any]:
        """Analyze user message to determine intent and required agents"""
        
        # Intent classification patterns
        intent_patterns = {
            "code_analysis": [
                r"analyze.*code", r"review.*function", r"debug", r"optimize",
                r"performance.*issue", r"memory.*leak", r"bug.*fix"
            ],
            "system_design": [
                r"architect.*", r"design.*system", r"scalability", r"database.*design",
                r"api.*design", r"microservice", r"infrastructure"
            ],
            "security_analysis": [
                r"security.*audit", r"vulnerability", r"penetration.*test",
                r"encrypt", r"authentication", r"authorization"
            ],
            "deployment": [
                r"deploy", r"ci.*cd", r"docker", r"kubernetes", r"container",
                r"production.*ready"
            ],
            "data_analysis": [
                r"analyze.*data", r"machine.*learning", r"model.*training",
                r"statistics", r"visualization", r"prediction"
            ]
        }
        
        # Simple pattern matching (in production, use ML model)
        detected_intents = []
        for intent, patterns in intent_patterns.items():
            for pattern in patterns:
                import re
                if re.search(pattern, message.lower()):
                    detected_intents.append(intent)
                    break
        
        # Determine required agents based on intent
        agent_mapping = {
            "code_analysis": ["LINTER", "DEBUGGER", "OPTIMIZER"],
            "system_design": ["ARCHITECT", "DATABASE", "API_DESIGNER"],
            "security_analysis": ["SECURITY"],
            "deployment": ["DEPLOYER", "PACKAGER", "MONITOR"],
            "data_analysis": ["ML_OPS", "DATABASE"]
        }
        
        required_agents = []
        for intent in detected_intents:
            required_agents.extend(agent_mapping.get(intent, []))
        
        # Remove duplicates while preserving order
        required_agents = list(dict.fromkeys(required_agents))
        
        return {
            "intents": detected_intents,
            "required_agents": required_agents,
            "complexity": "high" if len(required_agents) > 2 else "medium" if required_agents else "low",
            "estimated_duration": len(required_agents) * 2 + 5,  # seconds
            "needs_agent_coordination": bool(required_agents)
        }
    
    async def _create_response_stream(
        self, 
        conv_context: ConversationContext, 
        analysis: Dict[str, Any]
    ) -> AsyncGenerator[StreamingResponse, None]:
        """Create unified response stream from conversation and agents"""
        
        conversation_id = conv_context.conversation_id
        
        # Start with immediate acknowledgment
        yield StreamingResponse(
            source="conversation",
            source_id=conversation_id,
            content="I'm processing your request",
            chunk_type="text",
            is_partial=True,
            metadata={"phase": "acknowledgment"}
        )
        
        if analysis["needs_agent_coordination"]:
            # Show agent coordination if not in transparent mode
            if conv_context.integration_mode != IntegrationMode.TRANSPARENT:
                yield StreamingResponse(
                    source="system",
                    source_id="coordinator",
                    content=f"Coordinating with {len(analysis['required_agents'])} specialist agents...",
                    chunk_type="text",
                    is_partial=True,
                    metadata={
                        "agents": analysis['required_agents'],
                        "phase": "coordination"
                    }
                )
            
            # Start agent workflows
            conv_context.state = ConversationState.AGENT_WORKING
            agent_tasks = []
            
            for agent_id in analysis['required_agents']:
                task = asyncio.create_task(
                    self._spawn_agent_task(conv_context, agent_id, analysis)
                )
                agent_tasks.append(task)
            
            # Stream agent results as they complete
            completed_agents = []
            async for agent_result in self._stream_agent_results(agent_tasks):
                completed_agents.append(agent_result["agent_id"])
                
                # Store result in conversation context
                conv_context.agent_results[agent_result["agent_id"]] = agent_result
                
                # Stream progress updates
                if conv_context.integration_mode in [IntegrationMode.COLLABORATIVE, IntegrationMode.INTERACTIVE]:
                    yield StreamingResponse(
                        source="agent",
                        source_id=agent_result["agent_id"],
                        content=agent_result.get("summary", f"{agent_result['agent_id']} completed"),
                        chunk_type="text",
                        is_partial=True,
                        metadata={
                            "agent_result": agent_result,
                            "phase": "agent_execution"
                        }
                    )
        
        # Generate main conversation response
        conv_context.state = ConversationState.STREAMING
        
        # Synthesize response from conversation model and agent results
        response_content = await self._synthesize_response(conv_context, analysis)
        
        # Stream the synthesized response
        for chunk in self._chunk_response(response_content):
            yield StreamingResponse(
                source="conversation",
                source_id=conversation_id,
                content=chunk,
                chunk_type="text",
                is_partial=True,
                metadata={"phase": "main_response"}
            )
            
            # Add small delay for realistic streaming
            await asyncio.sleep(0.02)
        
        # Final completion marker
        conv_context.state = ConversationState.COMPLETE
        yield StreamingResponse(
            source="conversation",
            source_id=conversation_id,
            content="",
            chunk_type="text",
            is_partial=False,
            metadata={"phase": "complete", "total_agents": len(analysis['required_agents'])}
        )
    
    async def _spawn_agent_task(
        self, 
        conv_context: ConversationContext, 
        agent_id: str, 
        analysis: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Spawn individual agent task with conversation context"""
        
        # Prepare agent message with conversation context
        message = AgentMessage(
            source_agent="CONVERSATION_BRIDGE",
            target_agents=[agent_id],
            action="analyze_from_conversation",
            payload={
                "conversation_history": conv_context.messages[-5:],  # Last 5 messages
                "user_intent": analysis["intents"],
                "shared_context": conv_context.shared_context,
                "urgency": "high" if analysis["complexity"] == "high" else "medium"
            },
            context={
                "conversation_id": conv_context.conversation_id,
                "user_id": conv_context.user_id,
                "session_id": conv_context.session_id
            },
            priority=Priority.HIGH
        )
        
        # Mark agent as active
        conv_context.active_agents[agent_id] = {
            "status": AgentStatus.RUNNING,
            "started_at": datetime.now(),
            "message_id": message.message_id
        }
        
        # Execute agent (simulated for this implementation)
        result = await self._execute_agent_with_context(agent_id, message)
        
        # Update agent status
        conv_context.active_agents[agent_id]["status"] = AgentStatus.COMPLETED
        conv_context.active_agents[agent_id]["completed_at"] = datetime.now()
        
        return result
    
    async def _execute_agent_with_context(
        self, 
        agent_id: str, 
        message: AgentMessage
    ) -> Dict[str, Any]:
        """Execute agent with full conversation context"""
        
        # Simulate agent processing time based on agent type
        processing_times = {
            "LINTER": 1.0,
            "DEBUGGER": 2.5,
            "OPTIMIZER": 3.0,
            "ARCHITECT": 4.0,
            "SECURITY": 2.0,
            "DATABASE": 2.0,
            "API_DESIGNER": 1.5,
            "DEPLOYER": 2.5,
            "ML_OPS": 3.5,
            "MONITOR": 1.0
        }
        
        processing_time = processing_times.get(agent_id, 2.0)
        await asyncio.sleep(processing_time * 0.1)  # Reduced for demo
        
        # Generate agent-specific response
        agent_responses = {
            "LINTER": {
                "summary": "Code analysis complete - found 3 style issues",
                "findings": ["Unused import on line 15", "Long line on line 42", "Missing docstring"],
                "suggestions": ["Remove unused imports", "Break long lines", "Add documentation"]
            },
            "DEBUGGER": {
                "summary": "No critical bugs found, 2 potential issues identified",
                "issues": ["Potential null pointer access", "Race condition in thread pool"],
                "recommendations": ["Add null checks", "Implement proper synchronization"]
            },
            "OPTIMIZER": {
                "summary": "Performance optimization opportunities identified",
                "bottlenecks": ["Database query N+1 problem", "Inefficient loop in hot path"],
                "improvements": ["Implement query batching", "Optimize inner loop"]
            },
            "ARCHITECT": {
                "summary": "System design analysis complete",
                "architecture": {"pattern": "microservices", "scalability": "horizontal"},
                "recommendations": ["Consider event sourcing", "Implement caching layer"]
            },
            "SECURITY": {
                "summary": "Security scan complete - 1 medium issue found",
                "vulnerabilities": ["Weak password policy"],
                "mitigations": ["Implement stronger password requirements"]
            }
        }
        
        base_response = {
            "agent_id": agent_id,
            "status": "success",
            "execution_time": processing_time * 0.1,
            "timestamp": datetime.now()
        }
        
        # Add agent-specific content
        base_response.update(agent_responses.get(agent_id, {
            "summary": f"{agent_id} analysis complete",
            "result": "Generic analysis completed"
        }))
        
        return base_response
    
    async def _stream_agent_results(
        self, 
        agent_tasks: List[asyncio.Task]
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """Stream agent results as they complete"""
        
        completed_tasks = []
        
        while len(completed_tasks) < len(agent_tasks):
            # Wait for any task to complete
            done, pending = await asyncio.wait(
                agent_tasks, 
                return_when=asyncio.FIRST_COMPLETED
            )
            
            # Process completed tasks
            for task in done:
                if task not in completed_tasks:
                    completed_tasks.append(task)
                    try:
                        result = await task
                        yield result
                    except Exception as e:
                        logger.error(f"Agent task failed: {e}")
                        yield {
                            "agent_id": "unknown",
                            "status": "failed",
                            "error": str(e)
                        }
    
    async def _synthesize_response(
        self, 
        conv_context: ConversationContext, 
        analysis: Dict[str, Any]
    ) -> str:
        """Synthesize final response combining conversation and agent results"""
        
        user_message = conv_context.messages[-1]["content"]
        agent_results = conv_context.agent_results
        
        if not agent_results:
            # Simple conversational response
            return f"I understand you're asking about: {user_message}. Let me help you with that."
        
        # Synthesize response with agent findings
        response_parts = [
            f"Based on my analysis of your request about: {user_message}\n"
        ]
        
        # Add agent findings
        for agent_id, result in agent_results.items():
            if result.get("status") == "success":
                summary = result.get("summary", f"{agent_id} completed analysis")
                response_parts.append(f"\n**{agent_id} Analysis:**\n{summary}")
                
                # Add specific findings if available
                if "findings" in result:
                    response_parts.append(f"- Issues found: {', '.join(result['findings'])}")
                if "recommendations" in result:
                    response_parts.append(f"- Recommendations: {', '.join(result['recommendations'])}")
                if "suggestions" in result:
                    response_parts.append(f"- Suggestions: {', '.join(result['suggestions'])}")
        
        # Add conclusion
        response_parts.append(f"\n\nI've coordinated with {len(agent_results)} specialist agents to provide you with comprehensive insights. Is there anything specific you'd like me to elaborate on?")
        
        return "\n".join(response_parts)
    
    def _chunk_response(self, response: str, chunk_size: int = 50) -> List[str]:
        """Break response into chunks for streaming"""
        words = response.split()
        chunks = []
        current_chunk = []
        
        for word in words:
            current_chunk.append(word)
            if len(current_chunk) >= chunk_size:
                chunks.append(" ".join(current_chunk))
                current_chunk = []
        
        if current_chunk:
            chunks.append(" ".join(current_chunk))
        
        return chunks
    
    async def get_conversation_state(self, conversation_id: str) -> Optional[ConversationContext]:
        """Get current conversation state"""
        return self.active_conversations.get(conversation_id)
    
    async def update_integration_mode(
        self, 
        conversation_id: str, 
        mode: IntegrationMode
    ) -> bool:
        """Update conversation integration mode"""
        conv_context = self.active_conversations.get(conversation_id)
        if conv_context:
            conv_context.integration_mode = mode
            return True
        return False
    
    async def inject_agent_capability(
        self, 
        conversation_id: str, 
        capability: str, 
        parameters: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Inject specific agent capability into conversation"""
        
        conv_context = self.active_conversations.get(conversation_id)
        if not conv_context:
            raise ValueError(f"Conversation {conversation_id} not found")
        
        # Request capability from agent bridge
        result = await self.agent_bridge.request_capability(capability, parameters)
        
        # Update conversation context
        conv_context.shared_context[f"injected_{capability}"] = result
        
        return result
    
    async def _event_processor(self):
        """Process events from the event bus"""
        while True:
            try:
                event = await self.event_bus.get()
                await self._handle_event(event)
            except Exception as e:
                logger.error(f"Error processing event: {e}")
    
    async def _handle_event(self, event: Dict[str, Any]):
        """Handle individual events"""
        event_type = event.get("type")
        
        if event_type == "agent_completed":
            # Update conversation state when agent completes
            conv_id = event.get("conversation_id")
            if conv_id in self.active_conversations:
                # Could trigger real-time updates to user
                pass
        elif event_type == "context_update":
            # Synchronize context changes
            await self.context_synchronizer.handle_update(event)
    
    async def _state_cleanup_task(self):
        """Clean up inactive conversations periodically"""
        while True:
            await asyncio.sleep(self.cleanup_interval)
            await self._cleanup_inactive_conversations()
    
    async def _cleanup_inactive_conversations(self):
        """Remove conversations that have been inactive too long"""
        cutoff_time = datetime.now().timestamp() - 3600  # 1 hour
        to_remove = []
        
        async with self.state_lock:
            for conv_id, conv_context in self.active_conversations.items():
                if conv_context.last_activity.timestamp() < cutoff_time:
                    to_remove.append(conv_id)
            
            for conv_id in to_remove:
                conv_context = self.active_conversations.pop(conv_id)
                # Remove from session registry
                self.session_registry[conv_context.user_id] = [
                    cid for cid in self.session_registry[conv_context.user_id] 
                    if cid != conv_id
                ]
                
                logger.info(f"Cleaned up inactive conversation {conv_id}")
    
    async def _cleanup_oldest_session(self, user_id: str):
        """Clean up oldest session for user when limit reached"""
        if self.session_registry[user_id]:
            oldest_conv_id = self.session_registry[user_id][0]
            if oldest_conv_id in self.active_conversations:
                conv_context = self.active_conversations.pop(oldest_conv_id)
                logger.info(f"Removed oldest conversation {oldest_conv_id} for user {user_id}")
            self.session_registry[user_id].remove(oldest_conv_id)
    
    async def _performance_monitor(self):
        """Monitor performance metrics"""
        while True:
            await asyncio.sleep(60)  # Monitor every minute
            
            # Collect metrics
            active_count = len(self.active_conversations)
            avg_response_time = 0
            
            if active_count > 0:
                total_response_time = sum(
                    sum(ctx.response_times) for ctx in self.active_conversations.values()
                    if ctx.response_times
                )
                total_responses = sum(
                    len(ctx.response_times) for ctx in self.active_conversations.values()
                )
                avg_response_time = total_response_time / total_responses if total_responses > 0 else 0
            
            logger.info(f"Performance metrics - Active conversations: {active_count}, "
                       f"Average response time: {avg_response_time:.2f}s")


class StreamMultiplexer:
    """Multiplexes multiple agent streams into a single conversation stream"""
    
    def __init__(self):
        self.active_streams = {}
        
    async def add_stream(self, stream_id: str, stream: AsyncGenerator):
        """Add a new stream to multiplex"""
        self.active_streams[stream_id] = stream
    
    async def multiplex(self) -> AsyncGenerator[StreamingResponse, None]:
        """Multiplex all active streams"""
        tasks = []
        for stream_id, stream in self.active_streams.items():
            task = asyncio.create_task(self._consume_stream(stream_id, stream))
            tasks.append(task)
        
        # Yield responses as they arrive
        while tasks:
            done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            
            for task in done:
                try:
                    response = await task
                    if response:
                        yield response
                except Exception as e:
                    logger.error(f"Stream error: {e}")
            
            tasks = list(pending)
    
    async def _consume_stream(self, stream_id: str, stream: AsyncGenerator) -> Optional[StreamingResponse]:
        """Consume individual stream"""
        try:
            async for item in stream:
                return item
        except Exception as e:
            logger.error(f"Error consuming stream {stream_id}: {e}")
        return None


class ContextSynchronizer:
    """Synchronizes context between conversation and agent systems"""
    
    def __init__(self):
        self.context_store = {}
        self.sync_lock = asyncio.Lock()
    
    async def initialize_conversation(self, conv_context: ConversationContext):
        """Initialize conversation context for synchronization"""
        async with self.sync_lock:
            self.context_store[conv_context.conversation_id] = {
                "shared_context": conv_context.shared_context.copy(),
                "last_sync": datetime.now()
            }
    
    async def sync_context(self, conversation_id: str, updates: Dict[str, Any]):
        """Synchronize context updates"""
        async with self.sync_lock:
            if conversation_id in self.context_store:
                self.context_store[conversation_id]["shared_context"].update(updates)
                self.context_store[conversation_id]["last_sync"] = datetime.now()
    
    async def handle_update(self, event: Dict[str, Any]):
        """Handle context update events"""
        conv_id = event.get("conversation_id")
        updates = event.get("updates", {})
        
        if conv_id:
            await self.sync_context(conv_id, updates)


class TTLCache:
    """Simple TTL cache for response caching"""
    
    def __init__(self, maxsize: int = 100, ttl: int = 300):
        self.maxsize = maxsize
        self.ttl = ttl
        self.cache = {}
        self.timestamps = {}
    
    def get(self, key: str) -> Optional[Any]:
        """Get cached value if not expired"""
        if key in self.cache:
            if time.time() - self.timestamps[key] < self.ttl:
                return self.cache[key]
            else:
                # Expired, remove
                del self.cache[key]
                del self.timestamps[key]
        return None
    
    def set(self, key: str, value: Any):
        """Set cached value"""
        if len(self.cache) >= self.maxsize:
            # Remove oldest item
            oldest_key = min(self.timestamps.keys(), key=self.timestamps.get)
            del self.cache[oldest_key]
            del self.timestamps[oldest_key]
        
        self.cache[key] = value
        self.timestamps[key] = time.time()


# Example usage and testing
async def demo_conversation_integration():
    """Demonstrate the conversation-agent integration"""
    
    # Initialize the integration system
    bridge = ConversationAgentBridge()
    
    # Start a conversation
    conv_context = await bridge.start_conversation(
        user_id="demo_user",
        integration_mode=IntegrationMode.COLLABORATIVE
    )
    
    print(f"Started conversation: {conv_context.conversation_id}")
    
    # Process a complex user message that requires agent coordination
    message = "I need help optimizing my Python web application. It has performance issues and I'm concerned about security vulnerabilities."
    
    print(f"\nUser: {message}")
    print("\nClaude (with agents):")
    
    # Stream the response
    async for response in bridge.process_user_message(
        conv_context.conversation_id, 
        message
    ):
        if response.chunk_type == "text" and response.content.strip():
            print(response.content, end=" ", flush=True)
        
        # Show agent coordination in collaborative mode
        if response.source == "agent" and response.metadata.get("agent_result"):
            agent_result = response.metadata["agent_result"]
            print(f"\n[{agent_result['agent_id']} completed in {agent_result['execution_time']:.1f}s]")
    
    print("\n\nConversation completed!")
    
    # Check final state
    final_state = await bridge.get_conversation_state(conv_context.conversation_id)
    print(f"Final state: {final_state.state}")
    print(f"Agents used: {list(final_state.agent_results.keys())}")


if __name__ == "__main__":
    asyncio.run(demo_conversation_integration())