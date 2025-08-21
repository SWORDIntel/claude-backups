# Claude-Portable Agent Framework v7.0

[![Version](https://img.shields.io/badge/version-7.0.0-blue.svg)](VERSION)
[![Status](https://img.shields.io/badge/status-production-green.svg)](CLAUDE.md)
[![Agents](https://img.shields.io/badge/agents-47-orange.svg)](agents/)
[![Performance](https://img.shields.io/badge/throughput-4.2M%20msg%2Fs-red.svg)](CLAUDE.md#performance-targets)
[![Database](https://img.shields.io/badge/PostgreSQL-17-336791.svg)](database/)

Hardware-aware multi-agent orchestration system with 47 specialized agents, optimized for Intel Meteor Lake architecture.

## Quick Start

```bash
# Clone and install
git clone https://github.com/SWORDIntel/claude-backups.git
cd claude-backups
./claude-installer.sh --full

# Use with orchestration
claude /task "create authentication system with tests and security review"
```

## Documentation

**[📚 CLAUDE.md](CLAUDE.md)** - Complete project documentation, technical reference, and Claude Code context

## Key Features

- **47 Specialized Agents**: From strategic planning to low-level optimization
- **Tandem Orchestration**: Dual-layer Python/C execution with 5 modes
- **Binary Protocol**: 4.2M msg/sec, 200ns P99 latency
- **PostgreSQL 17**: >2000 auth/sec, <25ms P95 latency
- **Hardware Aware**: Intel Meteor Lake optimized with AVX-512

## License

MIT License - See [LICENSE](LICENSE) for details