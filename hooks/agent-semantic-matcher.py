#!/usr/bin/env python3
"""
Enhanced Agent Semantic Matcher v2.0
ML-style fuzzy matching for all 58+ agents with semantic understanding
"""

import re
import json
import yaml
import os
from typing import Dict, List, Tuple, Optional, Set, Any
from pathlib import Path
from collections import defaultdict
from dataclasses import dataclass
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get base path from environment or use relative path
BASE_PATH = os.environ.get('CLAUDE_BASE_PATH', Path.home() / '.config' / 'claude')
PATTERNS_FILE = os.environ.get('CLAUDE_PATTERNS_FILE', BASE_PATH / 'agent-invocation-patterns.yaml')

@dataclass
class SemanticCluster:
    """Semantic word cluster for concept matching"""
    core: List[str]
    related: List[str]
    action: List[str]
    context: List[str]

class EnhancedSemanticMatcher:
    """
    Advanced semantic matching with full agent support
    """
    
    def __init__(self, patterns_file: Optional[str] = None):
        self.patterns_file = Path(patterns_file or PATTERNS_FILE)
        self.semantic_clusters = self._initialize_semantic_clusters()
        self.agent_expertise = self._initialize_agent_expertise()
        self.concept_graph = self._build_concept_graph()
        
        # Try to load patterns if file exists
        if self.patterns_file.exists():
            self.load_patterns()
        else:
            logger.info(f"Patterns file not found at {self.patterns_file}, using defaults")
            self.patterns = self._get_default_patterns()
    
    def load_patterns(self):
        """Load patterns from YAML file"""
        try:
            with open(self.patterns_file, 'r') as f:
                self.patterns = yaml.safe_load(f)
        except Exception as e:
            logger.warning(f"Could not load patterns: {e}, using defaults")
            self.patterns = self._get_default_patterns()
    
    def _get_default_patterns(self) -> Dict[str, Any]:
        """Get default patterns if file doesn't exist"""
        return {
            'keyword_triggers': {},
            'compound_patterns': {
                'security_audit': {
                    'required': ['security', 'audit OR review OR assessment'],
                    'optional': ['vulnerability', 'compliance', 'penetration'],
                    'agents': ['cso', 'securityauditor', 'security', 'cryptoexpert'],
                    'confidence': 0.9
                },
                'deployment_pipeline': {
                    'required': ['deploy OR release', 'production OR staging'],
                    'optional': ['ci/cd', 'pipeline', 'rollback'],
                    'agents': ['deployer', 'infrastructure', 'monitor', 'testbed'],
                    'confidence': 0.9
                },
                'performance_optimization': {
                    'required': ['performance OR speed OR optimize', 'slow OR fast OR latency'],
                    'optional': ['profile', 'benchmark', 'bottleneck'],
                    'agents': ['optimizer', 'monitor', 'debugger'],
                    'confidence': 0.85
                }
            }
        }
    
    def _initialize_semantic_clusters(self) -> Dict[str, SemanticCluster]:
        """Initialize comprehensive semantic clusters"""
        return {
            'security': SemanticCluster(
                core=['security', 'secure', 'vulnerability', 'threat', 'risk', 'exploit'],
                related=['safety', 'protection', 'defense', 'guard', 'shield', 'firewall', 'harden'],
                action=['audit', 'scan', 'check', 'review', 'assess', 'analyze', 'penttest', 'fuzz'],
                context=['breach', 'attack', 'compromise', 'incident', 'intrusion', 'malware', 'zero-day']
            ),
            'quantum': SemanticCluster(
                core=['quantum', 'post-quantum', 'quantum-resistant', 'qkd', 'quantum-safe'],
                related=['cryptographic', 'lattice', 'hash-based', 'code-based', 'multivariate'],
                action=['migrate', 'upgrade', 'implement', 'protect', 'secure'],
                context=['y2q', 'harvest-now-decrypt-later', 'shor', 'grover', 'nist-pqc']
            ),
            'intelligence': SemanticCluster(
                core=['intelligence', 'sigint', 'osint', 'humint', 'cyber-intelligence'],
                related=['surveillance', 'reconnaissance', 'collection', 'analysis', 'attribution'],
                action=['gather', 'collect', 'analyze', 'correlate', 'attribute', 'track'],
                context=['apt', 'nation-state', 'campaign', 'ttps', 'iocs', 'threat-actor']
            ),
            'chaos': SemanticCluster(
                core=['chaos', 'resilience', 'fault', 'failure', 'stress'],
                related=['reliability', 'availability', 'durability', 'robustness', 'antifragile'],
                action=['inject', 'simulate', 'test', 'break', 'stress', 'load'],
                context=['failure-mode', 'blast-radius', 'recovery', 'mttr', 'mtbf', 'sla']
            ),
            'performance': SemanticCluster(
                core=['performance', 'speed', 'fast', 'slow', 'optimize', 'efficiency'],
                related=['quick', 'rapid', 'sluggish', 'lag', 'delay', 'throughput', 'bandwidth'],
                action=['improve', 'enhance', 'boost', 'accelerate', 'tune', 'profile', 'benchmark'],
                context=['bottleneck', 'latency', 'response-time', 'load', 'scale', 'cache', 'memory']
            ),
            'debugging': SemanticCluster(
                core=['bug', 'error', 'issue', 'problem', 'defect', 'crash', 'exception'],
                related=['glitch', 'fault', 'flaw', 'mistake', 'trouble', 'malfunction', 'anomaly'],
                action=['fix', 'debug', 'solve', 'repair', 'patch', 'resolve', 'troubleshoot', 'diagnose'],
                context=['stack-trace', 'core-dump', 'segfault', 'memory-leak', 'deadlock', 'race-condition']
            ),
            'testing': SemanticCluster(
                core=['test', 'testing', 'qa', 'quality', 'validation', 'verification'],
                related=['check', 'examination', 'evaluation', 'assessment', 'proof', 'acceptance'],
                action=['validate', 'verify', 'confirm', 'ensure', 'prove', 'demonstrate', 'execute'],
                context=['coverage', 'regression', 'unit', 'integration', 'e2e', 'smoke', 'canary']
            ),
            'deployment': SemanticCluster(
                core=['deploy', 'deployment', 'release', 'rollout', 'launch', 'ship'],
                related=['publish', 'distribute', 'provision', 'deliver', 'promote', 'push'],
                action=['migrate', 'transfer', 'move', 'install', 'configure', 'rollback'],
                context=['production', 'staging', 'environment', 'pipeline', 'ci/cd', 'devops', 'gitops']
            ),
            'architecture': SemanticCluster(
                core=['architecture', 'design', 'structure', 'pattern', 'blueprint', 'topology'],
                related=['framework', 'scaffold', 'skeleton', 'foundation', 'schema', 'model'],
                action=['design', 'architect', 'plan', 'model', 'diagram', 'outline', 'structure'],
                context=['microservices', 'monolith', 'serverless', 'distributed', 'scalable', 'event-driven']
            ),
            'data': SemanticCluster(
                core=['data', 'database', 'storage', 'persistence', 'dataset', 'datastore'],
                related=['repository', 'warehouse', 'lake', 'mart', 'cache', 'index'],
                action=['query', 'insert', 'update', 'delete', 'migrate', 'backup', 'restore'],
                context=['sql', 'nosql', 'transaction', 'schema', 'table', 'acid', 'cap']
            ),
            'ml_ai': SemanticCluster(
                core=['ml', 'ai', 'machine-learning', 'artificial-intelligence', 'model', 'neural'],
                related=['deep-learning', 'algorithm', 'prediction', 'classification', 'clustering'],
                action=['train', 'predict', 'classify', 'cluster', 'recommend', 'analyze', 'infer'],
                context=['dataset', 'feature', 'epoch', 'accuracy', 'loss', 'tensor', 'gradient']
            ),
            'api': SemanticCluster(
                core=['api', 'endpoint', 'service', 'interface', 'contract', 'specification'],
                related=['rest', 'graphql', 'soap', 'rpc', 'webhook', 'gateway', 'openapi'],
                action=['expose', 'consume', 'integrate', 'connect', 'communicate', 'call'],
                context=['authentication', 'authorization', 'rate-limit', 'cors', 'swagger', 'postman']
            ),
            'infrastructure': SemanticCluster(
                core=['infrastructure', 'iaac', 'cloud', 'servers', 'cluster', 'datacenter'],
                related=['terraform', 'ansible', 'kubernetes', 'docker', 'aws', 'azure', 'gcp'],
                action=['provision', 'configure', 'scale', 'orchestrate', 'manage', 'monitor'],
                context=['vpc', 'subnet', 'loadbalancer', 'autoscaling', 'ha', 'dr', 'backup']
            ),
            'mobile': SemanticCluster(
                core=['mobile', 'app', 'ios', 'android', 'smartphone', 'tablet'],
                related=['native', 'hybrid', 'pwa', 'react-native', 'flutter', 'swift', 'kotlin'],
                action=['develop', 'build', 'compile', 'sign', 'publish', 'distribute'],
                context=['appstore', 'playstore', 'apk', 'ipa', 'bundle', 'sdk', 'responsive']
            ),
            'networking': SemanticCluster(
                core=['network', 'networking', 'routing', 'switching', 'tcp/ip', 'protocol'],
                related=['bgp', 'ospf', 'vlan', 'vpn', 'firewall', 'nat', 'dns', 'dhcp'],
                action=['configure', 'route', 'forward', 'filter', 'monitor', 'trace'],
                context=['packet', 'frame', 'segment', 'latency', 'bandwidth', 'qos', 'acl']
            ),
            'iot': SemanticCluster(
                core=['iot', 'embedded', 'sensor', 'device', 'edge', 'arduino', 'raspberry'],
                related=['mqtt', 'coap', 'zigbee', 'bluetooth', 'lora', 'gateway', 'hub'],
                action=['connect', 'monitor', 'control', 'actuate', 'sense', 'transmit'],
                context=['telemetry', 'firmware', 'ota', 'mesh', 'low-power', 'real-time']
            ),
            'compliance': SemanticCluster(
                core=['compliance', 'regulation', 'governance', 'audit', 'policy', 'standard'],
                related=['gdpr', 'hipaa', 'pci-dss', 'sox', 'iso27001', 'nist', 'framework'],
                action=['enforce', 'validate', 'audit', 'report', 'certify', 'attest'],
                context=['control', 'requirement', 'evidence', 'remediation', 'exception', 'risk']
            )
        }
    
    def _initialize_agent_expertise(self) -> Dict[str, List[str]]:
        """Initialize expertise for all 58+ agents"""
        return {
            # ORCHESTRATORS
            'director': ['strategy', 'planning', 'leadership', 'vision', 'coordination', 'roadmap', 'architecture'],
            'projectorchestrator': ['coordination', 'orchestration', 'workflow', 'pipeline', 'task', 'dependency'],
            'redteamorchestrator': ['redteam', 'penetration', 'attack', 'exploit', 'adversarial', 'offensive'],
            
            # SECURITY
            'cso': ['security', 'compliance', 'risk', 'governance', 'policy', 'audit', 'ciso'],
            'security': ['protection', 'defense', 'threat', 'incident', 'response', 'vulnerability'],
            'securityauditor': ['audit', 'vulnerability', 'penetration', 'scan', 'assessment', 'compliance'],
            'securitychaosagent': ['chaos', 'resilience', 'failure', 'stress', 'break', 'fuzzing'],
            'cryptoexpert': ['encryption', 'cryptography', 'certificates', 'ssl', 'tls', 'keys', 'pki'],
            'quantumguard': ['quantum', 'post-quantum', 'quantum-resistant', 'qkd', 'lattice', 'pqc'],
            'bastion': ['firewall', 'gateway', 'proxy', 'vpn', 'access', 'jumphost', 'perimeter'],
            
            # INTELLIGENCE & SPECIALIZED SECURITY
            'nsa': ['sigint', 'signals', 'intelligence', 'intercept', 'analysis', 'surveillance'],
            'apt41-defense-agent': ['apt', 'advanced-threat', 'nation-state', 'defense', 'attribution'],
            'bgp-purple-team-agent': ['bgp', 'routing', 'purple-team', 'network', 'autonomous-system'],
            'psyops_agent': ['psyops', 'social-engineering', 'influence', 'deception', 'misinformation'],
            
            # DEVELOPMENT
            'leadengineer': ['technical', 'leadership', 'architecture', 'review', 'mentor', 'code-review'],
            'constructor': ['build', 'create', 'implement', 'develop', 'construct', 'scaffold'],
            'debugger': ['debug', 'troubleshoot', 'diagnose', 'investigate', 'trace', 'profile'],
            'patcher': ['fix', 'patch', 'repair', 'hotfix', 'resolve', 'correct', 'remedy'],
            'linter': ['lint', 'style', 'format', 'standards', 'conventions', 'quality'],
            
            # LANGUAGE-SPECIFIC
            'python-internal': ['python', 'py', 'pip', 'django', 'flask', 'pandas', 'numpy'],
            'rust-internal': ['rust', 'cargo', 'rustc', 'lifetime', 'borrow', 'memory-safety'],
            'go-internal': ['golang', 'go', 'goroutine', 'channel', 'defer', 'concurrency'],
            'typescript-internal': ['typescript', 'ts', 'tsx', 'types', 'interface', 'javascript'],
            'cpp_internal_agent': ['cpp', 'c++', 'stl', 'template', 'pointer', 'performance'],
            'c-internal': ['c', 'malloc', 'pointer', 'struct', 'embedded', 'system'],
            'java-internal': ['java', 'jvm', 'spring', 'maven', 'gradle', 'enterprise'],
            'kotlin-internal': ['kotlin', 'android', 'coroutine', 'suspend', 'jvm'],
            'zig-internal': ['zig', 'comptime', 'allocator', 'manual-memory'],
            'assembly-internal-agent': ['assembly', 'asm', 'nasm', 'masm', 'register', 'low-level'],
            'carbon-internal': ['carbon', 'carbon-lang', 'experimental', 'cpp-interop'],
            
            # UI/FRONTEND
            'web': ['web', 'frontend', 'react', 'vue', 'angular', 'html', 'css', 'javascript'],
            'androidmobile': ['android', 'mobile', 'app', 'apk', 'gradle', 'kotlin'],
            'pygui': ['gui', 'desktop', 'tkinter', 'pyqt', 'kivy', 'window'],
            'tui': ['terminal', 'cli', 'console', 'ncurses', 'text-ui'],
            
            # DATA & ML
            'datascience': ['data', 'analysis', 'statistics', 'visualization', 'pandas', 'numpy'],
            'mlops': ['ml', 'pipeline', 'training', 'model', 'deployment', 'kubeflow'],
            'researcher': ['research', 'investigate', 'explore', 'evaluate', 'study', 'literature'],
            
            # INFRASTRUCTURE
            'infrastructure': ['infrastructure', 'devops', 'terraform', 'kubernetes', 'cloud', 'iaac'],
            'docker-agent': ['docker', 'container', 'dockerfile', 'compose', 'swarm'],
            'proxmox-agent': ['proxmox', 'vm', 'virtual', 'hypervisor', 'kvm'],
            'cisco-agent': ['cisco', 'network', 'router', 'switch', 'ios', 'vlan'],
            'ddwrt-agent': ['ddwrt', 'router', 'firmware', 'wireless', 'openwrt'],
            
            # OPERATIONS
            'deployer': ['deploy', 'release', 'rollout', 'delivery', 'ci/cd', 'pipeline'],
            'monitor': ['monitor', 'observability', 'metrics', 'logging', 'alerting', 'tracking'],
            'packager': ['package', 'bundle', 'artifact', 'dependency', 'npm', 'pip'],
            
            # SPECIALIZED
            'database': ['database', 'sql', 'query', 'schema', 'migration', 'postgres'],
            'apidesigner': ['api', 'rest', 'graphql', 'endpoint', 'contract', 'openapi'],
            'docgen': ['documentation', 'docs', 'guide', 'manual', 'reference', 'readme'],
            'testbed': ['test', 'validate', 'verify', 'execute', 'automation', 'ci'],
            'qadirector': ['qa', 'quality', 'testing', 'standards', 'process', 'metrics'],
            'optimizer': ['optimize', 'performance', 'speed', 'efficiency', 'benchmark', 'profile'],
            'oversight': ['compliance', 'governance', 'audit', 'review', 'control', 'policy'],
            'planner': ['plan', 'planning', 'schedule', 'timeline', 'roadmap', 'milestone'],
            'integration': ['integration', 'integrate', 'connect', 'bridge', 'interface', 'api'],
            
            # HARDWARE
            'npu': ['npu', 'neural', 'ai-acceleration', 'inference', 'tensor', 'tpu'],
            'gna': ['gna', 'gaussian', 'neural-acceleration', 'audio-ai', 'low-power'],
            'iot-access-control-agent': ['iot', 'device', 'sensor', 'mqtt', 'embedded', 'arduino']
        }
    
    def _build_concept_graph(self) -> Dict[str, Set[str]]:
        """Build a graph of related concepts"""
        graph = defaultdict(set)
        
        # Build relationships from semantic clusters
        for cluster_name, cluster in self.semantic_clusters.items():
            all_words = cluster.core + cluster.related + cluster.action + cluster.context
            for word in all_words:
                graph[word].add(cluster_name)
                # Add bidirectional relationships
                for other_word in all_words:
                    if word != other_word:
                        graph[word].add(other_word)
        
        return dict(graph)
    
    def calculate_semantic_similarity(self, text: str, target: str, use_graph: bool = True) -> float:
        """
        Advanced semantic similarity calculation
        """
        text_lower = text.lower()
        target_lower = target.lower()
        
        # Direct match
        if target_lower in text_lower:
            return 1.0
        
        # Partial match with word boundaries
        if re.search(r'\b' + re.escape(target_lower) + r'\b', text_lower):
            return 0.95
        
        # Stem matching (improved)
        target_stem = self._get_stem(target_lower)
        if target_stem and target_stem in text_lower:
            return 0.8
        
        # Concept graph matching
        if use_graph and target_lower in self.concept_graph:
            related_concepts = self.concept_graph[target_lower]
            for concept in related_concepts:
                if isinstance(concept, str) and concept in text_lower:
                    return 0.7
        
        # Semantic cluster matching
        for cluster_name, cluster in self.semantic_clusters.items():
            all_words = cluster.core + cluster.related + cluster.action + cluster.context
            
            if target_lower in all_words:
                for word in all_words:
                    if word in text_lower:
                        # Weight by word importance
                        if word in cluster.core:
                            return 0.85
                        elif word in cluster.action:
                            return 0.75
                        elif word in cluster.related:
                            return 0.65
                        else:  # context
                            return 0.55
        
        # Fuzzy string matching (Levenshtein-like)
        if self._fuzzy_match(text_lower, target_lower):
            return 0.4
        
        return 0.0
    
    def _get_stem(self, word: str) -> Optional[str]:
        """Simple stemming function"""
        if len(word) <= 3:
            return word
        
        # Common suffixes to remove
        suffixes = ['ing', 'ed', 'er', 'est', 'ly', 'tion', 'ment', 's', 'es']
        for suffix in suffixes:
            if word.endswith(suffix) and len(word) - len(suffix) >= 3:
                return word[:-len(suffix)]
        
        return word[:max(3, len(word) - 2)]
    
    def _fuzzy_match(self, text: str, target: str, threshold: float = 0.7) -> bool:
        """Simple fuzzy matching"""
        # Check if most characters of target are in text
        target_chars = set(target)
        text_chars = set(text)
        common = target_chars.intersection(text_chars)
        
        if len(common) / len(target_chars) >= threshold:
            return True
        
        return False
    
    def match_agents(self, user_input: str, threshold: float = 0.5) -> Dict[str, float]:
        """
        Match user input to agents using semantic similarity
        """
        agent_scores = defaultdict(float)
        input_lower = user_input.lower()
        
        # Check each agent's expertise
        for agent, expertise_terms in self.agent_expertise.items():
            scores = []
            for term in expertise_terms:
                similarity = self.calculate_semantic_similarity(input_lower, term)
                if similarity > 0:
                    scores.append(similarity)
            
            if scores:
                # Use weighted average of top scores
                top_scores = sorted(scores, reverse=True)[:5]
                weights = [1.0, 0.8, 0.6, 0.4, 0.2][:len(top_scores)]
                weighted_sum = sum(s * w for s, w in zip(top_scores, weights))
                weighted_avg = weighted_sum / sum(weights[:len(top_scores)])
                
                if weighted_avg >= threshold:
                    agent_scores[agent] = weighted_avg
        
        return dict(agent_scores)
    
    def detect_workflow_patterns(self, user_input: str) -> List[Tuple[str, List[str], float]]:
        """
        Detect workflow patterns using advanced semantic matching
        """
        detected_patterns = []
        input_lower = user_input.lower()
        
        # Predefined workflow patterns
        workflow_patterns = {
            'security_assessment': {
                'triggers': ['security audit', 'vulnerability assessment', 'pen test', 'security review'],
                'agents': ['cso', 'securityauditor', 'security', 'cryptoexpert'],
                'confidence': 0.9
            },
            'incident_response': {
                'triggers': ['production down', 'incident', 'emergency', 'outage', 'crash'],
                'agents': ['debugger', 'monitor', 'patcher', 'deployer', 'leadengineer'],
                'confidence': 0.95
            },
            'ml_pipeline': {
                'triggers': ['ml pipeline', 'machine learning deployment', 'model training', 'mlops'],
                'agents': ['mlops', 'datascience', 'optimizer', 'monitor'],
                'confidence': 0.85
            },
            'full_stack_dev': {
                'triggers': ['full stack', 'end to end', 'frontend and backend', 'complete application'],
                'agents': ['web', 'apidesigner', 'database', 'infrastructure'],
                'confidence': 0.85
            },
            'quantum_migration': {
                'triggers': ['quantum safe', 'post quantum', 'quantum resistant', 'pqc migration'],
                'agents': ['quantumguard', 'cryptoexpert', 'security', 'cso'],
                'confidence': 0.9
            },
            'red_team_exercise': {
                'triggers': ['red team', 'adversarial', 'attack simulation', 'purple team'],
                'agents': ['redteamorchestrator', 'apt41-defense-agent', 'securitychaosagent'],
                'confidence': 0.95
            }
        }
        
        # Check each workflow pattern
        for pattern_name, pattern_config in workflow_patterns.items():
            max_similarity = 0
            for trigger in pattern_config['triggers']:
                similarity = self.calculate_semantic_similarity(input_lower, trigger, use_graph=True)
                max_similarity = max(max_similarity, similarity)
            
            if max_similarity > 0.6:
                confidence = max_similarity * pattern_config['confidence']
                detected_patterns.append((
                    pattern_name,
                    pattern_config['agents'],
                    confidence
                ))
        
        # Check compound patterns from loaded patterns
        if hasattr(self, 'patterns') and 'compound_patterns' in self.patterns:
            for pattern_name, pattern_config in self.patterns['compound_patterns'].items():
                required = pattern_config.get('required', [])
                optional = pattern_config.get('optional', [])
                
                # Check required terms
                required_matches = 0
                for req_term in required:
                    if ' OR ' in req_term:
                        terms = req_term.split(' OR ')
                        for term in terms:
                            if self.calculate_semantic_similarity(input_lower, term.strip()) > 0.5:
                                required_matches += 1
                                break
                    else:
                        if self.calculate_semantic_similarity(input_lower, req_term) > 0.5:
                            required_matches += 1
                
                if required_matches > 0 and required:
                    confidence = (required_matches / len(required)) * pattern_config.get('confidence', 0.8)
                    
                    # Boost for optional matches
                    for opt_term in optional:
                        if self.calculate_semantic_similarity(input_lower, opt_term) > 0.5:
                            confidence = min(1.0, confidence + 0.05)
                    
                    if confidence >= 0.6:
                        agents = pattern_config.get('agents', [])
                        if pattern_name not in [p[0] for p in detected_patterns]:
                            detected_patterns.append((pattern_name, agents, confidence))
        
        return sorted(detected_patterns, key=lambda x: x[2], reverse=True)
    
    def extract_explicit_invocations(self, user_input: str) -> List[Tuple[str, str, float]]:
        """
        Extract explicit agent invocations with confidence
        """
        invocations = []
        input_lower = user_input.lower()
        
        # Extended invocation patterns
        invocation_patterns = [
            (r'\b(?:invoke|use|call|summon|engage|activate|deploy|trigger)\s+(?:the\s+)?(\w+)', 1.0),
            (r'\b(?:ask|request|have|get|tell|instruct)\s+(?:the\s+)?(\w+)\s+to', 0.9),
            (r'\b(?:coordinate|orchestrate)\s+(?:with\s+)?(?:the\s+)?(\w+)', 0.85),
            (r'\busing\s+(?:the\s+)?(\w+)\s+agent', 0.95),
            (r'\b(\w+)\s+agent\s+(?:should|must|needs?\s+to)', 0.9),
            (r'\bwith\s+(?:the\s+)?(\w+)\s+agent', 0.8),
        ]
        
        for pattern, confidence in invocation_patterns:
            matches = re.finditer(pattern, input_lower)
            for match in matches:
                target = match.group(1)
                
                # Match target to actual agent names
                for agent_name in self.agent_expertise.keys():
                    similarity = self.calculate_semantic_similarity(agent_name.lower(), target)
                    if similarity > 0.7:
                        invocations.append((agent_name, target, confidence * similarity))
        
        return sorted(invocations, key=lambda x: x[2], reverse=True)
    
    def get_contextual_recommendations(self, user_input: str, top_k: int = 5) -> List[Tuple[str, float, str]]:
        """
        Get comprehensive agent recommendations with reasoning
        """
        combined_scores = defaultdict(float)
        reasoning = defaultdict(list)
        
        # Semantic matching
        semantic_matches = self.match_agents(user_input)
        for agent, score in semantic_matches.items():
            combined_scores[agent] = max(combined_scores[agent], score)
            if score > 0.7:
                reasoning[agent].append(f"High semantic match ({score:.2f})")
        
        # Workflow patterns
        workflow_patterns = self.detect_workflow_patterns(user_input)
        for pattern_name, agents, confidence in workflow_patterns:
            for agent in agents:
                combined_scores[agent] = max(combined_scores[agent], confidence * 0.9)
                reasoning[agent].append(f"Workflow: {pattern_name.replace('_', ' ')}")
        
        # Explicit invocations
        explicit_invocations = self.extract_explicit_invocations(user_input)
        for agent, target, confidence in explicit_invocations:
            combined_scores[agent] = max(combined_scores[agent], confidence)
            reasoning[agent].append(f"Explicit invocation: '{target}'")
        
        # Sort and prepare recommendations
        sorted_agents = sorted(combined_scores.items(), key=lambda x: x[1], reverse=True)[:top_k]
        
        recommendations = []
        for agent, score in sorted_agents:
            # Get primary reason
            agent_reasons = reasoning.get(agent, ["Contextual relevance"])
            primary_reason = agent_reasons[0] if agent_reasons else "Contextual relevance"
            recommendations.append((agent, score, primary_reason))
        
        return recommendations


class EnhancedAgentMatcher:
    """
    Main interface combining keyword and semantic matching
    """
    
    def __init__(self):
        self.semantic_matcher = EnhancedSemanticMatcher()
    
    def match(self, user_input: str) -> Dict[str, Any]:
        """
        Comprehensive matching with all methods
        """
        results = {
            'input': user_input,
            'semantic_agents': {},
            'keyword_agents': {},
            'explicit_invocations': [],
            'workflow_patterns': [],
            'recommended_agents': [],
            'confidence': 0.0
        }
        
        # Semantic matching
        semantic_agents = self.semantic_matcher.match_agents(user_input)
        results['semantic_agents'] = semantic_agents
        
        # Keyword matching (using semantic similarity)
        keyword_agents = self._match_keywords(user_input)
        results['keyword_agents'] = keyword_agents
        
        # Explicit invocations
        invocations = self.semantic_matcher.extract_explicit_invocations(user_input)
        results['explicit_invocations'] = invocations
        
        # Workflow patterns
        patterns = self.semantic_matcher.detect_workflow_patterns(user_input)
        results['workflow_patterns'] = patterns
        
        # Get recommendations
        recommendations = self.semantic_matcher.get_contextual_recommendations(user_input)
        results['recommended_agents'] = recommendations
        
        # Calculate overall confidence
        all_scores = list(semantic_agents.values()) + list(keyword_agents.values())
        if all_scores:
            results['confidence'] = max(all_scores)
        
        return results
    
    def _match_keywords(self, user_input: str) -> Dict[str, float]:
        """Enhanced keyword matching using semantic similarity"""
        matched_agents = {}
        input_lower = user_input.lower()
        
        # Common keyword to agent mappings
        keyword_mappings = {
            'security': ['cso', 'security', 'securityauditor', 'cryptoexpert'],
            'deploy': ['deployer', 'infrastructure', 'docker-agent'],
            'test': ['testbed', 'qadirector', 'securitychaosagent'],
            'optimize': ['optimizer', 'npu', 'gna'],
            'debug': ['debugger', 'patcher', 'monitor'],
            'api': ['apidesigner', 'web', 'integration'],
            'database': ['database', 'datascience'],
            'mobile': ['androidmobile', 'web'],
            'network': ['cisco-agent', 'ddwrt-agent', 'bgp-purple-team-agent'],
            'quantum': ['quantumguard', 'cryptoexpert'],
            'ml': ['mlops', 'datascience', 'npu']
        }
        
        for keyword, agents in keyword_mappings.items():
            if keyword in input_lower:
                for agent in agents:
                    matched_agents[agent] = 0.8
        
        return matched_agents


# CLI Testing Interface
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Enhanced Agent Semantic Matcher v2.0")
    parser.add_argument("input", nargs="*", help="User input to match")
    parser.add_argument("--test", action="store_true", help="Run test suite")
    parser.add_argument("--agents", action="store_true", help="List all agents")
    
    args = parser.parse_args()
    
    matcher = EnhancedAgentMatcher()
    
    if args.agents:
        print("\n🤖 All Registered Agents:")
        print("=" * 70)
        for agent in sorted(matcher.semantic_matcher.agent_expertise.keys()):
            expertise = matcher.semantic_matcher.agent_expertise[agent]
            print(f"  • {agent:30} {', '.join(expertise[:3])}")
    
    elif args.test:
        test_cases = [
            "We need a quantum-safe encryption implementation",
            "Perform red team exercise on production",
            "Debug the Rust memory leak issue",
            "Deploy the mobile app to both stores",
            "Setup BGP routing with security measures",
            "Implement ML pipeline for fraud detection",
            "There's an APT campaign targeting our infrastructure",
            "Configure Proxmox cluster with high availability",
            "Need social engineering awareness training"
        ]
        
        print("\n🧪 Semantic Matcher Test Suite")
        print("=" * 70)
        
        for test_input in test_cases:
            print(f"\n📝 Input: {test_input}")
            print("-" * 60)
            
            results = matcher.match(test_input)
            
            print("🎯 Top Recommendations:")
            for agent, score, reason in results['recommended_agents'][:3]:
                print(f"  {agent:25} {score:.2f} - {reason}")
            
            if results['workflow_patterns']:
                pattern, agents, conf = results['workflow_patterns'][0]
                print(f"\n📋 Workflow: {pattern} ({conf:.2f})")
                print(f"   Agents: {', '.join(agents)}")
            
            print(f"\n✓ Confidence: {results['confidence']:.2f}")
    
    elif args.input:
        user_input = ' '.join(args.input)
        results = matcher.match(user_input)
        
        print("\n" + "=" * 70)
        print(f"Input: {user_input}")
        print("=" * 70)
        
        print("\n🔮 Semantic Matching:")
        for agent, score in sorted(results['semantic_agents'].items(), 
                                  key=lambda x: x[1], reverse=True)[:5]:
            print(f"  {agent:25} {score:.2f}")
        
        if results['explicit_invocations']:
            print("\n🎯 Explicit Invocations:")
            for agent, target, conf in results['explicit_invocations'][:3]:
                print(f"  {agent:25} ('{target}') - {conf:.2f}")
        
        if results['workflow_patterns']:
            print("\n📋 Detected Workflows:")
            for pattern, agents, conf in results['workflow_patterns'][:2]:
                print(f"  {pattern}: {', '.join(agents)} ({conf:.2f})")
        
        print("\n💡 Recommendations:")
        for agent, confidence, reason in results['recommended_agents'][:5]:
            print(f"  {agent:25} {confidence:.2f} - {reason}")
        
        print(f"\n✓ Overall Confidence: {results['confidence']:.2f}")
    
    else:
        parser.print_help()
