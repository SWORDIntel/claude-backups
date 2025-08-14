#!/usr/bin/env python3
"""
📊 REAL-TIME ATTACK VISUALIZATION SYSTEM
Interactive dashboard for live simulation monitoring
"""

import asyncio
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
import numpy as np
import networkx as nx
from dataclasses import dataclass
import websockets
import threading
from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import plotly.graph_objs as go
import plotly.utils
from collections import deque, defaultdict
import psutil
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('Visualization')

# Flask application setup
app = Flask(__name__)
app.config['SECRET_KEY'] = 'simulation-viz-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')


@dataclass
class NetworkNode:
    """Represents a node in the attack visualization"""
    id: str
    type: str  # 'certificate', 'system', 'network', 'actor'
    status: str  # 'normal', 'scanning', 'compromised', 'defended'
    x: float
    y: float
    z: float = 0.0
    metadata: Dict = None
    connections: List[str] = None


@dataclass 
class AttackFlow:
    """Represents attack flow between nodes"""
    source: str
    target: str
    attack_type: str
    timestamp: datetime
    success: bool
    data_size: int = 0
    duration: float = 0.0


class SimulationVisualizer:
    """
    Real-time visualization engine for attack simulations
    """
    
    def __init__(self):
        self.network_graph = nx.Graph()
        self.nodes: Dict[str, NetworkNode] = {}
        self.attack_flows: deque = deque(maxlen=1000)
        self.metrics_buffer = deque(maxlen=300)  # 5 minutes at 1 update/sec
        self.active_simulations = {}
        self.is_running = False
        
        # Performance metrics
        self.fps_counter = 0
        self.last_fps_time = time.time()
        self.current_fps = 0
        
        # Attack heatmap data
        self.heatmap_data = np.zeros((50, 50))
        
        # Initialize network topology
        self._initialize_network()
    
    def _initialize_network(self):
        """Initialize the network topology for visualization"""
        # Create hierarchical network structure
        layers = {
            'internet': {'y': 0, 'nodes': 5},
            'dmz': {'y': 1, 'nodes': 8},
            'internal': {'y': 2, 'nodes': 15},
            'critical': {'y': 3, 'nodes': 10},
            'database': {'y': 4, 'nodes': 5}
        }
        
        node_id = 0
        for layer_name, layer_config in layers.items():
            for i in range(layer_config['nodes']):
                node = NetworkNode(
                    id=f"{layer_name}_{i}",
                    type='system',
                    status='normal',
                    x=i * (10 / layer_config['nodes']),
                    y=layer_config['y'] * 2,
                    metadata={'layer': layer_name}
                )
                self.nodes[node.id] = node
                self.network_graph.add_node(node.id)
                node_id += 1
        
        # Add certificate authority nodes
        ca_positions = [(2, -1), (5, -1), (8, -1)]
        for i, (x, y) in enumerate(ca_positions):
            ca_node = NetworkNode(
                id=f"ca_{i}",
                type='certificate',
                status='normal',
                x=x,
                y=y,
                metadata={'ca_type': ['root', 'intermediate', 'service'][i]}
            )
            self.nodes[ca_node.id] = ca_node
            self.network_graph.add_node(ca_node.id)
        
        # Create network connections
        self._create_network_edges()
    
    def _create_network_edges(self):
        """Create edges between network nodes"""
        # Connect layers
        for node_id, node in self.nodes.items():
            if 'internet' in node_id:
                # Connect to DMZ
                for dmz_id, dmz_node in self.nodes.items():
                    if 'dmz' in dmz_id and np.random.random() < 0.3:
                        self.network_graph.add_edge(node_id, dmz_id)
            
            elif 'dmz' in node_id:
                # Connect to internal
                for int_id, int_node in self.nodes.items():
                    if 'internal' in int_id and np.random.random() < 0.2:
                        self.network_graph.add_edge(node_id, int_id)
            
            elif 'internal' in node_id:
                # Connect to critical
                for crit_id, crit_node in self.nodes.items():
                    if 'critical' in crit_id and np.random.random() < 0.15:
                        self.network_graph.add_edge(node_id, crit_id)
            
            elif 'critical' in node_id:
                # Connect to database
                for db_id, db_node in self.nodes.items():
                    if 'database' in db_id and np.random.random() < 0.3:
                        self.network_graph.add_edge(node_id, db_id)
        
        # Connect CAs to various layers
        for ca_id in [n for n in self.nodes if 'ca_' in n]:
            for node_id in self.nodes:
                if 'ca_' not in node_id and np.random.random() < 0.1:
                    self.network_graph.add_edge(ca_id, node_id)
    
    def update_node_status(self, node_id: str, status: str):
        """Update node status in real-time"""
        if node_id in self.nodes:
            self.nodes[node_id].status = status
            
            # Emit update to connected clients
            socketio.emit('node_update', {
                'node_id': node_id,
                'status': status,
                'timestamp': datetime.now().isoformat()
            })
            
            # Update heatmap
            self._update_heatmap(node_id, status)
    
    def add_attack_flow(self, source: str, target: str, 
                       attack_type: str, success: bool):
        """Add new attack flow to visualization"""
        flow = AttackFlow(
            source=source,
            target=target,
            attack_type=attack_type,
            timestamp=datetime.now(),
            success=success
        )
        
        self.attack_flows.append(flow)
        
        # Emit attack flow to clients
        socketio.emit('attack_flow', {
            'source': source,
            'target': target,
            'attack_type': attack_type,
            'success': success,
            'timestamp': flow.timestamp.isoformat()
        })
    
    def _update_heatmap(self, node_id: str, status: str):
        """Update attack heatmap based on node activity"""
        if node_id in self.nodes:
            node = self.nodes[node_id]
            x_idx = int(node.x * 5) % 50
            y_idx = int(node.y * 10) % 50
            
            # Increase heat based on status
            heat_values = {
                'scanning': 0.3,
                'compromised': 1.0,
                'defended': -0.5,
                'normal': -0.1
            }
            
            heat_change = heat_values.get(status, 0)
            self.heatmap_data[y_idx, x_idx] = min(1.0, max(0, 
                self.heatmap_data[y_idx, x_idx] + heat_change))
            
            # Apply decay to surrounding cells
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    if dx == 0 and dy == 0:
                        continue
                    new_x = (x_idx + dx) % 50
                    new_y = (y_idx + dy) % 50
                    decay = heat_change * 0.3 / (abs(dx) + abs(dy))
                    self.heatmap_data[new_y, new_x] = min(1.0, max(0,
                        self.heatmap_data[new_y, new_x] + decay))
    
    def generate_network_plot(self) -> Dict:
        """Generate Plotly network graph"""
        edge_trace = []
        for edge in self.network_graph.edges():
            x0, y0 = self.nodes[edge[0]].x, self.nodes[edge[0]].y
            x1, y1 = self.nodes[edge[1]].x, self.nodes[edge[1]].y
            
            edge_trace.append(go.Scatter(
                x=[x0, x1, None],
                y=[y0, y1, None],
                mode='lines',
                line=dict(width=0.5, color='#888'),
                hoverinfo='none'
            ))
        
        # Create node traces by status
        node_traces = {}
        status_colors = {
            'normal': '#00FF00',
            'scanning': '#FFFF00',
            'compromised': '#FF0000',
            'defended': '#0000FF'
        }
        
        for status, color in status_colors.items():
            nodes_with_status = [n for n in self.nodes.values() if n.status == status]
            if nodes_with_status:
                node_traces[status] = go.Scatter(
                    x=[n.x for n in nodes_with_status],
                    y=[n.y for n in nodes_with_status],
                    mode='markers',
                    name=status.capitalize(),
                    marker=dict(
                        size=10,
                        color=color,
                        line=dict(width=2, color='white')
                    ),
                    text=[n.id for n in nodes_with_status],
                    hovertemplate='%{text}<extra></extra>'
                )
        
        # Combine all traces
        data = edge_trace + list(node_traces.values())
        
        layout = go.Layout(
            title='Network Attack Visualization',
            showlegend=True,
            hovermode='closest',
            margin=dict(b=20, l=5, r=5, t=40),
            xaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            yaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            height=600
        )
        
        fig = go.Figure(data=data, layout=layout)
        return json.loads(plotly.utils.PlotlyJSONEncoder().encode(fig))
    
    def generate_metrics_plot(self) -> Dict:
        """Generate real-time metrics plot"""
        if not self.metrics_buffer:
            return {}
        
        timestamps = [m['timestamp'] for m in self.metrics_buffer]
        compromised = [m.get('compromised_count', 0) for m in self.metrics_buffer]
        detected = [m.get('detected_count', 0) for m in self.metrics_buffer]
        
        trace1 = go.Scatter(
            x=timestamps,
            y=compromised,
            mode='lines',
            name='Compromised Systems',
            line=dict(color='red', width=2)
        )
        
        trace2 = go.Scatter(
            x=timestamps,
            y=detected,
            mode='lines',
            name='Detected Activities',
            line=dict(color='blue', width=2)
        )
        
        layout = go.Layout(
            title='Real-Time Attack Metrics',
            xaxis=dict(title='Time'),
            yaxis=dict(title='Count'),
            height=400
        )
        
        fig = go.Figure(data=[trace1, trace2], layout=layout)
        return json.loads(plotly.utils.PlotlyJSONEncoder().encode(fig))
    
    def generate_heatmap_plot(self) -> Dict:
        """Generate attack heatmap"""
        trace = go.Heatmap(
            z=self.heatmap_data,
            colorscale='Hot',
            showscale=True,
            colorbar=dict(title='Attack Intensity')
        )
        
        layout = go.Layout(
            title='Attack Intensity Heatmap',
            xaxis=dict(title='Network X', showticklabels=False),
            yaxis=dict(title='Network Y', showticklabels=False),
            height=400
        )
        
        fig = go.Figure(data=[trace], layout=layout)
        return json.loads(plotly.utils.PlotlyJSONEncoder().encode(fig))
    
    def generate_attack_timeline(self) -> Dict:
        """Generate attack timeline visualization"""
        if not self.attack_flows:
            return {}
        
        # Group attacks by time windows
        time_windows = defaultdict(list)
        for flow in self.attack_flows:
            window = flow.timestamp.replace(second=0, microsecond=0)
            time_windows[window].append(flow)
        
        times = sorted(time_windows.keys())
        successful = [
            sum(1 for f in time_windows[t] if f.success)
            for t in times
        ]
        failed = [
            sum(1 for f in time_windows[t] if not f.success)
            for t in times
        ]
        
        trace1 = go.Bar(
            x=times,
            y=successful,
            name='Successful',
            marker=dict(color='green')
        )
        
        trace2 = go.Bar(
            x=times,
            y=failed,
            name='Failed',
            marker=dict(color='red')
        )
        
        layout = go.Layout(
            title='Attack Timeline',
            xaxis=dict(title='Time'),
            yaxis=dict(title='Attack Count'),
            barmode='stack',
            height=300
        )
        
        fig = go.Figure(data=[trace1, trace2], layout=layout)
        return json.loads(plotly.utils.PlotlyJSONEncoder().encode(fig))
    
    async def start_visualization_server(self):
        """Start the visualization server"""
        self.is_running = True
        
        # Start background update task
        asyncio.create_task(self._update_loop())
        
        # Start Flask-SocketIO server in thread
        threading.Thread(
            target=lambda: socketio.run(app, host='0.0.0.0', port=5000),
            daemon=True
        ).start()
        
        logger.info("Visualization server started on http://localhost:5000")
    
    async def _update_loop(self):
        """Background update loop"""
        while self.is_running:
            # Update FPS
            self.fps_counter += 1
            current_time = time.time()
            if current_time - self.last_fps_time > 1.0:
                self.current_fps = self.fps_counter
                self.fps_counter = 0
                self.last_fps_time = current_time
            
            # Decay heatmap
            self.heatmap_data *= 0.99
            
            # Collect system metrics
            metrics = {
                'timestamp': datetime.now().isoformat(),
                'cpu_usage': psutil.cpu_percent(),
                'memory_usage': psutil.virtual_memory().percent,
                'network_nodes': len(self.nodes),
                'active_flows': len([f for f in self.attack_flows 
                                   if (datetime.now() - f.timestamp).seconds < 60]),
                'fps': self.current_fps
            }
            
            self.metrics_buffer.append(metrics)
            
            # Emit metrics update
            socketio.emit('metrics_update', metrics)
            
            await asyncio.sleep(1.0)


# Flask routes
@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('dashboard.html')


@app.route('/api/network')
def get_network():
    """Get network graph data"""
    return jsonify(visualizer.generate_network_plot())


@app.route('/api/metrics')
def get_metrics():
    """Get metrics data"""
    return jsonify(visualizer.generate_metrics_plot())


@app.route('/api/heatmap')
def get_heatmap():
    """Get heatmap data"""
    return jsonify(visualizer.generate_heatmap_plot())


@app.route('/api/timeline')
def get_timeline():
    """Get attack timeline"""
    return jsonify(visualizer.generate_attack_timeline())


@app.route('/api/status')
def get_status():
    """Get system status"""
    return jsonify({
        'running': visualizer.is_running,
        'nodes': len(visualizer.nodes),
        'edges': visualizer.network_graph.number_of_edges(),
        'active_simulations': len(visualizer.active_simulations),
        'fps': visualizer.current_fps
    })


# SocketIO events
@socketio.on('connect')
def handle_connect():
    """Handle client connection"""
    logger.info(f"Client connected: {request.sid}")
    emit('connected', {'data': 'Connected to visualization server'})


@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection"""
    logger.info(f"Client disconnected: {request.sid}")


@socketio.on('simulate_attack')
def handle_simulate_attack(data):
    """Handle attack simulation request"""
    source = data.get('source', 'internet_0')
    target = data.get('target', 'critical_0')
    
    # Simulate attack
    visualizer.update_node_status(source, 'scanning')
    time.sleep(0.5)
    
    success = np.random.random() < 0.7
    visualizer.add_attack_flow(source, target, 'certificate_exploit', success)
    
    if success:
        visualizer.update_node_status(target, 'compromised')
    else:
        visualizer.update_node_status(target, 'defended')
    
    emit('attack_complete', {
        'source': source,
        'target': target,
        'success': success
    })


# Initialize visualizer
visualizer = SimulationVisualizer()


# Dashboard HTML template
dashboard_html = """
<!DOCTYPE html>
<html>
<head>
    <title>Attack Simulation Dashboard</title>
    <script src="https://cdn.socket.io/4.5.0/socket.io.min.js"></script>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background: #1a1a1a;
            color: #fff;
        }
        .dashboard {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 20px;
        }
        .panel {
            background: #2a2a2a;
            border-radius: 8px;
            padding: 15px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 10px;
            margin-bottom: 20px;
        }
        .metric {
            background: #3a3a3a;
            padding: 10px;
            border-radius: 4px;
            text-align: center;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
            color: #00ff00;
        }
        .metric-label {
            font-size: 12px;
            color: #888;
        }
        #network-graph {
            height: 600px;
        }
        #metrics-chart, #heatmap, #timeline {
            height: 400px;
        }
        .controls {
            margin-top: 20px;
        }
        button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }
        button:hover {
            background: #45a049;
        }
        .status-indicator {
            display: inline-block;
            width: 10px;
            height: 10px;
            border-radius: 50%;
            margin-right: 5px;
        }
        .status-normal { background: #00ff00; }
        .status-scanning { background: #ffff00; }
        .status-compromised { background: #ff0000; }
        .status-defended { background: #0000ff; }
    </style>
</head>
<body>
    <h1>🎯 Real-Time Attack Simulation Dashboard</h1>
    
    <div class="metrics">
        <div class="metric">
            <div class="metric-value" id="fps">0</div>
            <div class="metric-label">FPS</div>
        </div>
        <div class="metric">
            <div class="metric-value" id="cpu">0%</div>
            <div class="metric-label">CPU Usage</div>
        </div>
        <div class="metric">
            <div class="metric-value" id="memory">0%</div>
            <div class="metric-label">Memory</div>
        </div>
        <div class="metric">
            <div class="metric-value" id="flows">0</div>
            <div class="metric-label">Active Flows</div>
        </div>
    </div>
    
    <div class="dashboard">
        <div>
            <div class="panel">
                <h2>Network Topology</h2>
                <div id="network-graph"></div>
                <div class="controls">
                    <button onclick="simulateAttack()">Simulate Attack</button>
                    <button onclick="resetNetwork()">Reset Network</button>
                    <button onclick="toggleAutoAttack()">Auto Attack: OFF</button>
                </div>
            </div>
            
            <div class="panel">
                <h2>Attack Timeline</h2>
                <div id="timeline"></div>
            </div>
        </div>
        
        <div>
            <div class="panel">
                <h2>Attack Metrics</h2>
                <div id="metrics-chart"></div>
            </div>
            
            <div class="panel">
                <h2>Attack Heatmap</h2>
                <div id="heatmap"></div>
            </div>
            
            <div class="panel">
                <h2>Live Feed</h2>
                <div id="live-feed" style="height: 200px; overflow-y: auto;">
                    <!-- Attack events will appear here -->
                </div>
            </div>
        </div>
    </div>
    
    <script>
        const socket = io();
        let autoAttack = false;
        let autoAttackInterval = null;
        
        socket.on('connect', function() {
            console.log('Connected to visualization server');
            updateGraphs();
        });
        
        socket.on('metrics_update', function(data) {
            document.getElementById('fps').innerText = data.fps || 0;
            document.getElementById('cpu').innerText = (data.cpu_usage || 0).toFixed(1) + '%';
            document.getElementById('memory').innerText = (data.memory_usage || 0).toFixed(1) + '%';
            document.getElementById('flows').innerText = data.active_flows || 0;
        });
        
        socket.on('node_update', function(data) {
            addToFeed(`Node ${data.node_id} status: ${data.status}`);
            updateGraphs();
        });
        
        socket.on('attack_flow', function(data) {
            const status = data.success ? '✓ Success' : '✗ Failed';
            addToFeed(`Attack: ${data.source} → ${data.target} [${data.attack_type}] ${status}`);
        });
        
        function addToFeed(message) {
            const feed = document.getElementById('live-feed');
            const entry = document.createElement('div');
            entry.style.padding = '5px';
            entry.style.borderBottom = '1px solid #444';
            entry.innerHTML = `<small>${new Date().toLocaleTimeString()}</small> ${message}`;
            feed.insertBefore(entry, feed.firstChild);
            
            // Keep only last 20 entries
            while (feed.children.length > 20) {
                feed.removeChild(feed.lastChild);
            }
        }
        
        function updateGraphs() {
            // Update network graph
            fetch('/api/network')
                .then(response => response.json())
                .then(data => {
                    if (data.data) {
                        Plotly.newPlot('network-graph', data.data, data.layout);
                    }
                });
            
            // Update metrics
            fetch('/api/metrics')
                .then(response => response.json())
                .then(data => {
                    if (data.data) {
                        Plotly.newPlot('metrics-chart', data.data, data.layout);
                    }
                });
            
            // Update heatmap
            fetch('/api/heatmap')
                .then(response => response.json())
                .then(data => {
                    if (data.data) {
                        Plotly.newPlot('heatmap', data.data, data.layout);
                    }
                });
            
            // Update timeline
            fetch('/api/timeline')
                .then(response => response.json())
                .then(data => {
                    if (data.data) {
                        Plotly.newPlot('timeline', data.data, data.layout);
                    }
                });
        }
        
        function simulateAttack() {
            const nodes = ['internet_0', 'dmz_0', 'internal_0', 'critical_0', 'database_0'];
            const source = nodes[Math.floor(Math.random() * nodes.length)];
            const target = nodes[Math.floor(Math.random() * nodes.length)];
            
            socket.emit('simulate_attack', {
                source: source,
                target: target
            });
        }
        
        function resetNetwork() {
            location.reload();
        }
        
        function toggleAutoAttack() {
            autoAttack = !autoAttack;
            const button = event.target;
            
            if (autoAttack) {
                button.innerText = 'Auto Attack: ON';
                button.style.background = '#ff4444';
                autoAttackInterval = setInterval(simulateAttack, 2000);
            } else {
                button.innerText = 'Auto Attack: OFF';
                button.style.background = '#4CAF50';
                clearInterval(autoAttackInterval);
            }
        }
        
        // Update graphs every 5 seconds
        setInterval(updateGraphs, 5000);
    </script>
</body>
</html>
"""

# Save HTML template
import os
os.makedirs('/home/ubuntu/Documents/Claude/ADVERSARIAL_SIMULATIONS/VISUALIZATION/templates', exist_ok=True)
with open('/home/ubuntu/Documents/Claude/ADVERSARIAL_SIMULATIONS/VISUALIZATION/templates/dashboard.html', 'w') as f:
    f.write(dashboard_html)


if __name__ == "__main__":
    async def main():
        await visualizer.start_visualization_server()
        
        # Keep running
        while True:
            await asyncio.sleep(1)
    
    asyncio.run(main())