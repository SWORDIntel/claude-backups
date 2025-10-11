# HTML Portal System - Organized Structure

## 📁 Directory Structure

```
html/
├── index.html                  # Main portal selector (START HERE)
│
├── portals/                    # All interactive portals
│   ├── SYSTEM_MAP.html         # Comprehensive map (⭐ recommended)
│   ├── index.html              # Unified master portal
│   ├── ai-enhanced-docs-browser.html
│   ├── universal-docs-browser.html
│   ├── browser_test.html
│   └── portal-test-suite.html
│
├── modules/                    # Module documentation pages (existing)
│   ├── agent-coordination.html
│   ├── agent-ecosystem.html
│   ├── shadowgit-performance.html
│   └── ... (10 total pages)
│
├── data/                       # All JSON data files
│   ├── agents-data.json        # 98 agents catalog
│   ├── modules-data.json       # 34+ modules inventory
│   ├── dependencies-graph.json # Dependency mapping
│   ├── performance-metrics.json
│   ├── workflows-msc.json
│   └── ... (10 total JSON files)
│
├── scripts/                    # Automation scripts
│   ├── launch-map.sh          # Launch portals
│   ├── verify-map.sh          # Validation
│   ├── master-automation.sh   # Run all automation
│   ├── merge-html-systems.py  # Merge HTML content
│   ├── generate-portal-data.py
│   ├── optimize-portal.py
│   └── ... (12 total scripts)
│
├── docs/                       # Complete documentation
│   ├── COMPREHENSIVE-SYSTEM-MAP-COMPLETE.md
│   ├── PORTAL-ARCHITECTURE-VALIDATION.md
│   ├── PORTAL-FIXES-IMPLEMENTATION.md
│   ├── QUICK-START.md
│   └── ... (9 total guides)
│
├── templates/                  # HTML templates
│   └── dashboard-metrics-template.html
│
├── css/                        # Stylesheets (existing)
│   └── base-framework.css
│
├── js/                         # JavaScript modules (existing)
│   └── base-framework.js
│
└── assets/                     # Static assets
    └── (reserved for images, fonts, etc.)
```

---

## 🚀 Quick Start

### **Option 1: Portal Selector** (Recommended)
```bash
cd /home/john/Downloads/claude-backups/html
firefox index.html
```
Opens a beautiful selector page with all 4 portals.

### **Option 2: Direct Portal Access**
```bash
# Most comprehensive
firefox html/portals/SYSTEM_MAP.html

# Master dashboard
firefox html/portals/index.html

# AI documentation
firefox html/portals/ai-enhanced-docs-browser.html

# Simple browser
firefox html/portals/universal-docs-browser.html
```

### **Option 3: Launch Scripts**
```bash
cd /home/john/Downloads/claude-backups/html/scripts
./launch-map.sh          # Auto-detects browser
./launch-map.sh --serve  # HTTP server mode
```

---

## 📊 Portal Comparison

| Portal | Size | Features | Best For |
|--------|------|----------|----------|
| **SYSTEM_MAP.html** | 684 KB | 98 agents, D3.js, Mermaid, 12 tabs | System architecture |
| **index.html** (portals/) | 900 KB | Dashboard, metrics, all docs | Daily use |
| **ai-enhanced** | 43 KB | AI chat, dark mode | Doc reading |
| **universal** | 39 KB | Fast, simple | Quick reference |

---

## 🎯 What's in Each Folder

### `/portals/` - Interactive Applications
All browser-based applications for system exploration and documentation.

### `/modules/` - Module Documentation
10 detailed HTML pages for major system components (agent-coordination, shadowgit-performance, etc.)

### `/data/` - Structured Datasets
JSON files with all system information extracted by agents.

### `/scripts/` - Automation Tools
Python and bash scripts for portal generation, validation, and updates.

### `/docs/` - Documentation Guides
Comprehensive markdown documentation covering usage, architecture, and fixes.

### `/templates/` - HTML Templates
Reusable templates for dashboard and metric visualizations.

### `/css/` & `/js/` - Shared Assets
Base framework styles and JavaScript (used by module pages).

---

## 🔧 Common Tasks

### Launch Any Portal
```bash
# From html/ directory
firefox portals/SYSTEM_MAP.html

# Or use scripts
scripts/launch-map.sh
```

### Update Portal Data
```bash
cd scripts
python3 generate-portal-data.py
python3 embed-data.py
```

### Validate Architecture
```bash
cd scripts
./verify-map.sh
python3 validate_system_map.py
```

### Run Full Automation
```bash
cd scripts
./master-automation.sh
```

---

## 📈 System Statistics

**Content:**
- 98 AI agents documented
- 34+ modules mapped
- 10 module HTML pages
- 15+ MSC workflows
- 500+ dependencies tracked

**Files:**
- 6 portal HTML files
- 10 JSON data files
- 12 automation scripts
- 9 documentation guides
- 10 module pages (existing)
- 2 framework files (CSS + JS)

**Total:** 49 organized files

---

## 🎨 Design System

All portals use a cohesive design:
- **Theme:** Neon dark mode with cyan/purple accents
- **Typography:** -apple-system font stack
- **Layout:** Responsive grid with flexbox
- **Animations:** Smooth transitions and effects
- **Compatibility:** All modern browsers

---

## 🆘 Troubleshooting

### Portal Won't Load?
```bash
# Try HTTP server mode
cd /home/john/Downloads/claude-backups/html
python3 -m http.server 8000
# Then open: http://localhost:8000/portals/SYSTEM_MAP.html
```

### Need to Update Data?
```bash
cd scripts
python3 generate-system-data.py
python3 embed-data.py
```

### Want to Validate?
```bash
cd scripts
./verify-map.sh
```

---

## 📚 Documentation

All documentation is in `docs/` folder:

- **QUICK-START.md** - 3-second launch guide
- **COMPREHENSIVE-SYSTEM-MAP-COMPLETE.md** - Full system overview
- **PORTAL-ARCHITECTURE-VALIDATION.md** - Technical validation (950 lines)
- **PORTAL-FIXES-IMPLEMENTATION.md** - Code examples and fixes
- **INTEGRATION-REPORT.md** - Agent coordination details

---

## ✅ Quality Assurance

**Validation Status:**
- Architecture: 93% (431/464 tests passed)
- No circular dependencies
- Comprehensive responsive design
- Production ready (with quick fixes)

**Files:**
- All HTML validated
- All JSON syntax correct
- All scripts executable
- All paths relative (portable)

---

## 🎉 Ready to Use!

Everything is organized and ready. Start with:

```bash
firefox /home/john/Downloads/claude-backups/html/index.html
```

Choose your portal and explore the complete Claude system architecture!

---

**Last Updated:** October 2, 2025
**Status:** ✅ Production Ready
**Organization:** Complete & Validated
