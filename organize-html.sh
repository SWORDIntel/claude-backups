#!/bin/bash
# Organize all HTML portal files into html/ folder structure

set -e

BASE="/home/john/Downloads/claude-backups"
HTML_DIR="$BASE/html"

echo "🗂️  Organizing HTML Portal Files"
echo "=================================="
echo ""

# Create organized directory structure
echo "Creating directory structure..."
mkdir -p "$HTML_DIR/portals"
mkdir -p "$HTML_DIR/data"
mkdir -p "$HTML_DIR/scripts"
mkdir -p "$HTML_DIR/docs"
mkdir -p "$HTML_DIR/templates"
mkdir -p "$HTML_DIR/assets"

# Move portal HTML files
echo ""
echo "Moving portal HTML files..."
[ -f "$BASE/index.html" ] && mv -v "$BASE/index.html" "$HTML_DIR/portals/" || echo "  index.html not found"
[ -f "$BASE/SYSTEM_MAP.html" ] && mv -v "$BASE/SYSTEM_MAP.html" "$HTML_DIR/portals/" || echo "  SYSTEM_MAP.html not found"
[ -f "$BASE/ai-enhanced-docs-browser.html" ] && mv -v "$BASE/ai-enhanced-docs-browser.html" "$HTML_DIR/portals/" || echo "  ai-enhanced-docs-browser.html not found"
[ -f "$BASE/universal-docs-browser.html" ] && mv -v "$BASE/universal-docs-browser.html" "$HTML_DIR/portals/" || echo "  universal-docs-browser.html not found"
[ -f "$BASE/browser_test.html" ] && mv -v "$BASE/browser_test.html" "$HTML_DIR/portals/" || echo "  browser_test.html not found"
[ -f "$BASE/portal-test-suite.html" ] && mv -v "$BASE/portal-test-suite.html" "$HTML_DIR/portals/" || echo "  portal-test-suite.html not found"

# Move data JSON files
echo ""
echo "Moving data files..."
for json_file in agents-data modules-data dependencies-graph performance-metrics workflows-msc modules-content dashboard-metrics system-data components-data integrations-data design-system; do
    [ -f "$BASE/${json_file}.json" ] && mv -v "$BASE/${json_file}.json" "$HTML_DIR/data/" || echo "  ${json_file}.json not found"
done

# Move scripts
echo ""
echo "Moving scripts..."
for script in launch-map launch-portal verify-map master-automation; do
    [ -f "$BASE/${script}.sh" ] && mv -v "$BASE/${script}.sh" "$HTML_DIR/scripts/" || echo "  ${script}.sh not found"
done

# Move Python scripts
for py_script in generate-system-data embed-data merge-html-systems generate-portal-data optimize-portal validate_system_map; do
    [ -f "$BASE/${py_script}.py" ] && mv -v "$BASE/${py_script}.py" "$HTML_DIR/scripts/" || echo "  ${py_script}.py not found"
done

# Move JavaScript modules
[ -f "$BASE/dashboard-metrics.js" ] && mv -v "$BASE/dashboard-metrics.js" "$HTML_DIR/scripts/" || echo "  dashboard-metrics.js not found"

# Move templates
echo ""
echo "Moving templates..."
[ -f "$BASE/dashboard-metrics-template.html" ] && mv -v "$BASE/dashboard-metrics-template.html" "$HTML_DIR/templates/" || echo "  template not found"

# Move documentation
echo ""
echo "Moving documentation..."
for doc in SYSTEM-MAP-README INTEGRATION-REPORT QUICK-START FILES-CREATED INTERACTIVE_MAP_README PORTAL-ARCHITECTURE-VALIDATION PORTAL-FIXES-IMPLEMENTATION PORTAL-VALIDATION-SUMMARY COMPREHENSIVE-SYSTEM-MAP-COMPLETE MAP_VALIDATION_REPORT; do
    [ -f "$BASE/${doc}.md" ] && mv -v "$BASE/${doc}.md" "$HTML_DIR/docs/" || echo "  ${doc}.md not found"
done

# Create index/master file in html/ root
echo ""
echo "Creating html/index.html (master entry point)..."
cat > "$HTML_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude System Portal - Main Index</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 800px;
            width: 100%;
        }
        
        h1 {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            font-size: 2.5rem;
            margin-bottom: 10px;
        }
        
        .subtitle {
            color: #666;
            margin-bottom: 30px;
        }
        
        .portal-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        
        .portal-card {
            background: white;
            border: 2px solid #e2e8f0;
            border-radius: 12px;
            padding: 25px;
            text-align: center;
            transition: all 0.3s ease;
            cursor: pointer;
            text-decoration: none;
            color: inherit;
        }
        
        .portal-card:hover {
            border-color: #667eea;
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
        }
        
        .portal-icon {
            font-size: 3rem;
            margin-bottom: 15px;
        }
        
        .portal-title {
            font-size: 1.3rem;
            font-weight: 600;
            color: #667eea;
            margin-bottom: 10px;
        }
        
        .portal-desc {
            color: #666;
            font-size: 0.9rem;
            line-height: 1.5;
        }
        
        .portal-badge {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.75rem;
            margin-top: 10px;
        }
        
        .info-section {
            background: #f8f9fa;
            border-radius: 12px;
            padding: 20px;
            margin-top: 30px;
        }
        
        .info-section h2 {
            color: #667eea;
            font-size: 1.2rem;
            margin-bottom: 15px;
        }
        
        .info-list {
            list-style: none;
            padding: 0;
        }
        
        .info-list li {
            padding: 8px 0;
            color: #666;
        }
        
        .info-list li::before {
            content: "✓ ";
            color: #10b981;
            font-weight: bold;
            margin-right: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Claude System Portal</h1>
        <p class="subtitle">Choose your portal experience</p>
        
        <div class="portal-grid">
            <a href="portals/SYSTEM_MAP.html" class="portal-card">
                <div class="portal-icon">🗺️</div>
                <div class="portal-title">System Map</div>
                <div class="portal-desc">
                    Comprehensive interactive map with 98 agents, 34+ modules, D3.js graphs, and MSC diagrams
                </div>
                <div class="portal-badge">Recommended</div>
            </a>
            
            <a href="portals/index.html" class="portal-card">
                <div class="portal-icon">🏠</div>
                <div class="portal-title">Unified Portal</div>
                <div class="portal-desc">
                    Master dashboard with all features, real-time metrics, and integrated documentation
                </div>
                <div class="portal-badge">Full Featured</div>
            </a>
            
            <a href="portals/ai-enhanced-docs-browser.html" class="portal-card">
                <div class="portal-icon">🤖</div>
                <div class="portal-title">AI Docs Browser</div>
                <div class="portal-desc">
                    AI-powered documentation with intelligent search and dark mode
                </div>
                <div class="portal-badge">47 Docs</div>
            </a>
            
            <a href="portals/universal-docs-browser.html" class="portal-card">
                <div class="portal-icon">📚</div>
                <div class="portal-title">Simple Browser</div>
                <div class="portal-desc">
                    Lightweight documentation viewer for quick reference
                </div>
                <div class="portal-badge">Fast</div>
            </a>
        </div>
        
        <div class="info-section">
            <h2>📊 System Overview</h2>
            <ul class="info-list">
                <li>98 specialized agents cataloged and documented</li>
                <li>34+ module subsystems mapped with dependencies</li>
                <li>15+ MSC workflow sequences visualized</li>
                <li>Real-time performance metrics and dashboards</li>
                <li>D3.js interactive graphs and Mermaid diagrams</li>
                <li>Complete automation infrastructure</li>
                <li>Production-ready with 93% validation score</li>
            </ul>
        </div>
        
        <div style="text-align: center; margin-top: 30px; color: #999; font-size: 0.9rem;">
            <p>Claude Agent Framework v7.0 | Generated: October 2, 2025</p>
            <p>All portals optimized for desktop and mobile</p>
        </div>
    </div>
</body>
</html>
HTMLEOF

echo ""
echo "Creating README in html/ folder..."
cat > "$HTML_DIR/README.md" << 'MDEOF'
# HTML Portal System - Organized Structure

## 📁 Directory Structure

```
html/
├── index.html              # Main portal selector (start here)
├── portals/                # All interactive portals
│   ├── SYSTEM_MAP.html     # Comprehensive map (recommended)
│   ├── index.html          # Unified master portal
│   ├── ai-enhanced-docs-browser.html
│   ├── universal-docs-browser.html
│   ├── browser_test.html
│   └── portal-test-suite.html
├── data/                   # All JSON data files
│   ├── agents-data.json
│   ├── modules-data.json
│   ├── dependencies-graph.json
│   └── ... (10 total)
├── scripts/                # Automation scripts
│   ├── launch-map.sh
│   ├── merge-html-systems.py
│   ├── generate-portal-data.py
│   └── ... (12 total)
├── docs/                   # Complete documentation
│   ├── COMPREHENSIVE-SYSTEM-MAP-COMPLETE.md
│   ├── PORTAL-ARCHITECTURE-VALIDATION.md
│   └── ... (9 total)
├── templates/              # HTML templates
│   └── dashboard-metrics-template.html
├── modules/                # Existing module pages (10 pages)
├── css/                    # Stylesheets
│   └── base-framework.css
└── js/                     # JavaScript modules
    └── base-framework.js
```

## 🚀 Quick Start

### Open Main Portal Selector
```bash
cd /home/john/Downloads/claude-backups/
