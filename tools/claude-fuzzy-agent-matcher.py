#!/usr/bin/env python3
"""
Claude Fuzzy Agent Matcher Integration
Provides ML-style fuzzy matching for Claude Code without restructuring
"""

import json
import sys
from pathlib import Path

# Import our semantic matcher
sys.path.insert(0, '/home/ubuntu/Documents/Claude')
from agent_semantic_matcher import EnhancedAgentMatcher

class ClaudeFuzzyMatcher:
    """
    Integration layer for Claude Code
    Provides simple API for fuzzy agent matching
    """
    
    def __init__(self):
        self.matcher = EnhancedAgentMatcher()
        
    def should_invoke_agents(self, user_input: str, confidence_threshold: float = 0.7) -> bool:
        """
        Determine if agents should be invoked based on fuzzy matching
        """
        results = self.matcher.match(user_input)
        return results['confidence'] >= confidence_threshold
        
    def get_agents_to_invoke(self, user_input: str, max_agents: int = 5) -> list:
        """
        Get list of agents to invoke based on fuzzy matching
        Returns list of agent names sorted by confidence
        """
        results = self.matcher.match(user_input)
        
        # Combine semantic and keyword agents
        all_agents = {}
        for agent, score in results['semantic_agents'].items():
            all_agents[agent] = score
        for agent, score in results['keyword_agents'].items():
            all_agents[agent] = max(all_agents.get(agent, 0), score)
            
        # Sort by confidence and return top agents
        sorted_agents = sorted(all_agents.items(), key=lambda x: x[1], reverse=True)
        return [agent for agent, _ in sorted_agents[:max_agents]]
        
    def get_invocation_plan(self, user_input: str) -> dict:
        """
        Get complete invocation plan with agents and reasoning
        """
        results = self.matcher.match(user_input)
        
        plan = {
            'should_invoke': self.should_invoke_agents(user_input),
            'confidence': results['confidence'],
            'agents': self.get_agents_to_invoke(user_input),
            'reasoning': [],
            'suggested_workflow': None
        }
        
        # Add reasoning
        for agent, conf, reason in results['recommended_agents'][:3]:
            plan['reasoning'].append(f"{agent}: {reason} (confidence: {conf:.2f})")
            
        # Suggest workflow if multiple agents
        if len(plan['agents']) > 1:
            if 'security' in user_input.lower() and 'audit' in user_input.lower():
                plan['suggested_workflow'] = 'security_assessment'
            elif 'deploy' in user_input.lower() or 'release' in user_input.lower():
                plan['suggested_workflow'] = 'deployment_pipeline'
            elif 'performance' in user_input.lower() or 'optimize' in user_input.lower():
                plan['suggested_workflow'] = 'performance_tuning'
            else:
                plan['suggested_workflow'] = 'multi_agent_coordination'
                
        return plan
        
    def format_task_invocation(self, user_input: str) -> str:
        """
        Format the Task tool invocation for Claude
        """
        plan = self.get_invocation_plan(user_input)
        
        if not plan['should_invoke']:
            return None
            
        agents = plan['agents']
        
        if len(agents) == 0:
            return None
        elif len(agents) == 1:
            return f'Task(subagent_type="{agents[0].lower()}", prompt="{user_input}")'
        else:
            # Multi-agent coordination
            if plan['suggested_workflow'] == 'security_assessment':
                return f'Task(subagent_type="cso", prompt="Coordinate security assessment: {user_input}")'
            elif plan['suggested_workflow'] == 'deployment_pipeline':
                return f'Task(subagent_type="deployer", prompt="Coordinate deployment: {user_input}")'
            elif plan['suggested_workflow'] == 'performance_tuning':
                return f'Task(subagent_type="optimizer", prompt="Coordinate optimization: {user_input}")'
            else:
                return f'Task(subagent_type="projectorchestrator", prompt="Coordinate {", ".join(agents[:3])}: {user_input}")'


# Lightweight API for direct use in Claude
def fuzzy_match_agents(user_input: str) -> dict:
    """Simple API for fuzzy matching agents"""
    matcher = ClaudeFuzzyMatcher()
    return matcher.get_invocation_plan(user_input)

def get_agent_command(user_input: str) -> str:
    """Get the Task command for agent invocation"""
    matcher = ClaudeFuzzyMatcher()
    return matcher.format_task_invocation(user_input)


# Example usage and testing
if __name__ == "__main__":
    test_inputs = [
        "There's a problem with database performance",
        "Let's build a secure payment system",
        "Deploy the new features to production",
        "The application crashed with an error",
        "Review the code for security issues",
        "Create documentation for the API",
        "Optimize the machine learning pipeline"
    ]
    
    matcher = ClaudeFuzzyMatcher()
    
    print("🧠 Claude Fuzzy Agent Matcher - Test Results")
    print("=" * 70)
    
    for test_input in test_inputs:
        print(f"\n📝 Input: {test_input}")
        print("-" * 70)
        
        plan = matcher.get_invocation_plan(test_input)
        
        print(f"✓ Should Invoke: {plan['should_invoke']}")
        print(f"📊 Confidence: {plan['confidence']:.2f}")
        print(f"🤖 Agents: {', '.join(plan['agents'][:3])}")
        
        if plan['reasoning']:
            print(f"💭 Reasoning: {plan['reasoning'][0]}")
            
        if plan['suggested_workflow']:
            print(f"🔄 Workflow: {plan['suggested_workflow']}")
            
        command = matcher.format_task_invocation(test_input)
        if command:
            print(f"💻 Command: {command[:80]}...")
            
    print("\n" + "=" * 70)
    print("✅ Fuzzy matching ready for integration!")