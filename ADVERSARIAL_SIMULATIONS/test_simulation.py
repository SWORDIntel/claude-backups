#!/usr/bin/env python3
"""
Quick test script for adversarial simulation framework
"""

import asyncio
import sys
import os

# Add path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

async def test_orchestrator():
    """Test the simulation orchestrator"""
    print("Testing Simulation Orchestrator...")
    
    try:
        from ORCHESTRATOR.simulation_orchestrator import SimulationOrchestrator, AttackScenario, AttackPhase, SimulationComplexity
        
        # Create orchestrator
        orchestrator = SimulationOrchestrator()
        
        # Create test scenario
        scenario = AttackScenario(
            name="Test Beijing Attack",
            description="Test scenario for Beijing smart city",
            complexity=SimulationComplexity.ADVANCED,
            phases=[
                AttackPhase.RECONNAISSANCE,
                AttackPhase.INITIAL_ACCESS,
                AttackPhase.LATERAL_MOVEMENT,
                AttackPhase.IMPACT
            ],
            target_certificates=["*.beijing.gov.cn", "*.bjca.org.cn"],
            duration_hours=24,
            actors=["APT-Test"],
            objectives=["Test infrastructure compromise"]
        )
        
        # Register scenario
        orchestrator.scenarios[scenario.id] = scenario
        
        print(f"✓ Created scenario: {scenario.name}")
        print(f"  ID: {scenario.id}")
        print(f"  Phases: {len(scenario.phases)}")
        print(f"  Complexity: {scenario.complexity.name}")
        
        return True
        
    except Exception as e:
        print(f"✗ Orchestrator test failed: {e}")
        return False

async def test_visualization():
    """Test visualization components"""
    print("\nTesting Visualization System...")
    
    try:
        from VISUALIZATION.realtime_visualization import SimulationVisualizer, NetworkNode
        
        # Create visualizer
        viz = SimulationVisualizer()
        
        # Test network creation
        print(f"✓ Network nodes: {len(viz.nodes)}")
        print(f"✓ Network edges: {viz.network_graph.number_of_edges()}")
        
        # Test node update
        if viz.nodes:
            first_node = list(viz.nodes.keys())[0]
            viz.update_node_status(first_node, 'compromised')
            print(f"✓ Updated node {first_node} to compromised")
        
        # Test plot generation
        network_plot = viz.generate_network_plot()
        print(f"✓ Generated network plot: {len(network_plot.get('data', []))} traces")
        
        return True
        
    except Exception as e:
        print(f"✗ Visualization test failed: {e}")
        return False

async def test_bridge():
    """Test integration bridge"""
    print("\nTesting Integration Bridge...")
    
    try:
        from INTEGRATION.agent_bridge import AgentSimulationBridge, AgentMessage, MessageType
        
        # Create bridge (don't start it, just test creation)
        bridge = AgentSimulationBridge(agent_port=14242, sim_port=15555)  # Different ports to avoid conflicts
        
        print(f"✓ Bridge created")
        print(f"  Agent port: {bridge.agent_port}")
        print(f"  Simulation port: {bridge.sim_port}")
        
        # Test agent registration
        bridge.register_agent('TestAgent', ['test', 'simulation'])
        print(f"✓ Registered test agent")
        
        # Test scenario mapping
        agents = bridge.map_scenario_to_agents('beijing_smart_city')
        print(f"✓ Scenario mapping: {agents}")
        
        return True
        
    except Exception as e:
        print(f"✗ Bridge test failed: {e}")
        return False

async def test_performance():
    """Test performance optimization tools"""
    print("\nTesting Performance Optimization...")
    
    try:
        from PERFORMANCE.optimizer import CPUOptimizer, MemoryOptimizer, AutoTuner
        
        # Test CPU optimizer
        cpu_opt = CPUOptimizer()
        print(f"✓ CPU cores detected: {cpu_opt.cpu_count}")
        print(f"  P-cores: {cpu_opt.p_cores}")
        print(f"  E-cores: {cpu_opt.e_cores}")
        
        # Test memory optimizer
        mem_opt = MemoryOptimizer()
        print(f"✓ Memory: {mem_opt.total_memory / (1024**3):.1f} GB")
        print(f"  Page size: {mem_opt.page_size} bytes")
        print(f"  Huge pages: {mem_opt.huge_pages_enabled}")
        
        # Test auto-tuner
        tuner = AutoTuner()
        params = await tuner.auto_tune('compute_intensive')
        print(f"✓ Auto-tuning for compute_intensive:")
        print(f"  CPU cores: {params.get('cpu_cores', [])[:3]}...")  # Show first 3
        print(f"  Thread pool: {params.get('thread_pool_size')}")
        
        return True
        
    except Exception as e:
        print(f"✗ Performance test failed: {e}")
        return False

async def main():
    """Run all tests"""
    print("="*60)
    print("ADVERSARIAL SIMULATION FRAMEWORK - COMPONENT TEST")
    print("="*60)
    
    results = []
    
    # Run tests
    results.append(await test_orchestrator())
    results.append(await test_visualization())
    results.append(await test_bridge())
    results.append(await test_performance())
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print(f"✅ ALL TESTS PASSED ({passed}/{total})")
        print("\nFramework is ready to use!")
        print("\nTo start the full system:")
        print("  ./build_and_run.sh --all")
        print("\nTo access dashboard after starting:")
        print("  http://localhost:5000")
    else:
        print(f"⚠️ SOME TESTS FAILED ({passed}/{total} passed)")
        print("\nCheck the errors above and fix before running.")
    
    return passed == total

if __name__ == "__main__":
    success = asyncio.run(main())
    sys.exit(0 if success else 1)