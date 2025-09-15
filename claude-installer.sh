#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# DEPRECATED: Claude Installer v10.0
# This installer has been deprecated in favor of the Python-based installer
# ═══════════════════════════════════════════════════════════════════════════

print_red() { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_yellow() { printf "\033[1;33m%s\033[0m\n" "$1"; }
print_cyan() { printf "\033[0;36m%s\033[0m\n" "$1"; }
print_bold() { printf "\033[1m%s\033[0m\n" "$1"; }

echo
print_bold "═══════════════════════════════════════════════════════════════════════════"
print_red "⚠️  DEPRECATED INSTALLER WARNING"
print_bold "═══════════════════════════════════════════════════════════════════════════"
echo
print_red "This shell-based installer (claude-installer.sh) has been DEPRECATED"
print_yellow "due to complexity issues and shell compatibility problems."
echo
print_cyan "Please use the new Python-based installer instead:"
echo
print_bold "  Quick Installation:"
print_cyan "    ./install"
echo
print_bold "  Advanced Installation:"
print_cyan "    ./claude-python-installer.sh"
echo
print_bold "  Migration from old installer:"
print_cyan "    ./upgrade-to-python-installer.py"
echo
print_yellow "The new installer provides:"
print_cyan "  • Better error handling and recovery"
print_cyan "  • Cross-platform compatibility (Linux, macOS, WSL)"
print_cyan "  • Shell-specific optimizations (bash, zsh, fish)"
print_cyan "  • Recursion-proof wrapper generation"
print_cyan "  • Advanced validation and testing"
echo
print_bold "═══════════════════════════════════════════════════════════════════════════"
echo

# Ask if user wants to proceed with deprecated installer
read -p "Do you still want to use the deprecated installer? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_cyan "Launching new Python installer..."
    exec "$(dirname "$0")/claude-python-installer.sh" "$@"
fi

print_yellow "Proceeding with deprecated installer..."
echo "You can find the original installer at: installers/deprecated/claude-installer-v10.0-deprecated.sh"
exec "$(dirname "$0")/installers/deprecated/claude-installer-v10.0-deprecated.sh" "$@"