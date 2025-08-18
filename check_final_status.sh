#!/bin/bash

echo "=== FINAL STATUS CHECK: ALL AGENTS METADATA AND COLORS ==="
for file in /home/ubuntu/Documents/Claude/agents/*.md; do 
  if [[ $(basename "$file") != "Template.md" && $(basename "$file") != "README.md" && $(basename "$file") != "STATUSLINE_INTEGRATION.md" ]]; then
    agent_name=$(basename "$file" .md)
    if grep -q "agent_metadata:\|  metadata:\|^metadata:" "$file"; then
      if grep -q "color:" "$file"; then
        color=$(grep "color:" "$file" | head -1 | awk '{print $2}')
        echo "✓ COMPLETE: $agent_name (color: $color)"
      else
        echo "⚠ NEEDS_COLOR: $agent_name"
      fi
    else
      echo "✗ NEEDS_METADATA: $agent_name"
    fi
  fi
done | sort

echo ""
echo "=== SUMMARY ==="
complete_count=$(grep -l "agent_metadata:\|  metadata:\|^metadata:" /home/ubuntu/Documents/Claude/agents/*.md 2>/dev/null | grep -v Template.md | grep -v README.md | grep -v STATUSLINE_INTEGRATION.md | wc -l)
color_count=$(grep -l "color:" /home/ubuntu/Documents/Claude/agents/*.md 2>/dev/null | grep -v Template.md | grep -v README.md | grep -v STATUSLINE_INTEGRATION.md | wc -l)
total_agents=$(ls /home/ubuntu/Documents/Claude/agents/*.md | grep -v Template.md | grep -v README.md | grep -v STATUSLINE_INTEGRATION.md | wc -l)

echo "Agents with metadata: $complete_count/$total_agents"
echo "Agents with colors: $color_count/$total_agents"