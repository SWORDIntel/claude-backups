---
metadata:
  name: AgentName
  version: 8.0.0
  uuid: unique-agent-uuid-here-unique00001
  category: CATEGORY_NAME
  priority: CRITICAL|HIGH|MEDIUM|LOW
  status: PRODUCTION
  
  # Visual identification
  color: "#HEXCODE"  # Color description - semantic meaning
  emoji: "🔧"  # Representative emoji for the agent
  
  description: |
    Comprehensive description of agent capabilities, specializations, and key features.
    Include quantifiable performance metrics, integration points, and unique value propositions.
    
    Core responsibilities include specific technical capabilities and measurable outcomes.
    
    Integration points include other agents this collaborates with and the nature of those relationships.
    
  # CRITICAL: Task tool compatibility for Claude Code
  tools:
  required:
  - Task  # MANDATORY for agent invocation
  code_operations:
  - Read
  - Write 
  - Edit
  - MultiEdit
  system_operations:
  - Bash
  - Grep
  - Glob
  - LS
  information:
  - WebFetch
  - WebSearch
  - ProjectKnowledgeSearch
  workflow:
  - TodoWrite
  - GitCommand
  analysis:  # Only for debugging/optimization agents
  - Analysis  # For complex analysis scenarios
  
  # Proactive invocation triggers for Claude Code
  proactive_triggers:
  patterns:
  - "Pattern 1 - regex or keyword patterns"
  - "Pattern 2 - triggering phrases"
  context_triggers:
  - "ALWAYS when [specific condition]"
  - "When [situational trigger]"
  auto_invoke:
  - "Condition → automatic action"
  keywords:
  - keyword1
  - keyword2
  
  # Agent collaboration patterns
  invokes_agents:
  frequently:
  - AgentName1  # Primary collaboration
  - AgentName2  # Regular coordination
  as_needed:
  - AgentName3  # Situational collaboration
  - AgentName4  # Specialized integration
  
  parallel_capable:  # Agents that can run simultaneously
  - AgentName5  # Can execute in parallel
  - AgentName6  # Concurrent execution safe
  
  # Usage examples
  examples:
  - "Example use case 1"
  - "Example use case 2"
---

################################################################################
# SPECIALIZED SECTIONS (if needed)
################################################################################

specialized_config:
  # Agent-specific configuration sections go here
  # Hardware requirements, specialized patterns, etc.