# Dell Enterprise Tools Directory Structure
## Ring -1 LiveCD Integration

### Primary Installation Location
```
/home/ubuntu/.local/share/claude/agents/build/dell-tools/
├── probe-dell-enterprise           # Main Dell hardware detection tool
├── dell-bios-analyzer              # BIOS/UEFI analysis tool  
├── dell-idrac-probe                # iDRAC discovery and analysis
├── dell-thermal-monitor            # Temperature and fan monitoring
├── dell-smbios-probe               # SMBIOS analysis tool
├── dell-redfish-client.py          # Python Redfish API client
├── dell-enterprise-suite           # Integrated launcher/menu system
├── venv/                          # Python virtual environment
│   ├── bin/
│   │   ├── python3
│   │   └── pip
│   └── lib/python3.*/site-packages/
│       ├── requests/
│       ├── urllib3/
│       └── yaml/
├── libsmbios/                     # Dell libsmbios source (if cloned)
├── iDRAC-Redfish-Scripting/       # Dell Redfish tools (if cloned)
└── docs/                          # Documentation and usage guides
    ├── dell-tools-usage.md
    ├── idrac-configuration.md
    └── troubleshooting.md
```

### System Integration Points
```
/usr/local/bin/                    # System-wide tool shortcuts
├── dell-enterprise-suite -> /home/ubuntu/.local/share/claude/agents/build/dell-tools/dell-enterprise-suite
├── probe-dell -> /home/ubuntu/.local/share/claude/agents/build/dell-tools/probe-dell-enterprise
└── dell-thermal -> /home/ubuntu/.local/share/claude/agents/build/dell-tools/dell-thermal-monitor

$HOME/.local/bin/                  # User-specific shortcuts
├── dell-suite -> ../share/claude/agents/build/dell-tools/dell-enterprise-suite
├── dell-probe -> ../share/claude/agents/build/dell-tools/probe-dell-enterprise
├── dell-bios -> ../share/claude/agents/build/dell-tools/dell-bios-analyzer
├── dell-idrac -> ../share/claude/agents/build/dell-tools/dell-idrac-probe
├── dell-thermal -> ../share/claude/agents/build/dell-tools/dell-thermal-monitor
└── dell-redfish -> ../share/claude/agents/build/dell-tools/dell-redfish-client.py

$HOME/.config/dell-tools/          # Configuration files
├── config.yaml                   # Main configuration
├── discovered-systems.json       # Auto-discovered Dell systems
├── thermal-profiles.yaml         # Thermal monitoring profiles
└── idrac-endpoints.json          # Known iDRAC endpoints

$HOME/.cache/dell-tools/           # Cache and temporary data
├── smbios-cache/                 # Cached SMBIOS data
├── thermal-logs/                 # Temperature monitoring logs
└── discovery-cache/              # Network discovery cache
```

### Desktop Integration (if GUI available)
```
$HOME/Desktop/                     # Desktop shortcuts
├── Dell-Enterprise-Suite.desktop # Main launcher
└── Dell-Hardware-Probe.desktop   # Quick hardware check

$HOME/.local/share/applications/   # Application menu entries
├── dell-enterprise-suite.desktop
├── dell-hardware-probe.desktop
└── dell-thermal-monitor.desktop

/usr/share/pixmaps/dell-tools/     # Icons (if GUI theme available)
├── dell-logo.png
├── dell-hardware.png
└── dell-thermal.png
```

### Log Files and Output
```
/var/log/dell-tools/              # System logs (if writable)
├── hardware-discovery.log
├── thermal-monitoring.log
└── idrac-connections.log

$HOME/.local/share/dell-tools/logs/ # User logs (fallback)
├── discovery-$(date +%Y%m%d).log
├── thermal-$(date +%Y%m%d).log
└── analysis-$(date +%Y%m%d).log
```

### Source Code Organization
```
$WORK_DIR/                        # Build-time sources
├── libsmbios/                    # Dell official SMBIOS library
│   ├── src/
│   ├── include/
│   └── configure
├── iDRAC-Redfish-Scripting/      # Dell Redfish scripts
│   ├── Redfish Python/
│   └── Redfish PowerShell/
├── minimal-smbios/               # Minimal SMBIOS implementation
│   └── smbios-probe.c
└── BIOSUtilities/                # BIOS analysis tools (optional)
```

### Ring -1 LiveCD Specific Layout
```
/opt/dell-tools/                  # Alternative system location
├── bin/                          # All executable tools
├── lib/                          # Shared libraries
├── share/                        # Documentation and data
│   ├── docs/
│   ├── examples/
│   └── templates/
└── etc/                          # Configuration templates
```

### PATH Integration
The installer adds Dell tools to the system PATH via:
1. `$HOME/.local/bin` (primary)
2. `/usr/local/bin` (system-wide symlinks if available)
3. `/opt/dell-tools/bin` (alternative location)

### Tool Access Methods

#### 1. Direct Command Execution
```bash
# Individual tools
probe-dell-enterprise
dell-bios-analyzer
dell-thermal-monitor
dell-idrac-probe

# Integrated launcher
dell-enterprise-suite
```

#### 2. Via Claude Code Agent System
```bash
# Through agent framework
claude "Analyze Dell hardware on this system"
claude "Monitor Dell thermal status"
claude "Discover iDRAC interfaces"
```

#### 3. Menu-Driven Interface
```bash
# Interactive menu system
dell-enterprise-suite
# Presents numbered menu with all available tools
```

#### 4. Automated/Scripted Usage
```bash
# Return codes for scripting
probe-dell-enterprise && echo "Dell system detected"
dell-thermal-monitor | grep -q "CRITICAL" && alert-admin
```

### Configuration Management

#### Main Configuration File: `$HOME/.config/dell-tools/config.yaml`
```yaml
# Dell Enterprise Tools Configuration
system:
  auto_discover: true
  cache_results: true
  log_level: "INFO"
  
thermal:
  check_interval: 30
  warning_threshold: 75
  critical_threshold: 85
  log_temperature: true
  
idrac:
  common_ips:
    - "192.168.1.120"
    - "192.168.0.120"
    - "10.0.0.120"
  discovery_timeout: 2
  default_username: "root"
  # Note: passwords should not be stored in config
  
redfish:
  verify_ssl: false
  timeout: 30
  max_retries: 3
  
paths:
  tools_dir: "$HOME/.local/share/claude/agents/build/dell-tools"
  cache_dir: "$HOME/.cache/dell-tools"
  log_dir: "$HOME/.local/share/dell-tools/logs"
```

This structure ensures:
1. **Isolation**: Dell tools are contained within the Claude agent system
2. **Integration**: Tools work with existing Claude Code framework
3. **Flexibility**: Multiple access methods for different use cases
4. **Maintainability**: Clear organization for updates and troubleshooting
5. **Compatibility**: Works in LiveCD environment with user-space installation