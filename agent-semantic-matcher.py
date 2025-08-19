#!/usr/bin/env python3
"""
Semantic Agent Matcher - ML-style fuzzy matching for agent invocation
Works alongside existing keyword patterns without restructuring
"""

import re
import json
import yaml
from typing import Dict, List, Tuple, Optional, Set
from pathlib import Path
from collections import defaultdict

class SemanticAgentMatcher:
    """
    ML-style fuzzy matching using semantic similarity
    Can work with or without actual ML libraries
    """
    
    def __init__(self, patterns_file: str = None):
        self.patterns_file = patterns_file or "/home/ubuntu/Documents/Claude/agent-invocation-patterns.yaml"
        self.load_patterns()
        self.build_semantic_map()
        
    def load_patterns(self):
        """Load existing patterns from YAML"""
        with open(self.patterns_file, 'r') as f:
            self.patterns = yaml.safe_load(f)
            
    def build_semantic_map(self):
        """Build semantic relationships between words and concepts"""
        # Semantic word clusters (poor man's word embeddings)
        self.semantic_clusters = {
            'security': {
                'core': ['security', 'secure', 'vulnerability', 'threat', 'risk'],
                'related': ['safety', 'protection', 'defense', 'guard', 'shield', 'firewall'],
                'action': ['audit', 'scan', 'check', 'review', 'assess', 'analyze', 'penttest'],
                'context': ['breach', 'attack', 'exploit', 'compromise', 'incident', 'intrusion']
            },
            'performance': {
                'core': ['performance', 'speed', 'fast', 'slow', 'optimize'],
                'related': ['efficiency', 'quick', 'rapid', 'sluggish', 'lag', 'delay'],
                'action': ['improve', 'enhance', 'boost', 'accelerate', 'tune', 'profile'],
                'context': ['bottleneck', 'latency', 'throughput', 'response', 'load', 'scale']
            },
            'bugs': {
                'core': ['bug', 'error', 'issue', 'problem', 'defect'],
                'related': ['glitch', 'fault', 'flaw', 'mistake', 'trouble', 'malfunction'],
                'action': ['fix', 'debug', 'solve', 'repair', 'patch', 'resolve', 'troubleshoot'],
                'context': ['crash', 'failure', 'broken', 'exception', 'stack trace', 'core dump']
            },
            'testing': {
                'core': ['test', 'testing', 'qa', 'quality', 'validation'],
                'related': ['verification', 'check', 'examination', 'evaluation', 'assessment'],
                'action': ['validate', 'verify', 'confirm', 'ensure', 'prove', 'demonstrate'],
                'context': ['coverage', 'regression', 'unit', 'integration', 'acceptance', 'smoke']
            },
            'deployment': {
                'core': ['deploy', 'deployment', 'release', 'rollout', 'launch'],
                'related': ['ship', 'publish', 'distribute', 'provision', 'deliver'],
                'action': ['push', 'promote', 'migrate', 'transfer', 'move', 'install'],
                'context': ['production', 'staging', 'environment', 'pipeline', 'cicd', 'devops']
            },
            'architecture': {
                'core': ['architecture', 'design', 'structure', 'pattern', 'blueprint'],
                'related': ['framework', 'scaffold', 'skeleton', 'foundation', 'schema'],
                'action': ['design', 'architect', 'plan', 'model', 'diagram', 'outline'],
                'context': ['microservices', 'monolith', 'serverless', 'distributed', 'scalable']
            },
            'database': {
                'core': ['database', 'db', 'data', 'storage', 'persistence'],
                'related': ['repository', 'store', 'warehouse', 'lake', 'mart'],
                'action': ['query', 'insert', 'update', 'delete', 'migrate', 'backup'],
                'context': ['sql', 'nosql', 'index', 'transaction', 'schema', 'table']
            },
            'api': {
                'core': ['api', 'endpoint', 'service', 'interface', 'contract'],
                'related': ['rest', 'graphql', 'soap', 'rpc', 'webhook', 'gateway'],
                'action': ['expose', 'consume', 'integrate', 'connect', 'communicate'],
                'context': ['authentication', 'authorization', 'rate limit', 'cors', 'swagger']
            },
            'ml_ai': {
                'core': ['ml', 'ai', 'machine learning', 'artificial intelligence', 'model'],
                'related': ['neural', 'deep learning', 'algorithm', 'prediction', 'classification'],
                'action': ['train', 'predict', 'classify', 'cluster', 'recommend', 'analyze'],
                'context': ['dataset', 'feature', 'epoch', 'accuracy', 'loss', 'tensor']
            }
        }
        
        # Agent expertise mapping (semantic understanding of what each agent does)
        self.agent_expertise = {
            'CSO': ['security', 'compliance', 'risk', 'governance', 'policy', 'audit'],
            'SecurityAuditor': ['vulnerability', 'penetration', 'scan', 'assessment', 'compliance'],
            'CryptoExpert': ['encryption', 'cryptography', 'certificates', 'ssl', 'tls', 'keys'],
            'Security': ['protection', 'defense', 'threat', 'incident', 'response'],
            'Optimizer': ['performance', 'speed', 'efficiency', 'optimization', 'profiling'],
            'Monitor': ['observability', 'metrics', 'logging', 'alerting', 'tracking'],
            'LeadEngineer': ['technical', 'leadership', 'architecture', 'review', 'mentor'],
            'Debugger': ['debug', 'troubleshoot', 'diagnose', 'investigate', 'trace'],
            'Patcher': ['fix', 'patch', 'repair', 'hotfix', 'resolve', 'correct'],
            'QADirector': ['quality', 'testing', 'validation', 'standards', 'process'],
            'Testbed': ['test', 'validate', 'verify', 'execute', 'automation'],
            'Docgen': ['documentation', 'docs', 'guide', 'manual', 'reference'],
            'RESEARCHER': ['research', 'investigate', 'explore', 'evaluate', 'study'],
            'Architect': ['design', 'architecture', 'structure', 'pattern', 'blueprint'],
            'Director': ['strategy', 'planning', 'leadership', 'vision', 'coordination'],
            'ProjectOrchestrator': ['coordination', 'orchestration', 'workflow', 'pipeline'],
            'Constructor': ['build', 'create', 'implement', 'develop', 'construct'],
            'Infrastructure': ['infrastructure', 'devops', 'servers', 'cloud', 'kubernetes'],
            'Deployer': ['deploy', 'release', 'rollout', 'delivery', 'cicd'],
            'Database': ['database', 'sql', 'query', 'schema', 'migration'],
            'DataScience': ['data', 'analysis', 'statistics', 'visualization', 'insights'],
            'MLOps': ['ml', 'pipeline', 'training', 'model', 'deployment'],
            'NPU': ['neural', 'acceleration', 'ai', 'inference', 'optimization'],
            'APIDesigner': ['api', 'rest', 'graphql', 'endpoint', 'contract'],
            'Web': ['web', 'frontend', 'react', 'vue', 'angular', 'ui'],
            'Mobile': ['mobile', 'ios', 'android', 'app', 'native'],
            'TUI': ['terminal', 'cli', 'console', 'text', 'interface'],
            'PyGUI': ['gui', 'desktop', 'tkinter', 'pyqt', 'interface'],
            'Linter': ['lint', 'style', 'format', 'standards', 'conventions'],
            'Oversight': ['compliance', 'governance', 'audit', 'review', 'control'],
            'Bastion': ['firewall', 'gateway', 'proxy', 'vpn', 'access'],
            'SecurityChaosAgent': ['chaos', 'resilience', 'failure', 'stress', 'break']
        }
        
    def calculate_semantic_similarity(self, text: str, target: str) -> float:
        """
        Calculate semantic similarity between text and target
        This is a simple implementation - can be replaced with actual embeddings
        """
        text_lower = text.lower()
        target_lower = target.lower()
        
        # Direct match
        if target_lower in text_lower:
            return 1.0
            
        # Check for word stem matches (simple stemming)
        target_stem = target_lower[:4] if len(target_lower) > 4 else target_lower
        if target_stem in text_lower:
            return 0.8
            
        # Check semantic clusters
        for cluster_name, cluster_words in self.semantic_clusters.items():
            all_words = []
            for word_list in cluster_words.values():
                all_words.extend(word_list)
                
            if target_lower in all_words:
                # Check if any cluster words appear in text
                similarity_scores = []
                for word in all_words:
                    if word in text_lower:
                        # Higher score for core words
                        if word in cluster_words.get('core', []):
                            similarity_scores.append(0.9)
                        elif word in cluster_words.get('action', []):
                            similarity_scores.append(0.7)
                        else:
                            similarity_scores.append(0.6)
                            
                if similarity_scores:
                    return max(similarity_scores)
                    
        return 0.0
        
    def fuzzy_match_agents(self, user_input: str, threshold: float = 0.6) -> Dict[str, float]:
        """
        Fuzzy match user input to agents using semantic similarity
        Returns agents with confidence scores
        """
        agent_scores = {}
        input_lower = user_input.lower()
        
        # Check each agent's expertise
        for agent, expertise_terms in self.agent_expertise.items():
            scores = []
            for term in expertise_terms:
                similarity = self.calculate_semantic_similarity(input_lower, term)
                if similarity > 0:
                    scores.append(similarity)
                    
            if scores:
                # Use average of top 3 scores
                top_scores = sorted(scores, reverse=True)[:3]
                agent_scores[agent] = sum(top_scores) / len(top_scores)
                
        # Filter by threshold
        return {k: v for k, v in agent_scores.items() if v >= threshold}
        
    def detect_compound_patterns(self, user_input: str) -> List[Tuple[str, List[str], float]]:
        """
        Detect compound patterns using fuzzy matching
        Returns list of (pattern_name, agents, confidence)
        """
        detected_patterns = []
        input_lower = user_input.lower()
        
        # Check each compound pattern
        for pattern_name, pattern_config in self.patterns.get('compound_patterns', {}).items():
            required = pattern_config.get('required', [])
            optional = pattern_config.get('optional', [])
            
            # Fuzzy match required terms
            required_matches = 0
            for req_term in required:
                # Handle OR conditions
                if ' OR ' in req_term:
                    terms = req_term.split(' OR ')
                    for term in terms:
                        if self.calculate_semantic_similarity(input_lower, term.strip()) > 0.5:
                            required_matches += 1
                            break
                else:
                    if self.calculate_semantic_similarity(input_lower, req_term) > 0.5:
                        required_matches += 1
                        
            # Calculate confidence based on matches
            if required_matches > 0:
                confidence = (required_matches / len(required)) * pattern_config.get('confidence', 0.8)
                
                # Boost confidence for optional matches
                for opt_term in optional:
                    if self.calculate_semantic_similarity(input_lower, opt_term) > 0.5:
                        confidence = min(1.0, confidence + 0.05)
                        
                if confidence >= 0.6:
                    agents = pattern_config.get('agents', [])
                    detected_patterns.append((pattern_name, agents, confidence))
                    
        return detected_patterns
        
    def extract_explicit_invocations(self, user_input: str) -> List[Tuple[str, str]]:
        """
        Extract explicit invocation requests using fuzzy matching
        Returns list of (verb, target) tuples
        """
        invocations = []
        input_lower = user_input.lower()
        
        # Invocation verb patterns with fuzzy matching
        verb_patterns = [
            r'\b(invoke|use|call|summon|engage|activate|deploy|trigger)\s+(?:the\s+)?(\w+)',
            r'\b(ask|request|have|get|tell|instruct)\s+(?:the\s+)?(\w+)\s+to',
            r'\b(coordinate|orchestrate|collaborate)\s+(?:with\s+)?(?:the\s+)?(\w+)',
        ]
        
        for pattern in verb_patterns:
            matches = re.finditer(pattern, input_lower)
            for match in matches:
                verb = match.group(1)
                target = match.group(2)
                invocations.append((verb, target))
                
        return invocations
        
    def get_contextual_agents(self, user_input: str) -> Dict[str, float]:
        """
        Get agents based on contextual understanding
        Uses semantic similarity and pattern detection
        """
        combined_scores = defaultdict(float)
        
        # Get fuzzy matched agents
        fuzzy_agents = self.fuzzy_match_agents(user_input)
        for agent, score in fuzzy_agents.items():
            combined_scores[agent] = max(combined_scores[agent], score)
            
        # Check compound patterns
        compound_patterns = self.detect_compound_patterns(user_input)
        for pattern_name, agents, confidence in compound_patterns:
            for agent in agents:
                combined_scores[agent] = max(combined_scores[agent], confidence * 0.9)
                
        # Check explicit invocations
        invocations = self.extract_explicit_invocations(user_input)
        for verb, target in invocations:
            # Fuzzy match target to agent names
            for agent in self.agent_expertise.keys():
                if self.calculate_semantic_similarity(agent.lower(), target) > 0.7:
                    combined_scores[agent] = 1.0  # Explicit invocation gets max score
                    
        return dict(combined_scores)
        
    def recommend_agents(self, user_input: str, top_k: int = 5) -> List[Tuple[str, float, str]]:
        """
        Recommend top agents for user input
        Returns list of (agent, confidence, reason) tuples
        """
        agent_scores = self.get_contextual_agents(user_input)
        
        # Sort by confidence
        sorted_agents = sorted(agent_scores.items(), key=lambda x: x[1], reverse=True)[:top_k]
        
        recommendations = []
        for agent, confidence in sorted_agents:
            # Determine reason for recommendation
            reason = self._get_recommendation_reason(user_input, agent, confidence)
            recommendations.append((agent, confidence, reason))
            
        return recommendations
        
    def _get_recommendation_reason(self, user_input: str, agent: str, confidence: float) -> str:
        """Generate human-readable reason for agent recommendation"""
        input_lower = user_input.lower()
        
        # Check for explicit invocation
        if confidence >= 1.0:
            return "Explicit invocation requested"
            
        # Check which expertise matched
        matched_expertise = []
        for term in self.agent_expertise.get(agent, []):
            if self.calculate_semantic_similarity(input_lower, term) > 0.5:
                matched_expertise.append(term)
                
        if matched_expertise:
            return f"Expertise match: {', '.join(matched_expertise[:3])}"
            
        # Check for compound pattern match
        for pattern_name, agents, _ in self.detect_compound_patterns(user_input):
            if agent in agents:
                return f"Pattern match: {pattern_name.replace('_', ' ')}"
                
        return "Contextual relevance"


class EnhancedAgentMatcher:
    """
    Enhanced matcher that combines keyword and semantic matching
    This is the main interface for the hybrid approach
    """
    
    def __init__(self):
        self.semantic_matcher = SemanticAgentMatcher()
        self.load_keyword_patterns()
        
    def load_keyword_patterns(self):
        """Load existing keyword patterns for hybrid matching"""
        with open(self.semantic_matcher.patterns_file, 'r') as f:
            self.patterns = yaml.safe_load(f)
            
    def match(self, user_input: str) -> Dict[str, any]:
        """
        Hybrid matching combining keywords and semantic similarity
        Returns comprehensive match results
        """
        results = {
            'input': user_input,
            'semantic_agents': {},
            'keyword_agents': {},
            'explicit_invocations': [],
            'compound_patterns': [],
            'recommended_agents': [],
            'confidence': 0.0
        }
        
        # Semantic matching
        semantic_agents = self.semantic_matcher.get_contextual_agents(user_input)
        results['semantic_agents'] = semantic_agents
        
        # Keyword matching (existing patterns)
        keyword_agents = self._match_keywords(user_input)
        results['keyword_agents'] = keyword_agents
        
        # Explicit invocations
        invocations = self.semantic_matcher.extract_explicit_invocations(user_input)
        results['explicit_invocations'] = invocations
        
        # Compound patterns
        patterns = self.semantic_matcher.detect_compound_patterns(user_input)
        results['compound_patterns'] = patterns
        
        # Get recommendations
        recommendations = self.semantic_matcher.recommend_agents(user_input)
        results['recommended_agents'] = recommendations
        
        # Calculate overall confidence
        if semantic_agents:
            results['confidence'] = max(semantic_agents.values())
            
        return results
        
    def _match_keywords(self, user_input: str) -> Dict[str, float]:
        """Match using existing keyword patterns"""
        matched_agents = {}
        input_lower = user_input.lower()
        
        for category, config in self.patterns.get('keyword_triggers', {}).items():
            keywords = config.get('keywords', [])
            agents = config.get('agents', [])
            
            for keyword in keywords:
                if keyword in input_lower:
                    for agent in agents:
                        matched_agents[agent] = 0.9  # High confidence for keyword match
                        
        return matched_agents
        
    def get_invocation_command(self, user_input: str) -> str:
        """
        Generate the Task tool invocation command based on matching
        """
        results = self.match(user_input)
        
        # Prioritize explicit invocations
        if results['explicit_invocations']:
            verb, target = results['explicit_invocations'][0]
            # Find matching agent
            for agent in results['semantic_agents'].keys():
                if self.semantic_matcher.calculate_semantic_similarity(agent.lower(), target) > 0.7:
                    return f'Task(subagent_type="{agent.lower()}", prompt="{user_input}")'
                    
        # Use top recommended agents
        if results['recommended_agents']:
            top_agents = [agent for agent, conf, _ in results['recommended_agents'] if conf > 0.7]
            if len(top_agents) == 1:
                return f'Task(subagent_type="{top_agents[0].lower()}", prompt="{user_input}")'
            elif len(top_agents) > 1:
                # Multi-agent coordination
                agents_str = ', '.join([f'"{a.lower()}"' for a in top_agents[:3]])
                return f'# Coordinate multiple agents: {agents_str}\n' + \
                       f'Task(subagent_type="projectorchestrator", prompt="Coordinate {agents_str} for: {user_input}")'
                       
        return None


# CLI interface for testing
if __name__ == "__main__":
    import sys
    
    matcher = EnhancedAgentMatcher()
    
    if len(sys.argv) > 1:
        user_input = ' '.join(sys.argv[1:])
    else:
        user_input = input("Enter request: ")
        
    results = matcher.match(user_input)
    
    print("\n" + "="*60)
    print(f"Input: {results['input']}")
    print("="*60)
    
    print("\n🔮 Semantic Matching:")
    for agent, score in sorted(results['semantic_agents'].items(), key=lambda x: x[1], reverse=True)[:5]:
        print(f"  {agent}: {score:.2f}")
        
    print("\n🔑 Keyword Matching:")
    for agent, score in results['keyword_agents'].items():
        print(f"  {agent}: {score:.2f}")
        
    print("\n📋 Recommendations:")
    for agent, confidence, reason in results['recommended_agents']:
        print(f"  {agent} ({confidence:.2f}): {reason}")
        
    if results['explicit_invocations']:
        print("\n🎯 Explicit Invocations:")
        for verb, target in results['explicit_invocations']:
            print(f"  {verb} → {target}")
            
    if results['compound_patterns']:
        print("\n🔗 Compound Patterns:")
        for pattern, agents, conf in results['compound_patterns']:
            print(f"  {pattern}: {', '.join(agents)} (confidence: {conf:.2f})")
            
    print("\n💡 Suggested Command:")
    command = matcher.get_invocation_command(user_input)
    if command:
        print(f"  {command}")
    else:
        print("  No specific agent recommendation")
        
    print("\n" + "="*60)