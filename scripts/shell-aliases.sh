#!/bin/bash
# Shell Aliases for Claude Framework v7.0
# Source this file in your ~/.bashrc or ~/.zshrc for convenience

# Quick validation and checks
alias claude-validate='~/claude-backups/scripts/quick-validate.sh'
alias claude-bench='~/claude-backups/scripts/quick-bench.sh'
alias claude-status='~/claude-backups/scripts/quick-validate.sh'

# Crypto-POW shortcuts
alias pow-info='crypto-pow info'
alias pow-solve='crypto-pow solve'
alias pow-verify='crypto-pow verify'
alias pow-bench='crypto-pow benchmark --difficulty 16 --iterations 5'

# Shadowgit shortcuts
alias sg='shadowgit'
alias sg-test='shadowgit 10'
alias sg-bench='shadowgit 100'

# Build shortcuts
alias build-crypto='cd ~/claude-backups/hooks/crypto-pow/crypto-pow-enhanced && cargo build --release && cd -'
alias build-shadowgit='cd ~/claude-backups/hooks/shadowgit && make && cd -'
alias build-all='build-crypto && build-shadowgit'

# Installer
alias claude-install='sudo ~/claude-backups/installer'
alias claude-install-quick='sudo ~/claude-backups/installer --quick'

# Navigation
alias cd-claude='cd ~/claude-backups'
alias cd-agents='cd ~/claude-backups/agents'
alias cd-hooks='cd ~/claude-backups/hooks'

# Git shortcuts for Claude development
alias claude-push='git push'
alias claude-status-git='git status'
alias claude-log='git log --oneline -10'

echo "Claude Framework v7.0 aliases loaded!"
echo "Run 'alias | grep claude' to see all aliases"
