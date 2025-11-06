# Crypto-POW Enhanced

Hardware-accelerated cryptographic proof-of-work system optimized for Intel Meteor Lake processors.

## Features

- **High Performance**: Optimized for AVX2, FMA, and AVX-VNNI instruction sets
- **Parallel Processing**: Multi-threaded POW solving using Rayon
- **Multiple Hash Algorithms**: SHA-256, SHA3-256, Blake3 (default)
- **Hardware Attestation**: Cryptographic attestation using hardware features
- **TPM Support**: Optional TPM 2.0 integration for hardware-backed security
- **SIMD Acceleration**: Hardware-accelerated hash computation

## Quick Start

### Build

```bash
cargo build --release
```

### Run Examples

```bash
# Basic usage example
cargo run --example basic_usage

# Run the CLI tool
cargo run --bin crypto-pow -- --help
```

### Run Tests

```bash
cargo test
```

## Usage

### As a Library

```rust
use crypto_pow_enhanced::{CryptoPowEngine, EngineConfig, HashAlgorithm};

// Create engine
let mut config = EngineConfig::default();
config.difficulty = 20;
config.hash_algorithm = HashAlgorithm::Blake3;
config.parallel = true;

let engine = CryptoPowEngine::new(config);

// Generate and solve challenge
let data = b"Hello, World!";
let challenge = engine.generate_challenge(data)?;
let solution = engine.solve(&challenge)?;

// Verify solution
assert!(engine.verify(&challenge, &solution)?);
```

### As a CLI Tool

```bash
# Solve a POW challenge
crypto-pow solve --data 48656c6c6f --difficulty 20 --parallel

# Verify a solution
crypto-pow verify --data 48656c6c6f --nonce 12345 --difficulty 20

# Generate hardware attestation
crypto-pow attest --data 48656c6c6f --output attestation.json

# Show hardware information
crypto-pow info

# Run benchmark
crypto-pow benchmark --difficulty 16 --iterations 10
```

## Features

### Default Features

- `parallel`: Enable parallel POW solving

### Optional Features

- `tpm`: Enable TPM 2.0 support
- `simd`: Enable SIMD optimizations
- `simulator`: Enable TPM simulator (for testing)
- `full`: Enable all features

### Build with Features

```bash
# Build with TPM support
cargo build --release --features tpm

# Build with all features
cargo build --release --features full
```

## Hardware Optimization

This library is optimized for Intel Meteor Lake processors with:

- AVX2 instruction set
- FMA (Fused Multiply-Add)
- AVX-VNNI (Vector Neural Network Instructions)
- AES-NI (hardware AES acceleration)

The library automatically detects available CPU features and enables optimizations accordingly.

## Benchmarks

Run benchmarks with:

```bash
cargo bench
```

Typical performance on Intel Core Ultra 7 165H (Meteor Lake):
- Blake3 hashing: ~2GB/s
- POW solving (difficulty 20): ~500K hashes/sec (single-threaded)
- POW solving (difficulty 20): ~5M hashes/sec (16 threads)

## Security

- All cryptographic operations use well-audited libraries (ed25519-dalek, blake3, sha2, sha3)
- Keys are automatically zeroized on drop
- Hardware attestation provides cryptographic binding to specific hardware
- Optional TPM integration for hardware-backed key storage

## License

Licensed under either of:

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.

## Contributing

Contributions are welcome! Please ensure all tests pass before submitting a PR:

```bash
cargo test --all-features
cargo clippy --all-features
cargo fmt --check
```
