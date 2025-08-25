#!/bin/bash
# Organize Documentation Files into docs/ Directory

echo "📚 Organizing Documentation Files"
echo "================================="

# Create docs subdirectories if they don't exist
mkdir -p docs/{guides,setup,status,references}

echo "📁 Moving documentation files to docs/..."

# Move setup and installation guides
echo "🔧 Setup & Installation → docs/setup/"
for file in FIRST_TIME_LAUNCH_GUIDE.md README_COMPLETE.md README_CONTAINERIZED_SYSTEM.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/setup/ && echo "  ✅ $file → docs/setup/"
    fi
done

# Move status and verification reports  
echo "📊 Status & Reports → docs/status/"
for file in HYBRID_INTEGRATION_STATUS.md VERIFICATION_REPORT.md; do
    if [ -f "$file" ]; then
        mv "$file" docs/status/ && echo "  ✅ $file → docs/status/"
    fi
done

# Keep main README.md and CLAUDE.md in root (they're the main entry points)
echo "📋 Core docs staying in root:"
echo "  ✅ README.md (main project README)"
echo "  ✅ CLAUDE.md (project context and instructions)"

# Move other documentation files to references
echo "📖 References → docs/references/"
for file in MANIFEST.txt VERSION agent-invocation-patterns.yaml; do
    if [ -f "$file" ]; then
        mv "$file" docs/references/ && echo "  ✅ $file → docs/references/"
    fi
done

# Create a documentation index
cat > docs/README.md << 'EOF'
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
- `../README.md` - Main project README (start here)
- `../CLAUDE.md` - Project context and instructions
EOF

echo "📝 Created docs/README.md index"

echo
echo "✅ Documentation organization complete!"
echo
echo "📂 Documentation structure:"
echo "  docs/"
echo "  ├── README.md (documentation index)"
echo "  ├── setup/ (installation guides)"
echo "  ├── status/ (status reports)"
echo "  ├── 01-GETTING-STARTED/ (existing quick start)"
echo "  ├── 05-SYSTEMS/ (existing technical docs)"
echo "  └── references/ (technical references)"
echo
echo "📋 Root documentation (staying):"
echo "  ├── README.md (main project entry point)"
echo "  └── CLAUDE.md (project context and instructions)"
echo
echo "🎯 Clean and organized documentation structure!"