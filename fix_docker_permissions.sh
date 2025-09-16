#!/bin/bash
# Docker Permission Fix Script
# Fixes Docker daemon permission denied errors

echo "🔧 Docker Permission Fix Script"
echo "================================"

# Check if user is in docker group
if groups $USER | grep -q docker; then
    echo "✅ User $USER is already in docker group"
else
    echo "❌ User $USER is NOT in docker group"
    echo ""
    echo "To fix Docker permissions, run the following commands:"
    echo ""
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"
    echo ""
    echo "Or logout and login again to apply group changes."
    echo ""
    echo "After fixing permissions, run this script again to verify."
    exit 1
fi

# Test Docker access
echo "Testing Docker access..."
if docker ps >/dev/null 2>&1; then
    echo "✅ Docker access working correctly"
else
    echo "❌ Docker access still not working"
    echo ""
    echo "If you just added yourself to the docker group, you may need to:"
    echo "  1. Logout and login again"
    echo "  2. Or run: newgrp docker"
    echo "  3. Or restart your terminal session"
    exit 1
fi

# Check Docker daemon status
echo "Checking Docker daemon status..."
if systemctl is-active --quiet docker; then
    echo "✅ Docker daemon is running"
else
    echo "❌ Docker daemon is not running"
    echo "Start Docker with: sudo systemctl start docker"
    exit 1
fi

echo ""
echo "🎉 Docker permissions are configured correctly!"
echo "You can now use Docker commands without sudo."