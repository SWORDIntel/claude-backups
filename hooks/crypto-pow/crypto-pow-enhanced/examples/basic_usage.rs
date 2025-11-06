//! Basic usage example for Crypto-POW Enhanced

use anyhow::Result;
use crypto_pow_enhanced::{CryptoPowEngine, EngineConfig, HashAlgorithm};

fn main() -> Result<()> {
    println!("=== Crypto-POW Enhanced - Basic Usage ===\n");

    // Create engine with custom configuration
    let mut config = EngineConfig::default();
    config.difficulty = 16; // Lower difficulty for demo
    config.hash_algorithm = HashAlgorithm::Blake3;
    config.parallel = true;

    println!("Configuration:");
    println!("  Difficulty: {} bits", config.difficulty);
    println!("  Algorithm: {:?}", config.hash_algorithm);
    println!("  Parallel: {}", config.parallel);
    println!("  Threads: {}\n", config.threads);

    let engine = CryptoPowEngine::new(config);

    // Generate challenge
    let data = b"Hello, Crypto-POW!";
    let challenge = engine.generate_challenge(data)?;

    println!("Challenge generated:");
    println!("  Data: {:?}", String::from_utf8_lossy(&challenge.data));
    println!("  Difficulty: {}", challenge.difficulty);
    println!("  Timestamp: {}\n", challenge.timestamp);

    // Solve challenge
    println!("Solving challenge...");
    let solution = engine.solve(&challenge)?;

    println!("\n✅ Solution found!");
    println!("  Nonce: {}", solution.nonce);
    println!("  Hash: {}", hex::encode(&solution.hash));
    println!("  Timestamp: {}\n", solution.timestamp);

    // Verify solution
    let valid = engine.verify(&challenge, &solution)?;
    println!("Verification: {}", if valid { "✅ Valid" } else { "❌ Invalid" });

    Ok(())
}
