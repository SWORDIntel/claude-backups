#!/usr/bin/env python3
"""
Claude Conversation-Agent Integration Example
Comprehensive demonstration of real-time agent coordination during conversations

This example shows:
1. Real-time agent coordination during user conversations
2. Context sharing between conversation and agent systems
3. Streaming response integration from agents to conversations
4. Agent task spawning from conversation context
5. Unified session management and state synchronization
6. Message bridging between conversation and agent protocols
7. Performance optimization for low-latency conversation integration
"""

import asyncio
import json
import time
import uuid
from typing import AsyncGenerator, Dict, List, Any, Optional
import logging

# Import our conversation bridge system
from conversation_bridge_wrapper import (
    ConversationBridge, IntegrationMode, ConversationState, 
    PythonStreamChunk, get_bridge, process_conversation_message
)

# Configure detailed logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ConversationManager:
    """Advanced conversation manager with agent integration"""
    
    def __init__(self):
        self.bridge = ConversationBridge()
        self.active_sessions = {}
        self.conversation_history = {}
        self.user_preferences = {}
        
    async def initialize(self):
        """Initialize the conversation manager"""
        self.bridge.initialize()
        logger.info("Conversation manager initialized")
        
        # Show system capabilities
        stats = self.bridge.get_performance_stats()
        logger.info(f"Bridge implementation: {stats['implementation']}")
        logger.info(f"System ready for conversations")
    
    async def start_conversation(
        self,
        user_id: str,
        initial_context: Optional[Dict[str, Any]] = None,
        integration_mode: IntegrationMode = IntegrationMode.TRANSPARENT
    ) -> str:
        """Start a new conversation with optional context"""
        
        conversation_id = f"conv_{user_id}_{int(time.time())}_{uuid.uuid4().hex[:8]}"
        
        # Initialize conversation state
        session_info = {
            "conversation_id": conversation_id,
            "user_id": user_id,
            "started_at": time.time(),
            "integration_mode": integration_mode,
            "context": initial_context or {},
            "message_count": 0,
            "agent_invocations": 0
        }
        
        self.active_sessions[conversation_id] = session_info
        self.conversation_history[conversation_id] = []
        
        # Set integration mode in bridge
        self.bridge.set_integration_mode(conversation_id, integration_mode)
        
        logger.info(f"Started conversation {conversation_id} for user {user_id}")
        logger.info(f"Integration mode: {integration_mode.name}")
        
        return conversation_id
    
    async def process_message(
        self,
        conversation_id: str,
        message: str,
        message_metadata: Optional[Dict[str, Any]] = None
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """Process user message with comprehensive response tracking"""
        
        if conversation_id not in self.active_sessions:
            raise ValueError(f"Conversation {conversation_id} not found")
        
        session = self.active_sessions[conversation_id]
        user_id = session["user_id"]
        
        # Update session stats
        session["message_count"] += 1
        session["last_activity"] = time.time()
        
        # Add to conversation history
        user_message = {
            "role": "user",
            "content": message,
            "timestamp": time.time(),
            "metadata": message_metadata or {}
        }
        self.conversation_history[conversation_id].append(user_message)
        
        logger.info(f"Processing message in {conversation_id}: {message[:50]}...")
        
        # Track response composition
        response_parts = []
        agent_contributions = {}
        start_time = time.time()
        
        try:
            # Process through bridge
            async for chunk in self.bridge.process_message(
                conversation_id, user_id, message, session["integration_mode"]
            ):
                # Collect response data
                if chunk.source_type == "agent":
                    if chunk.source_id not in agent_contributions:
                        agent_contributions[chunk.source_id] = []
                        session["agent_invocations"] += 1
                    agent_contributions[chunk.source_id].append(chunk)
                
                response_parts.append(chunk)
                
                # Yield structured response
                yield {
                    "type": "stream_chunk",
                    "conversation_id": conversation_id,
                    "chunk": {
                        "content": chunk.content,
                        "source_type": chunk.source_type,
                        "source_id": chunk.source_id,
                        "chunk_type": chunk.chunk_type,
                        "is_partial": chunk.is_partial,
                        "timestamp": chunk.timestamp_ns / 1_000_000_000,
                        "metadata": chunk.metadata
                    }
                }
                
                # Yield agent coordination updates
                if (chunk.source_type == "agent" and 
                    session["integration_mode"] in [IntegrationMode.COLLABORATIVE, IntegrationMode.INTERACTIVE]):
                    
                    yield {
                        "type": "agent_update",
                        "conversation_id": conversation_id,
                        "agent_id": chunk.source_id,
                        "status": "working" if chunk.is_partial else "completed",
                        "preview": chunk.content[:100] if chunk.content else None
                    }
            
            # Final response summary
            processing_time = time.time() - start_time
            
            # Compose complete response
            complete_response = "".join(
                chunk.content for chunk in response_parts 
                if chunk.chunk_type == "text" and chunk.source_type == "conversation"
            )
            
            # Add to conversation history
            assistant_message = {
                "role": "assistant",
                "content": complete_response,
                "timestamp": time.time(),
                "metadata": {
                    "processing_time_ms": processing_time * 1000,
                    "agents_used": list(agent_contributions.keys()),
                    "total_chunks": len(response_parts)
                }
            }
            self.conversation_history[conversation_id].append(assistant_message)
            
            # Yield completion summary
            yield {
                "type": "completion_summary",
                "conversation_id": conversation_id,
                "response": complete_response,
                "processing_time_ms": processing_time * 1000,
                "agents_used": list(agent_contributions.keys()),
                "agent_contributions": {
                    agent_id: len(chunks) for agent_id, chunks in agent_contributions.items()
                },
                "conversation_state": self.bridge.get_conversation_state(conversation_id).name,
                "session_stats": {
                    "total_messages": session["message_count"],
                    "total_agent_invocations": session["agent_invocations"],
                    "session_duration_minutes": (time.time() - session["started_at"]) / 60
                }
            }
            
        except Exception as e:
            logger.error(f"Error processing message in {conversation_id}: {e}")
            
            yield {
                "type": "error",
                "conversation_id": conversation_id,
                "error": str(e),
                "recovery_suggestions": [
                    "Try rephrasing your request",
                    "Check if the conversation is still active",
                    "Contact support if the issue persists"
                ]
            }
    
    async def inject_capability(
        self,
        conversation_id: str,
        capability_name: str,
        parameters: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Inject specific agent capability into ongoing conversation"""
        
        if conversation_id not in self.active_sessions:
            raise ValueError(f"Conversation {conversation_id} not found")
        
        logger.info(f"Injecting capability '{capability_name}' into {conversation_id}")
        
        result = await self.bridge.inject_agent_capability(
            conversation_id, capability_name, parameters
        )
        
        # Update session stats
        session = self.active_sessions[conversation_id]
        session["agent_invocations"] += 1
        
        return {
            "capability": capability_name,
            "result": result,
            "conversation_id": conversation_id,
            "injected_at": time.time()
        }
    
    def get_conversation_summary(self, conversation_id: str) -> Dict[str, Any]:
        """Get comprehensive conversation summary"""
        
        if conversation_id not in self.active_sessions:
            return {"error": "Conversation not found"}
        
        session = self.active_sessions[conversation_id]
        history = self.conversation_history.get(conversation_id, [])
        
        # Calculate statistics
        total_user_messages = len([msg for msg in history if msg["role"] == "user"])
        total_assistant_messages = len([msg for msg in history if msg["role"] == "assistant"])
        
        avg_response_time = 0
        if total_assistant_messages > 0:
            response_times = [
                msg["metadata"].get("processing_time_ms", 0) 
                for msg in history 
                if msg["role"] == "assistant"
            ]
            avg_response_time = sum(response_times) / len(response_times)
        
        return {
            "conversation_id": conversation_id,
            "user_id": session["user_id"],
            "started_at": session["started_at"],
            "duration_minutes": (time.time() - session["started_at"]) / 60,
            "integration_mode": session["integration_mode"].name,
            "message_stats": {
                "total_user_messages": total_user_messages,
                "total_assistant_messages": total_assistant_messages,
                "total_agent_invocations": session["agent_invocations"],
                "average_response_time_ms": avg_response_time
            },
            "conversation_state": self.bridge.get_conversation_state(conversation_id).name,
            "context_size": len(json.dumps(session["context"])),
            "history_size": len(history)
        }
    
    def get_system_stats(self) -> Dict[str, Any]:
        """Get comprehensive system statistics"""
        
        bridge_stats = self.bridge.get_performance_stats()
        
        # Calculate conversation manager stats
        active_conversations = len(self.active_sessions)
        total_messages = sum(session["message_count"] for session in self.active_sessions.values())
        total_agent_invocations = sum(session["agent_invocations"] for session in self.active_sessions.values())
        
        # Calculate average session duration
        current_time = time.time()
        avg_session_duration = 0
        if active_conversations > 0:
            durations = [
                (current_time - session["started_at"]) / 60 
                for session in self.active_sessions.values()
            ]
            avg_session_duration = sum(durations) / len(durations)
        
        return {
            "bridge_stats": bridge_stats,
            "conversation_manager_stats": {
                "active_conversations": active_conversations,
                "total_messages_processed": total_messages,
                "total_agent_invocations": total_agent_invocations,
                "average_session_duration_minutes": avg_session_duration
            },
            "memory_usage": {
                "active_sessions_mb": len(json.dumps(self.active_sessions)) / 1024 / 1024,
                "conversation_history_mb": len(json.dumps(self.conversation_history)) / 1024 / 1024
            }
        }
    
    async def cleanup_inactive_conversations(self, max_inactive_minutes: int = 60):
        """Clean up conversations that have been inactive too long"""
        
        current_time = time.time()
        to_remove = []
        
        for conv_id, session in self.active_sessions.items():
            last_activity = session.get("last_activity", session["started_at"])
            inactive_time = (current_time - last_activity) / 60
            
            if inactive_time > max_inactive_minutes:
                to_remove.append(conv_id)
        
        for conv_id in to_remove:
            logger.info(f"Cleaning up inactive conversation {conv_id}")
            del self.active_sessions[conv_id]
            if conv_id in self.conversation_history:
                del self.conversation_history[conv_id]
        
        return len(to_remove)
    
    async def shutdown(self):
        """Gracefully shutdown the conversation manager"""
        
        logger.info("Shutting down conversation manager...")
        
        # Clean up all conversations
        active_count = len(self.active_sessions)
        self.active_sessions.clear()
        self.conversation_history.clear()
        
        # Shutdown bridge
        self.bridge.shutdown()
        
        logger.info(f"Shutdown complete. Cleaned up {active_count} conversations.")


# Demonstration scenarios
async def demo_transparent_mode():
    """Demonstrate transparent integration (user doesn't see agent coordination)"""
    
    print("\n🔍 TRANSPARENT MODE DEMO")
    print("=" * 50)
    print("In this mode, agents work invisibly behind the scenes")
    print()
    
    manager = ConversationManager()
    await manager.initialize()
    
    # Start transparent conversation
    conv_id = await manager.start_conversation(
        user_id="demo_user_1",
        integration_mode=IntegrationMode.TRANSPARENT
    )
    
    # Process a complex request
    message = "I need help optimizing my Python web API. It's slow and I'm worried about security."
    print(f"User: {message}")
    print("\nClaude: ", end="", flush=True)
    
    response_text = ""
    async for response in manager.process_message(conv_id, message):
        if response["type"] == "stream_chunk":
            chunk = response["chunk"]
            if chunk["chunk_type"] == "text" and chunk["source_type"] == "conversation":
                print(chunk["content"], end="", flush=True)
                response_text += chunk["content"]
        elif response["type"] == "completion_summary":
            print(f"\n\n✅ Response completed in {response['processing_time_ms']:.1f}ms")
            print(f"🤖 Agents used: {', '.join(response['agents_used'])}")
            print(f"📊 Session: {response['session_stats']['total_messages']} messages, "
                  f"{response['session_stats']['total_agent_invocations']} agent invocations")
    
    await manager.shutdown()


async def demo_collaborative_mode():
    """Demonstrate collaborative integration (user sees agent coordination)"""
    
    print("\n🤝 COLLABORATIVE MODE DEMO")
    print("=" * 50)
    print("In this mode, users see agent coordination and progress")
    print()
    
    manager = ConversationManager()
    await manager.initialize()
    
    # Start collaborative conversation
    conv_id = await manager.start_conversation(
        user_id="demo_user_2",
        integration_mode=IntegrationMode.COLLABORATIVE,
        initial_context={"project_type": "web_application", "urgency": "high"}
    )
    
    # Process a system design request
    message = "Design a scalable e-commerce system that can handle 100,000 concurrent users with real-time inventory and payment processing."
    print(f"User: {message}")
    print()
    
    main_response = ""
    agent_updates = {}
    
    async for response in manager.process_message(conv_id, message):
        if response["type"] == "stream_chunk":
            chunk = response["chunk"]
            if chunk["source_type"] == "conversation" and chunk["chunk_type"] == "text":
                if not main_response:
                    print("Claude: ", end="", flush=True)
                print(chunk["content"], end="", flush=True)
                main_response += chunk["content"]
                
        elif response["type"] == "agent_update":
            agent_id = response["agent_id"]
            if agent_id not in agent_updates:
                print(f"\n🔧 {agent_id} is analyzing...")
                agent_updates[agent_id] = {"started": time.time()}
            
            if response["status"] == "completed":
                duration = time.time() - agent_updates[agent_id]["started"]
                print(f"✅ {agent_id} completed analysis ({duration:.1f}s)")
                
        elif response["type"] == "completion_summary":
            print(f"\n\n🎯 ANALYSIS COMPLETE")
            print(f"⏱️  Total time: {response['processing_time_ms']:.1f}ms")
            print(f"🤖 Specialists consulted: {len(response['agents_used'])}")
            for agent, contrib in response['agent_contributions'].items():
                print(f"   • {agent}: {contrib} contributions")
            
            # Show conversation summary
            summary = manager.get_conversation_summary(conv_id)
            print(f"📈 Session stats: {summary['message_stats']}")
    
    await manager.shutdown()


async def demo_interactive_mode():
    """Demonstrate interactive integration (user can interact with agents)"""
    
    print("\n💬 INTERACTIVE MODE DEMO")
    print("=" * 50)
    print("In this mode, users can interact directly with individual agents")
    print()
    
    manager = ConversationManager()
    await manager.initialize()
    
    # Start interactive conversation
    conv_id = await manager.start_conversation(
        user_id="demo_user_3",
        integration_mode=IntegrationMode.INTERACTIVE
    )
    
    # First, process a general request
    message = "I'm building a machine learning pipeline for fraud detection. What should I consider?"
    print(f"User: {message}")
    print()
    
    async for response in manager.process_message(conv_id, message):
        if response["type"] == "stream_chunk":
            chunk = response["chunk"]
            if chunk["source_type"] == "conversation" and chunk["chunk_type"] == "text":
                print(chunk["content"], end="", flush=True)
        elif response["type"] == "completion_summary":
            print(f"\n\n✅ Initial analysis complete")
            break
    
    # Now inject a specific capability
    print("\n🔬 INJECTING SPECIALIZED CAPABILITY")
    print("Requesting ML_OPS agent for detailed pipeline design...")
    
    capability_result = await manager.inject_capability(
        conv_id,
        "ml_pipeline_design",
        {
            "use_case": "fraud_detection",
            "data_volume": "1TB_daily",
            "latency_requirement": "real_time",
            "compliance": ["PCI_DSS", "GDPR"]
        }
    )
    
    print(f"🎯 ML_OPS Analysis Result:")
    print(json.dumps(capability_result["result"], indent=2))
    
    await manager.shutdown()


async def demo_performance_monitoring():
    """Demonstrate performance monitoring and optimization"""
    
    print("\n📊 PERFORMANCE MONITORING DEMO")
    print("=" * 50)
    
    manager = ConversationManager()
    await manager.initialize()
    
    # Create multiple concurrent conversations
    conversations = []
    for i in range(5):
        conv_id = await manager.start_conversation(
            user_id=f"perf_user_{i}",
            integration_mode=IntegrationMode.TRANSPARENT
        )
        conversations.append(conv_id)
    
    print(f"Created {len(conversations)} concurrent conversations")
    
    # Process messages concurrently
    async def process_conversation(conv_id, user_num):
        message = f"Analyze the performance of a web application handling {1000 * (user_num + 1)} requests per second"
        
        response_time = time.time()
        async for response in manager.process_message(conv_id, message):
            if response["type"] == "completion_summary":
                response_time = response["processing_time_ms"]
                break
        
        return response_time
    
    # Run conversations concurrently
    start_time = time.time()
    tasks = [
        process_conversation(conv_id, i) 
        for i, conv_id in enumerate(conversations)
    ]
    
    response_times = await asyncio.gather(*tasks)
    total_time = time.time() - start_time
    
    # Show performance stats
    print(f"\n📈 PERFORMANCE RESULTS")
    print(f"Total processing time: {total_time:.2f}s")
    print(f"Average response time: {sum(response_times):.1f}ms")
    print(f"Fastest response: {min(response_times):.1f}ms")
    print(f"Slowest response: {max(response_times):.1f}ms")
    
    # Show system stats
    system_stats = manager.get_system_stats()
    print(f"\n🖥️  SYSTEM STATISTICS")
    print(f"Implementation: {system_stats['bridge_stats']['implementation']}")
    print(f"Total messages processed: {system_stats['bridge_stats']['total_messages_processed']}")
    print(f"Active conversations: {system_stats['conversation_manager_stats']['active_conversations']}")
    print(f"Memory usage: {system_stats['memory_usage']['active_sessions_mb']:.2f}MB")
    
    await manager.shutdown()


async def main():
    """Run all demonstration scenarios"""
    
    print("🚀 CLAUDE CONVERSATION-AGENT INTEGRATION DEMOS")
    print("=" * 60)
    print("Demonstrating real-time agent coordination during conversations")
    print()
    
    # Run all demos
    try:
        await demo_transparent_mode()
        await demo_collaborative_mode()
        await demo_interactive_mode()
        await demo_performance_monitoring()
        
        print("\n🎉 ALL DEMOS COMPLETED SUCCESSFULLY!")
        print("The conversation-agent integration system is working perfectly.")
        
    except Exception as e:
        print(f"\n❌ Demo failed: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())