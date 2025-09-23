#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Claude Master Installer v11.0 - Complete System Edition with UltraThink Integration
# Enhanced with Documentation Organization & Descriptive Commands
# ═══════════════════════════════════════════════════════════════════════════

# Read the original installer first
ORIGINAL_INSTALLER="$CLAUDE_PROJECT_ROOT/claude-installer.sh"

if [[ ! -f "$ORIGINAL_INSTALLER" ]]; then
    echo "❌ Error: Original claude-installer.sh not found"
    exit 1
fi

# UltraThink Integration Points:
# 1. Add documentation organization function after setup_natural_invocation
# 2. Add descriptive commands creation after setup_environment  
# 3. Update show_summary to include new commands
# 4. Update TOTAL_STEPS to reflect new steps

# Create enhanced installer by inserting our new functions
echo "🧠 UltraThink: Integrating Documentation Organization & Descriptive Commands into Claude Installer..."

# Copy the original installer and enhance it
cp "$ORIGINAL_INSTALLER" /tmp/claude-installer-temp.sh

# 1. First, update the TOTAL_STEPS count (add 2 more steps)
sed -i 's/TOTAL_STEPS=23/TOTAL_STEPS=25/' /tmp/claude-installer-temp.sh

# 2. Insert the new functions before the main() function
cat >> /tmp/claude-installer-temp.sh << 'EOF'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ULTRATHINK ENHANCED FUNCTIONS - Documentation & Commands Organization
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Organize documentation into proper structure
organize_documentation() {
    print_section "Organizing Documentation Structure"
    
    info "Creating professional documentation organization..."
    
    # Create docs subdirectories
    force_mkdir "$PROJECT_ROOT/docs/setup"
    force_mkdir "$PROJECT_ROOT/docs/status"  
    force_mkdir "$PROJECT_ROOT/docs/references"
    
    # Move setup and installation guides
    info "📁 Organizing setup guides..."
    for file in FIRST_TIME_LAUNCH_GUIDE.md README_COMPLETE.md README_CONTAINERIZED_SYSTEM.md; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            mv "$PROJECT_ROOT/$file" "$PROJECT_ROOT/docs/setup/" 2>/dev/null
            success "  ✓ $file → docs/setup/"
        fi
    done
    
    # Move status and verification reports
    info "📊 Organizing status reports..."
    for file in HYBRID_INTEGRATION_STATUS.md VERIFICATION_REPORT.md; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            mv "$PROJECT_ROOT/$file" "$PROJECT_ROOT/docs/status/" 2>/dev/null
            success "  ✓ $file → docs/status/"
        fi
    done
    
    # Move reference files
    info "📖 Organizing references..."
    for file in MANIFEST.txt VERSION agent-invocation-patterns.yaml; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            mv "$PROJECT_ROOT/$file" "$PROJECT_ROOT/docs/references/" 2>/dev/null
            success "  ✓ $file → docs/references/"
        fi
    done
    
    # Create documentation index
    cat > "$PROJECT_ROOT/docs/README.md" << 'DOCEOF'
# Documentation Directory

## Structure

### `/setup/` - Installation & Setup Guides
- `FIRST_TIME_LAUNCH_GUIDE.md` - Complete first-time launch instructions
- `README_COMPLETE.md` - Comprehensive setup documentation  
- `README_CONTAINERIZED_SYSTEM.md` - Container system documentation

### `/status/` - System Status & Reports
- `HYBRID_INTEGRATION_STATUS.md` - Current integration status
- `VERIFICATION_REPORT.md` - System verification results

### `/01-GETTING-STARTED/` - Quick Start
- Basic installation and usage guides

### `/05-SYSTEMS/` - System Documentation
- Technical system documentation
- Architecture guides

### `/references/` - Technical References
- `MANIFEST.txt` - System manifest
- `VERSION` - Version information
- `agent-invocation-patterns.yaml` - Agent coordination patterns

## Quick Navigation

- **New Users**: Start with `/setup/FIRST_TIME_LAUNCH_GUIDE.md`
- **System Health**: Check `/status/HYBRID_INTEGRATION_STATUS.md`
- **Technical Details**: Browse `/05-SYSTEMS/`
- **Installation**: See `/01-GETTING-STARTED/`

## Main Documentation in Root
- `../README.md` - Main project entry point (start here)
- `../CLAUDE.md` - Project context and instructions
DOCEOF
    
    success "Documentation organization complete"
    success "  • docs/setup/ - Installation guides"
    success "  • docs/status/ - Status reports"
    success "  • docs/references/ - Technical references"
    success "  • docs/README.md - Documentation index created"
    
    show_progress
}

# Create descriptive command shortcuts
create_descriptive_commands() {
    print_section "Creating Descriptive Command Shortcuts"
    
    info "Creating professional command names that tell you EXACTLY what you're running..."
    
    # Remove any old generic names
    rm -f "$PROJECT_ROOT/launch" "$PROJECT_ROOT/status-check" "$PROJECT_ROOT/setup" "$PROJECT_ROOT/integrate" 2>/dev/null
    
    # Create crystal clear descriptive names
    if [[ -f "$PROJECT_ROOT/launch_hybrid_system.sh" ]]; then
        ln -sf launch_hybrid_system.sh "$PROJECT_ROOT/launch-hybrid-bridge"
        success "  ✓ ./launch-hybrid-bridge - Launch PostgreSQL hybrid bridge integration system"
    fi
    
    if [[ -f "$PROJECT_ROOT/check_system_status.sh" ]]; then
        ln -sf check_system_status.sh "$PROJECT_ROOT/check-hybrid-bridge-health"
        success "  ✓ ./check-hybrid-bridge-health - Check PostgreSQL hybrid bridge system health"
    fi
    
    if [[ -f "$PROJECT_ROOT/claude-installer.sh" ]]; then
        ln -sf claude-installer.sh "$PROJECT_ROOT/setup-claude-agents"
        success "  ✓ ./setup-claude-agents - Setup Claude Agent Framework (65+ agents)"
    fi
    
    if [[ -f "$PROJECT_ROOT/integrate_hybrid_bridge.sh" ]]; then
        ln -sf integrate_hybrid_bridge.sh "$PROJECT_ROOT/setup-hybrid-bridge"
        success "  ✓ ./setup-hybrid-bridge - Setup PostgreSQL hybrid bridge integration"
    fi
    
    if [[ -f "$PROJECT_ROOT/integrated_learning_setup.py" ]]; then
        ln -sf integrated_learning_setup.py "$PROJECT_ROOT/setup-learning-system"
        success "  ✓ ./setup-learning-system - Setup ML-powered learning system (155K+ lines)"
    fi
    
    if [[ -f "$PROJECT_ROOT/github-sync.sh" ]]; then
        ln -sf github-sync.sh "$PROJECT_ROOT/sync-to-github"
        success "  ✓ ./sync-to-github - Sync project to GitHub repository"
    fi
    
    success "Descriptive command shortcuts created"
    success "  • No more guessing what commands do"
    success "  • Each name tells you exactly what system you're operating"
    success "  • Professional, self-documenting interface"
    
    show_progress
}

EOF

# 3. Now we need to modify the main() function to include our new functions
# Insert organize_documentation after setup_natural_invocation
sed -i '/setup_natural_invocation/a\        organize_documentation' /tmp/claude-installer-temp.sh

# Insert create_descriptive_commands after setup_environment  
sed -i '/setup_environment/a\    create_descriptive_commands' /tmp/claude-installer-temp.sh

# 4. Update the show_summary function to include the new commands
# We need to add a new section for our descriptive commands
cat >> /tmp/claude-installer-temp.sh << 'EOF'

# Update show_summary to include descriptive commands
update_show_summary_with_descriptive_commands() {
    # This will be inserted into the original show_summary
    echo ""
    print_bold "UltraThink Enhanced Commands (NEW):"
    echo "🚀 SYSTEM OPERATIONS:"
    printf "  %-35s %s\n" "./launch-hybrid-bridge" "Launch PostgreSQL hybrid bridge integration system"
    printf "  %-35s %s\n" "./check-hybrid-bridge-health" "Check PostgreSQL hybrid bridge system health"
    echo ""
    echo "🔧 SETUP OPERATIONS:"
    printf "  %-35s %s\n" "./setup-claude-agents" "Setup Claude Agent Framework (65+ agents)"
    printf "  %-35s %s\n" "./setup-hybrid-bridge" "Setup PostgreSQL hybrid bridge integration"
    printf "  %-35s %s\n" "./setup-learning-system" "Setup ML-powered learning system (155K+ lines)"
    echo ""
    echo "🌐 MAINTENANCE:"
    printf "  %-35s %s\n" "./sync-to-github" "Sync project to GitHub repository"
    echo ""
    echo "📚 DOCUMENTATION:"
    printf "  %-35s %s\n" "docs/README.md" "Complete documentation index"
    printf "  %-35s %s\n" "docs/setup/" "Installation & setup guides"
    printf "  %-35s %s\n" "docs/status/" "System status & reports"
}

EOF

# 5. Insert the descriptive commands section into show_summary function
# Find the line with "Quick Functions:" and insert our section before it
sed -i '/print_bold "Quick Functions:"/i\    update_show_summary_with_descriptive_commands' /tmp/claude-installer-temp.sh

# 6. Move the enhanced installer to replace the original
mv /tmp/claude-installer-temp.sh "$PROJECT_ROOT/claude-installer.sh"
chmod +x "$PROJECT_ROOT/claude-installer.sh"

echo "✅ UltraThink Integration Complete!"
echo ""
echo "📋 Enhanced Claude Installer v11.0 Features:"
echo "  ✅ Documentation Organization - Professional docs/ structure"
echo "  ✅ Descriptive Commands - Crystal clear command names"
echo "  ✅ Enhanced Summary - Shows all new features"
echo "  ✅ Integrated Installation Flow - Seamless user experience"
echo ""
echo "🚀 The installer now includes:"
echo "  • Automatic documentation organization into docs/ subdirectories"
echo "  • Descriptive command creation (no more guessing what commands do)"
echo "  • Professional project structure maintenance"
echo "  • Enhanced user experience with clear command names"
echo ""
echo "💡 Users will now get:"
echo "  ./launch-hybrid-bridge        (instead of vague 'launch')"
echo "  ./check-hybrid-bridge-health  (instead of 'status-check')"
echo "  ./setup-claude-agents         (instead of 'setup')"
echo "  ./setup-hybrid-bridge         (instead of 'integrate')"
echo ""
echo "🎯 Run the enhanced installer:"
echo "  ./claude-installer.sh"