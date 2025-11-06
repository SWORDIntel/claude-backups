# Claude Framework v7.0 - Quick Start Guide

## 🚀 Installation

```bash
# Run the installer (installs all modules automatically)
sudo ./installer

# Or quick install
sudo ./installer --quick

# Reload your shell
source ~/.bashrc  # or ~/.zshrc
```

## ✅ Validation

```bash
# Quick system validation
./scripts/quick-validate.sh

# Run benchmarks
./scripts/quick-bench.sh

# Setup binary symlinks
./scripts/setup-binaries.sh
```

## 🔧 Available Commands

### Crypto-POW
```bash
crypto-pow info                    # Show hardware capabilities
crypto-pow solve --data HEX --difficulty 20
crypto-pow verify --data HEX --nonce N --difficulty 20
crypto-pow attest --data HEX --output file.json
crypto-pow benchmark --difficulty 16 --iterations 10
```

### Shadowgit
```bash
shadowgit 10                       # Process 10 tasks
shadowgit 100                      # Benchmark with 100 tasks
```

### Claude
```bash
claude --version                   # Check version
claude --help                      # Get help
```

## 🎯 Quick Wins - Shell Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
source ~/claude-backups/scripts/shell-aliases.sh
```

Then you get:
- `claude-validate` - Quick system check
- `claude-bench` - Performance benchmark
- `pow-info` - Hardware info
- `sg-test` - Test shadowgit
- `build-crypto` - Rebuild Crypto-POW
- `build-shadowgit` - Rebuild Shadowgit
- `cd-claude` - Jump to project root
- And many more! (run `alias | grep claude`)

## 📊 Performance Expectations

### Crypto-POW (Rust)
- Blake3 hashing: ~2 GB/s
- POW solving (16 threads): ~5M hashes/sec
- Single-threaded: ~500K hashes/sec

### Shadowgit (C/AVX-512)
- Line processing: ~2M lines/sec
- Target: 3.5B lines/sec (full optimization)

## 🏗️ Building from Source

### Crypto-POW
```bash
cd hooks/crypto-pow/crypto-pow-enhanced
cargo build --release
# Binary: target/release/crypto-pow
```

### Shadowgit
```bash
cd hooks/shadowgit
make                  # Standard build
make avx512           # AVX-512 optimized
make performance      # Maximum optimization
# Binaries: shadowgit_phase3_test, shadowgit_phase3_integration.so
```

## 🔍 Troubleshooting

### Module not installing?
```bash
# Check Python dependencies
pip3 install --user asyncpg cryptography pycryptodome

# Check for PEP 668 issues
pip3 install --user --break-system-packages PACKAGE
```

### Claude command not found?
```bash
# Ensure PATH includes ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

# Check if npm global bin is in PATH
echo $PATH | grep npm-global
```

### Rust not installed?
```bash
# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

## 📁 Key Directories

```
claude-backups/
├── installer                  # Main installer script
├── scripts/
│   ├── quick-validate.sh      # System validation
│   ├── quick-bench.sh         # Performance benchmark
│   ├── setup-binaries.sh      # Make binaries accessible
│   └── shell-aliases.sh       # Convenience aliases
├── hooks/
│   ├── crypto-pow/           # Rust POW acceleration
│   └── shadowgit/            # C AVX-512 acceleration
├── agents/                    # 98 specialized agents
└── installers/               # Installation scripts
```

## 🎓 Module Status

| Module | Language | Status | Performance |
|--------|----------|--------|-------------|
| Crypto-POW | Rust | ✅ Working | 5M hash/s |
| Shadowgit | C | ✅ Working | 2M lines/s |
| Installer | Bash/Python | ✅ Working | N/A |
| Agents | Python | ✅ Working | 98 agents |

## 🚦 Getting Help

```bash
# Installer help
./installer --help

# Module-specific help
crypto-pow --help
make help           # In shadowgit directory

# System diagnostics
./scripts/quick-validate.sh
```

## 🔗 Integration

The installer automatically:
1. ✅ Installs Rust toolchain
2. ✅ Compiles Crypto-POW acceleration
3. ✅ Compiles Shadowgit C engine
4. ✅ Installs Python dependencies
5. ✅ Creates claude wrapper script
6. ✅ Updates shell configuration

All modules work together seamlessly!

---

**Version**: 7.0.0
**Last Updated**: 2025-11-06
**Hardware**: Intel Meteor Lake optimized (AVX2/AVX-512/NPU)
