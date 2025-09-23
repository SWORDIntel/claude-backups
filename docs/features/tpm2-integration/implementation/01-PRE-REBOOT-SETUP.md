# Pre-Reboot Setup Guide

**Phase**: Pre-Implementation  
**Duration**: 30 minutes  
**Required**: Before running `sudo usermod -a -G tss john`

## 🎯 Objectives

Prepare the system for TPM integration before the required reboot for group membership activation.

## ✅ Pre-Flight Checklist

### 1. System State Documentation

```bash
# Document current system state
date > ~/tpm-integration-start.log
echo "=== System Information ===" >> ~/tpm-integration-start.log
uname -a >> ~/tpm-integration-start.log
echo "=== Current Groups ===" >> ~/tpm-integration-start.log
groups >> ~/tpm-integration-start.log
echo "=== TPM Status ===" >> ~/tpm-integration-start.log
sudo tpm2_getcap properties-fixed 2>&1 >> ~/tpm-integration-start.log || echo "TPM not accessible yet" >> ~/tpm-integration-start.log
```

### 2. Save Current Work

```bash
# Commit all current changes
cd $HOME/claude-backups
git add -A
git commit -m "checkpoint: Pre-TPM integration - system state before reboot"
git push origin main

# Create backup branch
git checkout -b tpm-integration-backup
git push origin tpm-integration-backup
git checkout main
```

### 3. Prepare Integration Scripts

```bash
# Make scripts executable
cd $HOME/claude-backups/docs/features/tpm2-integration/scripts/
chmod +x probe_tpm_capabilities.sh
chmod +x tpm2_integration_demo.py

# Create post-reboot script
cat > ~/post-reboot-tpm-setup.sh << 'EOF'
#!/bin/bash
# Post-reboot TPM setup script

echo "=== Post-Reboot TPM Setup ==="
echo "Date: $(date)"

# Verify group membership
echo -e "\n1. Checking TPM group membership..."
if groups | grep -q tss; then
    echo "✓ User is in tss group"
else
    echo "✗ User NOT in tss group - reboot may be needed"
    exit 1
fi

# Test TPM access
echo -e "\n2. Testing TPM access..."
if tpm2_getcap properties-fixed > /dev/null 2>&1; then
    echo "✓ TPM accessible"
    tpm2_getcap properties-fixed | grep -E "TPM2_PT_MANUFACTURER|TPM2_PT_VENDOR_STRING"
else
    echo "✗ TPM not accessible"
    echo "   Try: newgrp tss"
fi

# Run capability probe
echo -e "\n3. Running capability probe..."
cd $HOME/claude-backups/docs/features/tpm2-integration/scripts/
./probe_tpm_capabilities.sh > ~/tpm-capabilities-post-reboot.log 2>&1
echo "✓ Capability probe complete (see ~/tpm-capabilities-post-reboot.log)"

# Test demo script
echo -e "\n4. Testing integration demo..."
python3 tpm2_integration_demo.py
echo "✓ Demo script tested"

echo -e "\n=== TPM Setup Complete ==="
echo "Next steps:"
echo "  1. Review ~/tpm-capabilities-post-reboot.log"
echo "  2. Run integration scripts in docs/features/tpm2-integration/"
echo "  3. Begin Phase 1 implementation"
EOF

chmod +x ~/post-reboot-tpm-setup.sh
```

### 4. Document Open Sessions

```bash
# List current sessions/processes to restore after reboot
cat > ~/pre-reboot-sessions.txt << EOF
Current Working Sessions:
- Claude-backups repository: $HOME/claude-backups
- TPM integration docs: docs/features/tpm2-integration/
- Important files:
  - Main integration guide: docs/features/tpm2-integration/README.md
  - Demo script: docs/features/tpm2-integration/scripts/tpm2_integration_demo.py
  - Probe script: docs/features/tpm2-integration/scripts/probe_tpm_capabilities.sh

Commands to run after reboot:
1. cd $HOME/claude-backups
2. ./post-reboot-tpm-setup.sh
3. Review logs in home directory
4. Continue with implementation
EOF
```

### 5. Backup Critical Files

```bash
# Create pre-integration backup
cd $HOME/claude-backups
tar -czf ~/claude-backups-pre-tpm-$(date +%Y%m%d-%H%M%S).tar.gz \
    --exclude=venv \
    --exclude=node_modules \
    --exclude=__pycache__ \
    --exclude=.git \
    .

echo "Backup created: ~/claude-backups-pre-tpm-*.tar.gz"
```

## 🔐 Add User to TPM Group

Now run the command that requires reboot:

```bash
# Add current user to TPM group
sudo usermod -a -G tss john

# Verify the command worked
grep tss /etc/group
# Expected output: tss:x:XXX:john
```

## 📝 Pre-Reboot Notes

### What Will Change
- User `john` will be added to `tss` group
- TPM device access will be enabled after reboot
- Group membership activates on next login

### What Won't Change
- All files remain in place
- Git repository state preserved
- No system configuration changes beyond group membership

## 🔄 Reboot Procedure

```bash
# Final sync and reboot
sync
sync
sync

# Choose your reboot method:
sudo reboot
# OR
sudo shutdown -r now
# OR
sudo systemctl reboot
```

## 📋 Post-Reboot Immediate Actions

After system restarts:

1. **Log in normally**
2. **Open terminal**
3. **Verify group membership**:
   ```bash
   groups
   # Should show: ... tss ...
   ```
4. **Run post-reboot script**:
   ```bash
   cd $HOME/claude-backups
   ~/post-reboot-tpm-setup.sh
   ```

## ⚠️ Troubleshooting

### If TPM Still Not Accessible After Reboot

```bash
# Option 1: Force group refresh
newgrp tss

# Option 2: Full logout/login
# Log out completely and log back in

# Option 3: Check TPM device
ls -la /dev/tpm*
# Should show: crw-rw---- 1 tss tss ... /dev/tpm0

# Option 4: Check group membership
id john
# Should show: groups=...XXX(tss)
```

### If Scripts Don't Run

```bash
# Ensure TPM tools installed
which tpm2_getcap
# If not found:
sudo apt-get update
sudo apt-get install tpm2-tools

# Check Python version
python3 --version
# Should be 3.8 or higher
```

## 📊 Success Criteria

Before proceeding to post-reboot configuration, verify:

- [ ] User added to `tss` group (check /etc/group)
- [ ] Backup created successfully
- [ ] Git repository committed and pushed
- [ ] Post-reboot script created and executable
- [ ] Documentation of current state complete

## 🔗 Next Steps

After successful reboot, continue with:
→ [Post-Reboot Configuration](02-POST-REBOOT-CONFIGURATION.md)

---

*Remember: The reboot is required for group membership to take effect. The TPM will not be accessible until after the reboot and re-login.*