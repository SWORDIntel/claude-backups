# Claude Enhanced Installer - Automatic Environment Detection

## 🧪 **Smart Environment Detection System**

The enhanced Python installer now automatically detects your environment type and adapts the installation accordingly.

## 🖥️ **Supported Environments**

### **Headless Server** 🖥️
- **Detection**: No display server, SSH connection, Docker container, cloud platform indicators
- **Adaptations**:
  - Forces full installation mode (ensures all server components)
  - Installs Docker + database system
  - Includes server-specific packages: `docker.io`, `docker-compose`, `postgresql-client`
  - Optimizes for headless operation

### **KDE Plasma** 🎨
- **Detection**: `plasmashell`, `kwin` processes, KDE environment variables
- **Adaptations**:
  - GUI optimization mode
  - KDE-specific packages: `kde-baseapps`, `konsole`
  - Desktop integration features

### **GNOME Desktop** 🐧
- **Detection**: `gnome-shell`, `gnome-session` processes, GNOME environment variables
- **Adaptations**:
  - GNOME-specific packages: `gnome-terminal`, `nautilus`
  - GNOME desktop integration

### **XFCE Desktop** 🖱️
- **Detection**: `xfce4-session`, `xfwm4` processes, XFCE environment variables
- **Adaptations**:
  - XFCE-specific packages: `xfce4-terminal`, `thunar`
  - Lightweight desktop optimization

### **Wayland** 🌊
- **Detection**: `WAYLAND_DISPLAY` environment variable
- **Adaptations**:
  - Wayland-specific display server support
  - Modern graphics stack optimization

### **X11** 🪟
- **Detection**: `DISPLAY` environment variable, X11 processes
- **Adaptations**:
  - X11 display server configuration
  - Traditional graphics support

## 🔍 **Detection Methods**

### **Environment Variables Checked:**
- `DISPLAY` - X11 display server
- `WAYLAND_DISPLAY` - Wayland display server
- `XDG_SESSION_TYPE` - Session type (wayland/x11)
- `DESKTOP_SESSION` - Desktop session name
- `XDG_CURRENT_DESKTOP` - Current desktop environment
- `SSH_CLIENT` / `SSH_TTY` - SSH connection indicators

### **Process Detection:**
- **KDE**: `plasmashell`, `kwin`, `kdeconnectd`
- **GNOME**: `gnome-shell`, `gnome-session`, `gsd-power`
- **XFCE**: `xfce4-session`, `xfwm4`, `xfce4-panel`

### **Headless Indicators:**
- Docker container: `/.dockerenv` file
- SSH connection: `SSH_CLIENT` or `SSH_TTY` environment variables
- Cloud platforms: DMI system vendor detection (AWS, Google, Azure, etc.)
- Graphics drivers: Absence of GPU kernel modules

## 🚀 **Automatic Adaptations**

### **Installation Mode Adaptation:**
```
Quick Mode → Headless Server → Full Mode (automatic upgrade)
Full Mode → Any Environment → Full Mode (no change)
```

### **Package Selection:**
- **Headless**: `docker.io`, `docker-compose`, `postgresql-client`, `python3-venv`
- **Desktop**: `python3-venv`, desktop-specific terminals and file managers
- **Universal**: `git`, `curl`, `wget`, `python3-full`

### **Feature Configuration:**
- **Headless**: Docker database, learning system, agent bridge
- **Desktop**: GUI optimizations, desktop integration, display server support

## 🧪 **Testing Environment Detection**

### **Simple Test:**
```bash
python3 test-environment-simple.py
```

### **Comprehensive Test:**
```bash
python3 test-environment-detection.py
```

### **Installer Detection Mode:**
```bash
python3 claude-enhanced-installer.py --detect-only
```

## 📋 **Example Output**

### **Current System (KDE Wayland):**
```
Environment: 🌊 Wayland (wayland) [plasma]
🪟 Display server detected (wayland) - configuring graphics support
```

### **Headless Server:**
```
Environment: 🖥️ Headless Server
🖥️ Headless environment detected - optimizing for server deployment
📦 Upgrading to full installation for headless server optimization
```

### **GNOME Desktop:**
```
Environment: 🐧 GNOME Desktop (x11) [gnome]
🎨 Desktop environment detected (GNOME) - enabling GUI optimizations
```

## ⚙️ **Manual Override**

Environment detection is automatic, but you can still control installation mode:

```bash
# Force full mode regardless of environment
python3 claude-enhanced-installer.py --mode=full

# Force quick mode (may be upgraded for headless)
python3 claude-enhanced-installer.py --mode=quick

# Custom mode with manual selection
python3 claude-enhanced-installer.py --mode=custom
```

## 🎯 **Benefits**

- **Zero Configuration**: Automatically detects and adapts to your environment
- **Optimal Setup**: Each environment gets the most appropriate installation
- **Server Optimization**: Headless systems get full server stack automatically
- **Desktop Integration**: GUI environments get desktop-specific enhancements
- **Fallback Safety**: Unknown environments get safe default configuration

## 🔧 **Technical Implementation**

- **Comprehensive Detection**: Multiple detection methods for reliability
- **Graceful Fallback**: Unknown environments default to safe configuration
- **Performance Optimized**: Fast detection with minimal system impact
- **Cross-Platform**: Works on all Linux distributions and environments

The installer now intelligently adapts to your specific environment for the optimal Claude Code installation experience.