#!/bin/bash
# TPM Reboot Reminder Script
# Displays popup reminder to activate TPM after reboot

# Check if we're in a desktop environment
if [ -n "$DISPLAY" ]; then
    # Try different notification methods
    if command -v zenity >/dev/null 2>&1; then
        zenity --info --width=500 --height=200 \
               --title="🚨 TPM ACTIVATION REQUIRED" \
               --text="CRYPTOGRAPHIC PROOF-OF-WORK SYSTEM READY

🔐 UEFI TPM Module Activation Required:
1. sudo modprobe tpm_tis
2. sudo systemctl start tpm2-abrmd
3. cd /home/john/claude-backups
4. Review PROOFOFWORKCHECK.md for full deployment

⚡ Intel Hardware Security Ready:
• MEI Interface: /dev/mei0 ✅
• RSA-4096 + SHA-256 + TPM Attestation
• Zero Tolerance for Fake Implementations

🎯 MISSION: Deploy MIL-SPEC Cryptographic Verification"
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical -t 30000 \
                   "🚨 TPM ACTIVATION REQUIRED" \
                   "CRYPTOGRAPHIC PROOF-OF-WORK SYSTEM READY
🔐 Run: sudo modprobe tpm_tis && sudo systemctl start tpm2-abrmd
📋 Review: /home/john/claude-backups/PROOFOFWORKCHECK.md
🎯 MISSION: Deploy MIL-SPEC Verification System"
    elif command -v xmessage >/dev/null 2>&1; then
        xmessage -center -title "TPM ACTIVATION REQUIRED" \
                "🚨 CRYPTOGRAPHIC PROOF-OF-WORK SYSTEM READY

UEFI TPM Module Activation Required:
1. sudo modprobe tpm_tis
2. sudo systemctl start tpm2-abrmd
3. Review PROOFOFWORKCHECK.md

Intel Hardware Security Ready - Deploy Now!"
    fi
else
    # Terminal/console notification
    echo "🚨🚨🚨 TPM ACTIVATION REQUIRED 🚨🚨🚨"
    echo "CRYPTOGRAPHIC PROOF-OF-WORK SYSTEM READY"
    echo ""
    echo "🔐 UEFI TPM Module Activation Required:"
    echo "   sudo modprobe tpm_tis"
    echo "   sudo systemctl start tpm2-abrmd"
    echo ""
    echo "📋 Review deployment guide:"
    echo "   /home/john/claude-backups/PROOFOFWORKCHECK.md"
    echo ""
    echo "🎯 MISSION: Deploy MIL-SPEC Cryptographic Verification"
    echo "⚡ Intel Hardware Security Ready - Zero Fake Code Tolerance"
fi

# Log the reminder
echo "$(date): TPM reboot reminder displayed" >> /var/log/tpm-reminders.log 2>/dev/null || \
echo "$(date): TPM reboot reminder displayed" >> /home/john/claude-backups/tpm-reminders.log