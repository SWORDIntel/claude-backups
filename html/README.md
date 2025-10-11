# Claude Agent Framework - HTML Documentation

**Purpose:** Interactive browser-based system map and documentation

---

## Quick Start

```bash
# Open interactive system map
firefox html/index.html

# Or use any browser
chromium html/index.html
```

---

## HTML Structure

```
html/
├── index.html              # Main interactive system map
├── README.md               # This file
├── css/                    # Stylesheets
├── js/                     # Interactive JavaScript
├── modules/                # Module-specific documentation
├── portals/                # Access portals
└── docs/                   # Additional documentation
```

---

## Key Files

### index.html
**Interactive System Map** with:
- Module visualization
- Dependency graphs
- Status indicators
- Quick navigation

**Features:**
- Click modules to see details
- View interconnections
- Check health status
- Access documentation

### modules/
Module-specific HTML documentation:
- Installation guides
- API documentation
- Configuration examples
- Troubleshooting

### portals/
Service access points:
- Database portal
- Learning API portal
- Monitoring dashboards
- Agent interfaces

---

## Usage

### View System Status
1. Open `html/index.html`
2. Check module colors:
   - 🟢 Green: Operational
   - 🟡 Yellow: Partial
   - 🔴 Red: Not running
3. Click module for details

### Access Services
- Database: http://localhost:5433
- Learning API: http://localhost:8080
- Agent Bridge: http://localhost:8081

---

## File Count

- HTML files: 12
- Total size: ~100KB
- Last updated: 2025-10-11

---

## Related Documentation

**Detailed docs:** `/home/john/claude-backups/docs/MODULES.md`
**Installation:** `/home/john/claude-backups/INSTALLER_VERIFICATION_REPORT.md`
**Logs:** `~/.local/share/claude/logs/installer.log`

---

**Note:** This is the simplified HTML documentation. For comprehensive markdown documentation, see `/docs/MODULES.md`
