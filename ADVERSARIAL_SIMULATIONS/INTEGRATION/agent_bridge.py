#!/usr/bin/env python3
"""
🌉 AGENT-SIMULATION INTEGRATION BRIDGE
Connects Claude agent system with adversarial simulation framework
"""

import asyncio
import json
import zmq
import struct
import time
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass
from enum import Enum
import threading
import queue
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('AgentBridge')


class MessageType(Enum):
    """Message types for agent communication"""
    COMMAND = 0x01
    QUERY = 0x02
    RESPONSE = 0x03
    EVENT = 0x04
    HEARTBEAT = 0x05
    SCENARIO = 0x06
    METRICS = 0x07
    ALERT = 0x08


@dataclass
class AgentMessage:
    """Message structure for agent communication"""
    agent_id: str
    message_type: MessageType
    payload: Dict[str, Any]
    timestamp: float
    correlation_id: Optional[str] = None


class AgentSimulationBridge:
    """
    Bridge between agent system and simulation framework
    """
    
    def __init__(self, agent_port: int = 4242, sim_port: int = 5555):
        self.agent_port = agent_port
        self.sim_port = sim_port
        
        # ZMQ contexts
        self.context = zmq.Context()
        
        # Agent communication (binary protocol)
        self.agent_socket = self.context.socket(zmq.ROUTER)
        self.agent_socket.bind(f"tcp://*:{agent_port}")
        
        # Simulation communication (JSON)
        self.sim_socket = self.context.socket(zmq.PUB)
        self.sim_socket.bind(f"tcp://*:{sim_port}")
        
        # Message queues
        self.agent_queue = queue.Queue()
        self.sim_queue = queue.Queue()
        
        # Agent registry
        self.registered_agents = {}
        self.agent_capabilities = {}
        
        # Simulation mappings
        self.scenario_agent_mapping = {
            'beijing_smart_city': ['Director', 'ProjectOrchestrator', 'Security', 'Infrastructure'],
            'yuan_storm': ['Director', 'Security', 'Monitor', 'Debugger'],
            'satellite_attack': ['Infrastructure', 'Security', 'Monitor', 'NPU'],
            'iot_botnet': ['Security', 'SecurityChaosAgent', 'Monitor', 'Debugger'],
            'defi_bridge': ['Security', 'Database', 'Monitor', 'Patcher']
        }
        
        self.is_running = False
        
    def register_agent(self, agent_id: str, capabilities: List[str]):
        """Register an agent with the bridge"""
        self.registered_agents[agent_id] = {
            'status': 'active',
            'last_seen': time.time(),
            'capabilities': capabilities
        }
        self.agent_capabilities[agent_id] = capabilities
        
        logger.info(f"Registered agent: {agent_id} with capabilities: {capabilities}")
        
    def map_scenario_to_agents(self, scenario_id: str) -> List[str]:
        """Map simulation scenario to required agents"""
        return self.scenario_agent_mapping.get(scenario_id, ['Director', 'Security'])
        
    async def process_agent_message(self, agent_id: bytes, message: bytes):
        """Process incoming message from agent system"""
        try:
            # Parse binary protocol (4.2M msg/sec format)
            msg_type = struct.unpack('!B', message[0:1])[0]
            payload_len = struct.unpack('!I', message[1:5])[0]
            payload = message[5:5+payload_len]
            
            # Convert to bridge message
            agent_msg = AgentMessage(
                agent_id=agent_id.decode('utf-8'),
                message_type=MessageType(msg_type),
                payload=json.loads(payload),
                timestamp=time.time()
            )
            
            # Route based on message type
            if agent_msg.message_type == MessageType.SCENARIO:
                await self.handle_scenario_request(agent_msg)
            elif agent_msg.message_type == MessageType.ALERT:
                await self.handle_security_alert(agent_msg)
            elif agent_msg.message_type == MessageType.METRICS:
                await self.forward_metrics(agent_msg)
                
        except Exception as e:
            logger.error(f"Error processing agent message: {e}")
            
    async def handle_scenario_request(self, msg: AgentMessage):
        """Handle scenario execution request from agent"""
        scenario_id = msg.payload.get('scenario_id')
        
        # Get required agents
        required_agents = self.map_scenario_to_agents(scenario_id)
        
        # Check agent availability
        available = all(
            agent in self.registered_agents 
            for agent in required_agents
        )
        
        if available:
            # Forward to simulation framework
            sim_command = {
                'command': 'execute_scenario',
                'scenario_id': scenario_id,
                'agents': required_agents,
                'requester': msg.agent_id,
                'timestamp': msg.timestamp
            }
            
            # Publish to simulation framework
            self.sim_socket.send_json(sim_command)
            
            # Notify agents
            for agent in required_agents:
                await self.notify_agent(agent, {
                    'action': 'prepare_for_scenario',
                    'scenario': scenario_id,
                    'role': self.get_agent_role(agent, scenario_id)
                })
        else:
            logger.warning(f"Not all required agents available for {scenario_id}")
            
    async def handle_security_alert(self, msg: AgentMessage):
        """Handle security alert from agent"""
        alert_type = msg.payload.get('alert_type')
        severity = msg.payload.get('severity', 'medium')
        
        # Critical alerts trigger immediate response
        if severity == 'critical':
            # Activate defensive agents
            defensive_agents = ['Security', 'Bastion', 'Monitor', 'Patcher']
            
            for agent in defensive_agents:
                if agent in self.registered_agents:
                    await self.notify_agent(agent, {
                        'action': 'respond_to_threat',
                        'threat': alert_type,
                        'severity': severity,
                        'source': msg.agent_id
                    })
            
            # Notify simulation framework
            self.sim_socket.send_json({
                'event': 'security_alert',
                'type': alert_type,
                'severity': severity,
                'responding_agents': defensive_agents
            })
            
    async def forward_metrics(self, msg: AgentMessage):
        """Forward metrics from agent to simulation"""
        metrics_data = {
            'source': msg.agent_id,
            'metrics': msg.payload,
            'timestamp': msg.timestamp
        }
        
        self.sim_socket.send_json({
            'event': 'agent_metrics',
            'data': metrics_data
        })
        
    async def notify_agent(self, agent_id: str, notification: Dict):
        """Send notification to specific agent"""
        if agent_id in self.registered_agents:
            # Construct binary message for agent
            payload = json.dumps(notification).encode()
            message = struct.pack('!BI', MessageType.COMMAND.value, len(payload)) + payload
            
            # Send to agent
            self.agent_socket.send_multipart([
                agent_id.encode(),
                message
            ])
            
    def get_agent_role(self, agent_id: str, scenario_id: str) -> str:
        """Determine agent role in scenario"""
        role_mapping = {
            'Director': 'strategic_command',
            'ProjectOrchestrator': 'tactical_coordination',
            'Security': 'threat_analysis',
            'Infrastructure': 'system_compromise',
            'Monitor': 'activity_tracking',
            'Patcher': 'vulnerability_exploitation',
            'Debugger': 'error_analysis',
            'NPU': 'ai_acceleration'
        }
        
        return role_mapping.get(agent_id, 'support')
        
    async def simulation_to_agent_translator(self, sim_event: Dict):
        """Translate simulation events to agent commands"""
        event_type = sim_event.get('type')
        
        if event_type == 'phase_complete':
            # Notify orchestrator
            await self.notify_agent('ProjectOrchestrator', {
                'event': 'simulation_phase_complete',
                'phase': sim_event.get('phase'),
                'success': sim_event.get('success'),
                'next_phase': sim_event.get('next_phase')
            })
            
        elif event_type == 'compromise_detected':
            # Alert security agents
            await self.notify_agent('Security', {
                'alert': 'compromise_detected',
                'systems': sim_event.get('compromised_systems'),
                'attack_vector': sim_event.get('vector')
            })
            
        elif event_type == 'resource_exhaustion':
            # Request infrastructure support
            await self.notify_agent('Infrastructure', {
                'request': 'allocate_resources',
                'required': sim_event.get('resources_needed'),
                'priority': 'high'
            })
            
    async def heartbeat_monitor(self):
        """Monitor agent health"""
        while self.is_running:
            current_time = time.time()
            
            for agent_id, info in self.registered_agents.items():
                last_seen = info['last_seen']
                
                if current_time - last_seen > 30:  # 30 second timeout
                    logger.warning(f"Agent {agent_id} appears offline")
                    info['status'] = 'offline'
                    
                    # Notify simulation framework
                    self.sim_socket.send_json({
                        'event': 'agent_offline',
                        'agent_id': agent_id,
                        'impact': self.assess_impact(agent_id)
                    })
                    
            await asyncio.sleep(10)
            
    def assess_impact(self, offline_agent: str) -> str:
        """Assess impact of agent going offline"""
        critical_agents = ['Director', 'ProjectOrchestrator', 'Security']
        
        if offline_agent in critical_agents:
            return 'critical'
        elif offline_agent in ['Monitor', 'Infrastructure', 'Debugger']:
            return 'high'
        else:
            return 'medium'
            
    async def start_bridge(self):
        """Start the integration bridge"""
        self.is_running = True
        logger.info(f"Bridge started - Agent port: {self.agent_port}, Sim port: {self.sim_port}")
        
        # Start background tasks
        asyncio.create_task(self.heartbeat_monitor())
        asyncio.create_task(self.agent_listener())
        asyncio.create_task(self.simulation_listener())
        
        # Main bridge loop
        while self.is_running:
            await asyncio.sleep(1)
            
    async def agent_listener(self):
        """Listen for agent messages"""
        poller = zmq.Poller()
        poller.register(self.agent_socket, zmq.POLLIN)
        
        while self.is_running:
            try:
                socks = dict(poller.poll(1000))  # 1 second timeout
                
                if self.agent_socket in socks:
                    message = self.agent_socket.recv_multipart()
                    agent_id = message[0]
                    data = message[1]
                    
                    await self.process_agent_message(agent_id, data)
                    
            except Exception as e:
                logger.error(f"Agent listener error: {e}")
                
    async def simulation_listener(self):
        """Listen for simulation framework events"""
        sim_sub = self.context.socket(zmq.SUB)
        sim_sub.connect("tcp://localhost:5556")  # Simulation event publisher
        sim_sub.setsockopt(zmq.SUBSCRIBE, b"")
        
        poller = zmq.Poller()
        poller.register(sim_sub, zmq.POLLIN)
        
        while self.is_running:
            try:
                socks = dict(poller.poll(1000))
                
                if sim_sub in socks:
                    event = sim_sub.recv_json()
                    await self.simulation_to_agent_translator(event)
                    
            except Exception as e:
                logger.error(f"Simulation listener error: {e}")
                
    async def stop_bridge(self):
        """Stop the integration bridge"""
        self.is_running = False
        
        # Close sockets
        self.agent_socket.close()
        self.sim_socket.close()
        self.context.term()
        
        logger.info("Bridge stopped")


class ScenarioCoordinator:
    """
    Coordinates agent execution with simulation scenarios
    """
    
    def __init__(self, bridge: AgentSimulationBridge):
        self.bridge = bridge
        self.active_scenarios = {}
        self.agent_assignments = {}
        
    async def launch_coordinated_attack(self, scenario_config: Dict):
        """Launch coordinated attack with agent support"""
        scenario_id = scenario_config['id']
        phases = scenario_config['phases']
        
        # Assign agents to phases
        for phase in phases:
            phase_agents = self.select_agents_for_phase(phase)
            
            for agent in phase_agents:
                await self.bridge.notify_agent(agent, {
                    'command': 'execute_phase',
                    'scenario': scenario_id,
                    'phase': phase['name'],
                    'objectives': phase['objectives'],
                    'duration': phase['duration']
                })
                
        self.active_scenarios[scenario_id] = {
            'status': 'running',
            'current_phase': 0,
            'agents': phase_agents
        }
        
    def select_agents_for_phase(self, phase: Dict) -> List[str]:
        """Select optimal agents for phase execution"""
        phase_type = phase.get('type')
        
        agent_selection = {
            'reconnaissance': ['RESEARCHER', 'Monitor', 'Security'],
            'initial_access': ['Security', 'Patcher', 'SecurityChaosAgent'],
            'persistence': ['Infrastructure', 'Patcher', 'Constructor'],
            'lateral_movement': ['Security', 'Infrastructure', 'Monitor'],
            'exfiltration': ['Security', 'Database', 'Monitor'],
            'impact': ['SecurityChaosAgent', 'Infrastructure', 'Monitor']
        }
        
        return agent_selection.get(phase_type, ['Director', 'Security'])
        
    async def coordinate_response(self, threat_event: Dict):
        """Coordinate defensive response across agents"""
        threat_type = threat_event.get('type')
        severity = threat_event.get('severity')
        
        # Determine response strategy
        if severity == 'critical':
            response_agents = [
                'Director',  # Strategic decisions
                'Security',  # Threat analysis
                'Bastion',  # Defensive measures
                'Patcher',  # Quick fixes
                'Monitor'   # Activity tracking
            ]
        else:
            response_agents = ['Security', 'Monitor', 'Debugger']
            
        # Deploy agents
        for agent in response_agents:
            task = self.get_agent_task(agent, threat_type)
            await self.bridge.notify_agent(agent, task)
            
    def get_agent_task(self, agent: str, threat_type: str) -> Dict:
        """Get specific task for agent based on threat"""
        task_mapping = {
            'Director': {
                'action': 'strategic_response',
                'priority': 'immediate',
                'authority': 'full'
            },
            'Security': {
                'action': 'threat_analysis',
                'focus': threat_type,
                'depth': 'comprehensive'
            },
            'Bastion': {
                'action': 'activate_defenses',
                'mode': 'maximum',
                'rules': 'adaptive'
            },
            'Patcher': {
                'action': 'emergency_patch',
                'target': 'vulnerable_systems',
                'speed': 'critical'
            },
            'Monitor': {
                'action': 'enhanced_monitoring',
                'scope': 'full_network',
                'alerting': 'real_time'
            }
        }
        
        return task_mapping.get(agent, {'action': 'support'})


# Performance monitoring
class BridgeMonitor:
    """Monitor bridge performance"""
    
    def __init__(self):
        self.message_count = 0
        self.error_count = 0
        self.latency_samples = []
        self.start_time = time.time()
        
    def record_message(self, latency: float):
        """Record message metrics"""
        self.message_count += 1
        self.latency_samples.append(latency)
        
        # Keep only last 1000 samples
        if len(self.latency_samples) > 1000:
            self.latency_samples.pop(0)
            
    def get_metrics(self) -> Dict:
        """Get current metrics"""
        uptime = time.time() - self.start_time
        
        if self.latency_samples:
            avg_latency = sum(self.latency_samples) / len(self.latency_samples)
            p99_latency = sorted(self.latency_samples)[int(len(self.latency_samples) * 0.99)]
        else:
            avg_latency = 0
            p99_latency = 0
            
        return {
            'uptime_seconds': uptime,
            'total_messages': self.message_count,
            'messages_per_second': self.message_count / uptime if uptime > 0 else 0,
            'error_count': self.error_count,
            'avg_latency_ms': avg_latency * 1000,
            'p99_latency_ms': p99_latency * 1000
        }


if __name__ == "__main__":
    async def main():
        # Initialize bridge
        bridge = AgentSimulationBridge()
        
        # Register some agents
        bridge.register_agent('Director', ['command', 'strategy', 'coordination'])
        bridge.register_agent('Security', ['threat_analysis', 'defense', 'forensics'])
        bridge.register_agent('ProjectOrchestrator', ['execution', 'coordination', 'monitoring'])
        bridge.register_agent('Infrastructure', ['deployment', 'compromise', 'persistence'])
        
        # Initialize coordinator
        coordinator = ScenarioCoordinator(bridge)
        
        # Start bridge
        await bridge.start_bridge()
        
    # Run bridge
    asyncio.run(main())