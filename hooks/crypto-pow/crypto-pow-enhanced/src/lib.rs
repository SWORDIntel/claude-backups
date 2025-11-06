//! Crypto-POW Enhanced - Hardware-Accelerated Cryptographic Proof-of-Work
//!
//! High-performance cryptographic proof-of-work system optimized for Intel Meteor Lake
//! with AVX2, FMA, and AVX-VNNI support.

#![cfg_attr(docsrs, feature(doc_cfg))]

use anyhow::{Context, Result};
use std::sync::Arc;
use parking_lot::RwLock;

pub mod crypto;
pub mod pow;
pub mod attestation;
pub mod hardware;

#[cfg(feature = "tpm")]
pub mod tpm;

/// Core proof-of-work engine
pub struct CryptoPowEngine {
    config: Arc<RwLock<EngineConfig>>,
    difficulty: u32,
}

/// Engine configuration
#[derive(Debug, Clone)]
pub struct EngineConfig {
    pub difficulty: u32,
    pub hash_algorithm: HashAlgorithm,
    pub use_simd: bool,
    pub parallel: bool,
    pub threads: usize,
}

/// Supported hash algorithms
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HashAlgorithm {
    SHA256,
    SHA3_256,
    Blake3,
}

/// Proof-of-work challenge
#[derive(Debug, Clone)]
pub struct Challenge {
    pub data: Vec<u8>,
    pub difficulty: u32,
    pub timestamp: i64,
}

/// Proof-of-work solution
#[derive(Debug, Clone)]
pub struct Solution {
    pub nonce: u64,
    pub hash: Vec<u8>,
    pub timestamp: i64,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            difficulty: 20,
            hash_algorithm: HashAlgorithm::Blake3,
            use_simd: cfg!(target_feature = "avx2"),
            parallel: cfg!(feature = "parallel"),
            threads: num_cpus::get(),
        }
    }
}

impl CryptoPowEngine {
    /// Create a new proof-of-work engine
    pub fn new(config: EngineConfig) -> Self {
        let difficulty = config.difficulty;
        Self {
            config: Arc::new(RwLock::new(config)),
            difficulty,
        }
    }

    /// Create with default configuration
    pub fn default() -> Self {
        Self::new(EngineConfig::default())
    }

    /// Generate a new challenge
    pub fn generate_challenge(&self, data: &[u8]) -> Result<Challenge> {
        let config = self.config.read();
        Ok(Challenge {
            data: data.to_vec(),
            difficulty: config.difficulty,
            timestamp: chrono::Utc::now().timestamp(),
        })
    }

    /// Solve a challenge
    pub fn solve(&self, challenge: &Challenge) -> Result<Solution> {
        let config = self.config.read();

        if config.parallel {
            #[cfg(feature = "parallel")]
            {
                self.solve_parallel(challenge)
            }
            #[cfg(not(feature = "parallel"))]
            {
                self.solve_sequential(challenge)
            }
        } else {
            self.solve_sequential(challenge)
        }
    }

    /// Verify a solution
    pub fn verify(&self, challenge: &Challenge, solution: &Solution) -> Result<bool> {
        if solution.hash.is_empty() {
            // Recompute hash if not provided
            let hash = self.compute_hash(&challenge.data, solution.nonce)?;
            return Ok(self.check_difficulty(&hash, challenge.difficulty));
        }

        let hash = self.compute_hash(&challenge.data, solution.nonce)?;

        if hash != solution.hash {
            return Ok(false);
        }

        Ok(self.check_difficulty(&hash, challenge.difficulty))
    }

    /// Solve challenge sequentially
    fn solve_sequential(&self, challenge: &Challenge) -> Result<Solution> {
        for nonce in 0..u64::MAX {
            let hash = self.compute_hash(&challenge.data, nonce)?;

            if self.check_difficulty(&hash, challenge.difficulty) {
                return Ok(Solution {
                    nonce,
                    hash,
                    timestamp: chrono::Utc::now().timestamp(),
                });
            }
        }

        anyhow::bail!("Failed to find solution")
    }

    /// Solve challenge in parallel
    #[cfg(feature = "parallel")]
    fn solve_parallel(&self, challenge: &Challenge) -> Result<Solution> {
        use rayon::prelude::*;
        use std::sync::atomic::{AtomicBool, Ordering};

        let config = self.config.read();
        let found = Arc::new(AtomicBool::new(false));
        let solution = Arc::new(RwLock::new(None));

        let chunk_size = u64::MAX / config.threads as u64;

        (0..config.threads).into_par_iter().for_each(|thread_id| {
            let start = thread_id as u64 * chunk_size;
            let end = if thread_id == config.threads - 1 {
                u64::MAX
            } else {
                start + chunk_size
            };

            for nonce in start..end {
                if found.load(Ordering::Relaxed) {
                    break;
                }

                if let Ok(hash) = self.compute_hash(&challenge.data, nonce) {
                    if self.check_difficulty(&hash, challenge.difficulty) {
                        found.store(true, Ordering::Relaxed);
                        *solution.write() = Some(Solution {
                            nonce,
                            hash,
                            timestamp: chrono::Utc::now().timestamp(),
                        });
                        break;
                    }
                }
            }
        });

        let result = solution.read().clone();
        result.context("Failed to find solution in parallel")
    }

    /// Compute hash using configured algorithm
    fn compute_hash(&self, data: &[u8], nonce: u64) -> Result<Vec<u8>> {
        let config = self.config.read();
        let mut input = data.to_vec();
        input.extend_from_slice(&nonce.to_le_bytes());

        match config.hash_algorithm {
            HashAlgorithm::SHA256 => {
                use sha2::{Sha256, Digest};
                Ok(Sha256::digest(&input).to_vec())
            }
            HashAlgorithm::SHA3_256 => {
                use sha3::{Sha3_256, Digest};
                Ok(Sha3_256::digest(&input).to_vec())
            }
            HashAlgorithm::Blake3 => {
                Ok(blake3::hash(&input).as_bytes().to_vec())
            }
        }
    }

    /// Check if hash meets difficulty requirement
    fn check_difficulty(&self, hash: &[u8], difficulty: u32) -> bool {
        let leading_zeros = hash.iter()
            .take_while(|&&b| b == 0)
            .count() * 8;

        let first_nonzero = hash.iter()
            .skip_while(|&&b| b == 0)
            .next()
            .copied()
            .unwrap_or(0);

        let additional_zeros = first_nonzero.leading_zeros();
        let total_zeros = leading_zeros as u32 + additional_zeros;

        total_zeros >= difficulty
    }

    /// Update engine configuration
    pub fn update_config<F>(&self, f: F) -> Result<()>
    where
        F: FnOnce(&mut EngineConfig),
    {
        let mut config = self.config.write();
        f(&mut config);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_creation() {
        let engine = CryptoPowEngine::default();
        assert_eq!(engine.difficulty, 20);
    }

    #[test]
    fn test_challenge_generation() {
        let engine = CryptoPowEngine::default();
        let challenge = engine.generate_challenge(b"test data").unwrap();
        assert_eq!(challenge.data, b"test data");
        assert_eq!(challenge.difficulty, 20);
    }

    #[test]
    fn test_difficulty_check() {
        let engine = CryptoPowEngine::default();

        // Hash with leading zeros
        let easy_hash = vec![0, 0, 0, 255, 255, 255];
        assert!(engine.check_difficulty(&easy_hash, 20));

        // Hash without enough leading zeros
        let hard_hash = vec![255, 255, 255, 255, 255, 255];
        assert!(!engine.check_difficulty(&hard_hash, 20));
    }

    #[test]
    fn test_solve_and_verify() {
        let mut config = EngineConfig::default();
        config.difficulty = 12; // Lower difficulty for testing
        config.parallel = false;

        let engine = CryptoPowEngine::new(config);
        let challenge = engine.generate_challenge(b"test").unwrap();
        let solution = engine.solve(&challenge).unwrap();

        assert!(engine.verify(&challenge, &solution).unwrap());
    }
}
