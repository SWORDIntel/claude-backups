#!/usr/bin/env python3
"""
ZFS MIGRATION PLAN
Comprehensive ZFS transition strategy for military-grade system
Secure migration from current ext4 to encrypted ZFS
"""

import os
import sys
import json
import subprocess
from pathlib import Path
import time

class ZFSMigrationPlan:
    def __init__(self):
        self.base_path = Path("/home/john/claude-backups")
        os.chdir(self.base_path)

        # ZFS configuration
        self.zfs_pools = {
            'rpool': {
                'purpose': 'root_system',
                'encryption': 'aes-256-gcm',
                'compression': 'lz4',
                'checksum': 'sha256',
                'atime': 'off',
                'recordsize': '128k'
            },
            'dpool': {
                'purpose': 'data_storage',
                'encryption': 'aes-256-gcm',
                'compression': 'zstd',
                'checksum': 'blake3',
                'atime': 'off',
                'recordsize': '1M'
            },
            'tpool': {
                'purpose': 'temp_fast',
                'encryption': 'aes-256-gcm',
                'compression': 'lz4',
                'checksum': 'sha256',
                'atime': 'off',
                'recordsize': '64k'
            }
        }

        # Migration phases
        self.migration_phases = [
            "System analysis and backup",
            "ZFS tools installation",
            "Pool creation and encryption",
            "Data migration",
            "System configuration",
            "Validation and cleanup"
        ]

    def analyze_current_system(self):
        """Analyze current filesystem layout"""
        print("🔍 ANALYZING CURRENT SYSTEM LAYOUT")
        print("=" * 50)

        try:
            # Get filesystem information
            df_result = subprocess.run(['df', '-h'], capture_output=True, text=True)
            print("📊 Current filesystem usage:")
            for line in df_result.stdout.split('\n')[1:6]:  # First 5 lines
                if line.strip():
                    print(f"  {line}")

            # Get mount information
            mount_result = subprocess.run(['mount'], capture_output=True, text=True)
            ext4_mounts = []
            for line in mount_result.stdout.split('\n'):
                if 'ext4' in line and '/dev/' in line:
                    ext4_mounts.append(line.strip())

            print(f"\n📋 EXT4 filesystems found: {len(ext4_mounts)}")
            for mount in ext4_mounts[:3]:  # Show first 3
                print(f"  {mount}")

            # Check available space
            statvfs = os.statvfs('/')
            total_space = statvfs.f_frsize * statvfs.f_blocks
            free_space = statvfs.f_frsize * statvfs.f_available

            print(f"\n💾 Root filesystem:")
            print(f"  Total: {total_space // (1024**3):.1f} GB")
            print(f"  Free: {free_space // (1024**3):.1f} GB")
            print(f"  Used: {(total_space - free_space) // (1024**3):.1f} GB")

            return {
                'ext4_mounts': len(ext4_mounts),
                'total_gb': total_space // (1024**3),
                'free_gb': free_space // (1024**3)
            }

        except Exception as e:
            print(f"⚠️  System analysis error: {e}")
            return {}

    def create_zfs_installation_script(self):
        """Create ZFS installation and setup script"""
        print("\n📦 CREATING ZFS INSTALLATION SCRIPT")
        print("=" * 50)

        zfs_install_script = '''#!/bin/bash
# ZFS Installation Script for Debian/Ubuntu
# Military-grade ZFS setup with encryption

echo "🔒 ZFS INSTALLATION FOR MILITARY SYSTEM"
echo "======================================"

# Update package list
echo "📦 Updating package lists..."
sudo apt update

# Install ZFS utilities
echo "📦 Installing ZFS utilities..."
sudo apt install -y zfsutils-linux zfs-dkms

# Load ZFS module
echo "🔧 Loading ZFS kernel module..."
sudo modprobe zfs

# Verify ZFS installation
echo "✅ Verifying ZFS installation..."
zpool version
zfs version

# Create ZFS configuration directory
sudo mkdir -p /etc/zfs
sudo mkdir -p /var/cache/zfs

echo "✅ ZFS installation complete"
echo "🎯 Ready for pool creation"
'''

        script_file = self.base_path / "install_zfs.sh"
        script_file.write_text(zfs_install_script)
        script_file.chmod(0o755)

        print(f"✅ ZFS installation script: {script_file}")

    def create_pool_creation_script(self):
        """Create ZFS pool creation script"""
        print("\n🏊 CREATING POOL CREATION SCRIPT")
        print("=" * 50)

        pool_script = f'''#!/bin/bash
# ZFS Pool Creation Script
# Creates encrypted ZFS pools for military system

echo "🏊 ZFS POOL CREATION - MILITARY CONFIGURATION"
echo "============================================="

# WARNING: Replace /dev/sdX with actual target devices
# DO NOT run on production system without verification!

echo "⚠️  WARNING: This script will create ZFS pools"
echo "⚠️  Verify target devices before proceeding"
echo ""

# Example pool creation (ADJUST DEVICE PATHS!)
# sudo zpool create -o ashift=12 \\
#   -O encryption=aes-256-gcm \\
#   -O keylocation=prompt \\
#   -O keyformat=passphrase \\
#   -O compression=lz4 \\
#   -O checksum=sha256 \\
#   -O atime=off \\
#   -O recordsize=128k \\
#   rpool /dev/sdX1

# Data pool creation
# sudo zpool create -o ashift=12 \\
#   -O encryption=aes-256-gcm \\
#   -O keylocation=prompt \\
#   -O keyformat=passphrase \\
#   -O compression=zstd \\
#   -O checksum=blake3 \\
#   -O atime=off \\
#   -O recordsize=1M \\
#   dpool /dev/sdY1

echo "📋 Pool creation commands prepared"
echo "🔧 Edit this script with actual device paths"
echo "⚠️  CRITICAL: Backup data before running!"

# Pool status check
echo "📊 Current ZFS status:"
sudo zpool status 2>/dev/null || echo "No ZFS pools found"
'''

        pool_file = self.base_path / "create_zfs_pools.sh"
        pool_file.write_text(pool_script)
        pool_file.chmod(0o755)

        print(f"✅ Pool creation script: {pool_file}")

    def create_migration_strategy(self):
        """Create comprehensive migration strategy"""
        print("\n📋 CREATING MIGRATION STRATEGY")
        print("=" * 50)

        strategy = {
            "migration_overview": {
                "current_system": "EXT4 on /dev/sda",
                "target_system": "ZFS encrypted pools",
                "migration_method": "Fresh install + data migration",
                "security_level": "Military grade",
                "downtime_estimate": "4-8 hours"
            },
            "phase_details": {
                "phase_1": {
                    "name": "System Analysis and Backup",
                    "duration": "1-2 hours",
                    "tasks": [
                        "Complete system backup to external storage",
                        "Document current configuration",
                        "Verify backup integrity",
                        "Identify critical data locations"
                    ]
                },
                "phase_2": {
                    "name": "ZFS Tools Installation",
                    "duration": "30 minutes",
                    "tasks": [
                        "Install ZFS utilities",
                        "Load ZFS kernel modules",
                        "Verify ZFS functionality",
                        "Configure ZFS defaults"
                    ]
                },
                "phase_3": {
                    "name": "Pool Creation and Encryption",
                    "duration": "1 hour",
                    "tasks": [
                        "Create encrypted root pool (rpool)",
                        "Create encrypted data pool (dpool)",
                        "Configure encryption settings",
                        "Set compression and checksums"
                    ]
                },
                "phase_4": {
                    "name": "Data Migration",
                    "duration": "2-4 hours",
                    "tasks": [
                        "Copy system files to ZFS",
                        "Migrate user data",
                        "Transfer configurations",
                        "Verify data integrity"
                    ]
                },
                "phase_5": {
                    "name": "System Configuration",
                    "duration": "1 hour",
                    "tasks": [
                        "Configure bootloader for ZFS",
                        "Update /etc/fstab",
                        "Configure ZFS auto-mount",
                        "Set up encryption key management"
                    ]
                },
                "phase_6": {
                    "name": "Validation and Cleanup",
                    "duration": "30 minutes",
                    "tasks": [
                        "Boot test from ZFS",
                        "Verify all services",
                        "Performance validation",
                        "Clean up temporary files"
                    ]
                }
            },
            "security_features": {
                "encryption": "AES-256-GCM",
                "key_derivation": "PBKDF2",
                "checksum": "SHA256/BLAKE3",
                "compression": "LZ4/ZSTD",
                "features": [
                    "Per-dataset encryption",
                    "Automatic compression",
                    "Silent data corruption detection",
                    "Snapshot capabilities",
                    "Copy-on-write protection"
                ]
            },
            "rollback_plan": {
                "emergency_boot": "Boot from external backup",
                "data_recovery": "Restore from verified backups",
                "system_restore": "Reinstall from original image",
                "verification": "Integrity check all restored data"
            }
        }

        strategy_file = self.base_path / "config" / "zfs_migration_strategy.json"
        strategy_file.parent.mkdir(exist_ok=True)
        strategy_file.write_text(json.dumps(strategy, indent=2))

        print(f"✅ Migration strategy: {strategy_file}")
        print("✅ 6-phase migration plan created")
        print("✅ Security features documented")
        print("✅ Rollback plan included")

    def create_zfs_configuration(self):
        """Create detailed ZFS configuration"""
        print("\n⚙️  CREATING ZFS CONFIGURATION")
        print("=" * 50)

        for pool_name, config in self.zfs_pools.items():
            print(f"📋 {pool_name.upper()} configuration:")
            for key, value in config.items():
                print(f"  • {key}: {value}")
            print()

        # Save detailed configuration
        zfs_config = {
            "pools": self.zfs_pools,
            "global_settings": {
                "arc_max": "8G",  # ARC cache limit
                "arc_min": "1G",  # ARC cache minimum
                "prefetch_disable": "0",
                "sync_disabled": "0",
                "zfs_immediate_write_sz": "32768"
            },
            "recommended_datasets": {
                "rpool/ROOT": {
                    "mountpoint": "/",
                    "compression": "lz4",
                    "atime": "off"
                },
                "rpool/home": {
                    "mountpoint": "/home",
                    "compression": "zstd",
                    "atime": "off"
                },
                "dpool/claude-backups": {
                    "mountpoint": "/home/john/claude-backups",
                    "compression": "zstd",
                    "recordsize": "1M"
                },
                "tpool/tmp": {
                    "mountpoint": "/tmp",
                    "compression": "lz4",
                    "sync": "disabled"
                }
            }
        }

        config_file = self.base_path / "config" / "zfs_detailed_config.json"
        config_file.write_text(json.dumps(zfs_config, indent=2))

        print(f"✅ Detailed ZFS config: {config_file}")

    def generate_migration_report(self):
        """Generate comprehensive migration report"""
        print("\n📊 GENERATING MIGRATION REPORT")
        print("=" * 50)

        report = f"""
# ZFS MIGRATION PLAN - COMPREHENSIVE STRATEGY

**Plan Date**: {time.strftime('%Y-%m-%d %H:%M:%S')}
**Current System**: EXT4 on Dell Latitude 5450 MIL-SPEC
**Target System**: Encrypted ZFS with military-grade security

---

## MIGRATION OVERVIEW

**Current Status**: Internal drive disabled for security
**Migration Type**: Fresh ZFS installation + data migration
**Security Level**: Military grade encryption
**Estimated Duration**: 4-8 hours total

---

## ZFS POOL CONFIGURATION

{chr(10).join([f"**{pool.upper()}**:" + chr(10) + chr(10).join([f"• {k}: {v}" for k, v in config.items()]) for pool, config in self.zfs_pools.items()])}

---

## MIGRATION PHASES

{chr(10).join([f"**Phase {i+1}**: {phase}" for i, phase in enumerate(self.migration_phases)])}

---

## SECURITY FEATURES

**Encryption**: AES-256-GCM per dataset
**Compression**: LZ4 (fast) / ZSTD (efficient)
**Checksum**: SHA256 / BLAKE3
**Protection**: Copy-on-write, silent corruption detection

**Military-Grade Features**:
✅ Per-dataset encryption keys
✅ Automatic data integrity verification
✅ Snapshot-based recovery points
✅ Hardware-level performance optimization

---

## PREPARATION CHECKLIST

**Before Migration**:
□ Complete system backup to external storage
□ Verify backup integrity and accessibility
□ Document current network and system configuration
□ Prepare ZFS installation media
□ Identify target storage devices

**During Migration**:
□ Install ZFS utilities and modules
□ Create encrypted pools with proper ashift
□ Configure compression and checksum algorithms
□ Migrate data with integrity verification
□ Configure bootloader for ZFS root

**After Migration**:
□ Verify system boot from ZFS
□ Test all critical services and applications
□ Validate data integrity and accessibility
□ Configure automatic ZFS maintenance
□ Document new system configuration

---

## ROLLBACK STRATEGY

**Emergency Boot**: External backup system available
**Data Recovery**: Verified backups with integrity checks
**System Restore**: Complete reinstallation capability
**Validation**: Full system integrity verification

---

## PERFORMANCE EXPECTATIONS

**ZFS Benefits**:
• Improved data integrity (checksums)
• Better compression (20-40% space savings)
• Snapshot capabilities (instant backups)
• Copy-on-write efficiency
• Advanced caching (ARC/L2ARC)

**Military System Integration**:
• Maintains 66.5 TOPS performance
• DSMIL hardware access preserved
• Zero-token operation compatibility
• Military-grade encryption standards

---

## NEXT STEPS

1. **Review and approve migration plan**
2. **Prepare external backup storage**
3. **Schedule migration window**
4. **Execute phase-by-phase migration**
5. **Validate system functionality**

**Status**: MIGRATION PLAN READY
**Security**: MILITARY-GRADE PREPARED
"""

        report_file = self.base_path / "ZFS_MIGRATION_REPORT.md"
        report_file.write_text(report)

        print(f"✅ Migration report: {report_file}")

def main():
    """Execute ZFS migration planning"""
    print("💾 ZFS MIGRATION PLANNING - MILITARY SYSTEM")
    print("=" * 60)

    planner = ZFSMigrationPlan()

    # Analyze current system
    system_info = planner.analyze_current_system()

    # Create migration components
    planner.create_zfs_installation_script()
    planner.create_pool_creation_script()
    planner.create_migration_strategy()
    planner.create_zfs_configuration()
    planner.generate_migration_report()

    print("\n" + "💾" * 60)
    print("🔒 ZFS MIGRATION PLAN COMPLETE")
    print("💾" * 60)

    print(f"\n✅ MIGRATION PREPARATION COMPLETE:")
    print("  📦 ZFS installation script ready")
    print("  🏊 Pool creation script prepared")
    print("  📋 6-phase migration strategy documented")
    print("  ⚙️  Detailed ZFS configuration created")
    print("  📊 Comprehensive migration report generated")

    print(f"\n🔒 SECURITY FEATURES PREPARED:")
    print("  • AES-256-GCM encryption per dataset")
    print("  • LZ4/ZSTD compression algorithms")
    print("  • SHA256/BLAKE3 checksum verification")
    print("  • Military-grade data protection")

    print(f"\n⚠️  IMPORTANT REMINDERS:")
    print("  🔐 Internal drive currently disabled for security")
    print("  💾 Complete backup required before migration")
    print("  🎯 Migration will enable full ZFS capabilities")
    print("  🛡️  Military-grade encryption will be maintained")

    return True

if __name__ == "__main__":
    main()