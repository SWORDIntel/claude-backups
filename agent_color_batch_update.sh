#!/bin/bash

# Agent color assignments based on functional categories
declare -A AGENT_COLORS=(
    ["Linter"]="indigo"
    ["Optimizer"]="cyan"
    ["Infrastructure"]="brown"
    ["Deployer"]="teal"
    ["Monitor"]="lime"
    ["Packager"]="olive"
    ["APIDesigner"]="turquoise"
    ["Database"]="amber"
    ["Web"]="lightblue"
    ["Mobile"]="pink"
    ["PyGUI"]="violet"
    ["TUI"]="emerald"
    ["DataScience"]="magenta"
    ["MLOps"]="coral"
    ["Docgen"]="gray"
    ["RESEARCHER"]="lavender"
    ["c-internal"]="darkgray"
    ["python-internal"]="lightgreen"
    ["SecurityChaosAgent"]="maroon"
    ["Oversight"]="darkred"
)

declare -A AGENT_UUIDS=(
    ["Linter"]="9a7c5e2f-8d4b-6e3a-9c1f-7e5a8c3f6d92"
    ["Optimizer"]="2e8f4c9a-5b7d-3e6a-8c4f-1e9a5c8f2d64"
    ["Infrastructure"]="3f9e2c8a-6d5b-4e7a-9c3f-2e8a6d4c9f71"
    ["Deployer"]="4c2e9f8a-7b5d-3e6a-8c1f-5e9a2c6f8d43"
    ["Monitor"]="5d3f2e9a-8c6b-4e7a-9c2f-6e3a9d5c2f84"
    ["Packager"]="6e4c3f2a-9d7b-5e8a-8c3f-7e4a2d6c9f15"
    ["APIDesigner"]="7f5d4e3a-2c9b-6e8a-9c4f-8e5a3c7f2d96"
    ["Database"]="8c6e5f4a-3d2b-7e9a-2c5f-9e6a4d8c3f27"
    ["Web"]="9d7f6e5a-4c3b-8e2a-3c6f-2e7a5d9c4f38"
    ["Mobile"]="2e8c7f6a-5d4b-9e3a-4c7f-3e8a6d2c5f49"
    ["PyGUI"]="3f9d8c7a-6e5b-2e4a-5c8f-4e9a7d3c6f52"
    ["TUI"]="4c2e9f8a-7d6b-3e5a-6c9f-5e2a8d4c7f63"
    ["DataScience"]="5d3f2e9a-8c7b-4e6a-7c2f-6e3a9d5c8f74"
    ["MLOps"]="6e4c3f2a-9d8b-5e7a-8c3f-7e4a2d6c9f85"
    ["Docgen"]="7f5d4e3a-2c9b-6e8a-9c4f-8e5a3c7f2d96"
    ["RESEARCHER"]="8c6e5f4a-3d2b-7e9a-2c5f-9e6a4d8c3f21"
    ["c-internal"]="9d7f6e5a-4c3b-8e2a-3c6f-2e7a5d9c4f32"
    ["python-internal"]="2e8c7f6a-5d4b-9e3a-4c7f-3e8a6d2c5f43"
    ["SecurityChaosAgent"]="3f9d8c7a-6e5b-2e4a-5c8f-4e9a7d3c6f54"
    ["Oversight"]="4c2e9f8a-7d6b-3e5a-6c9f-5e2a8d4c7f65"
)

# Function to add metadata to an agent file
add_metadata_to_agent() {
    local file="$1"
    local agent_name="$2"
    local color="${AGENT_COLORS[$agent_name]}"
    local uuid="${AGENT_UUIDS[$agent_name]}"
    
    if [[ -z "$color" || -z "$uuid" ]]; then
        echo "Missing color or UUID for $agent_name"
        return 1
    fi
    
    # Check if agent already has metadata
    if grep -q "agent_metadata:\|  metadata:" "$file"; then
        echo "$agent_name already has metadata"
        return 0
    fi
    
    # Find the insertion point (after thermal_management section)
    local temp_file=$(mktemp)
    local in_thermal=false
    local inserted=false
    
    while IFS= read -r line; do
        echo "$line" >> "$temp_file"
        
        # Look for the end of thermal_management or similar hardware sections
        if [[ "$line" =~ ^[[:space:]]*thermal_management: ]]; then
            in_thermal=true
        elif [[ "$in_thermal" == true && "$line" =~ ^[[:space:]]*normal.*°C ]]; then
            # Add metadata after thermal section
            cat >> "$temp_file" << EOF

agent_metadata:
  name: ${agent_name^^}
  version: 7.0.0
  uuid: $uuid
  category: DEVELOPMENT
  priority: HIGH
  status: PRODUCTION
  color: $color
EOF
            inserted=true
            in_thermal=false
        fi
    done < "$file"
    
    if [[ "$inserted" == true ]]; then
        mv "$temp_file" "$file"
        echo "Added metadata to $agent_name"
    else
        rm "$temp_file"
        echo "Could not find insertion point for $agent_name"
        return 1
    fi
}

# Process remaining agents
for agent in "${!AGENT_COLORS[@]}"; do
    file="/home/ubuntu/Documents/Claude/agents/${agent}.md"
    if [[ -f "$file" ]]; then
        add_metadata_to_agent "$file" "$agent"
    else
        echo "File not found: $file"
    fi
done

echo "Batch update complete!"