//! Proof-of-Work implementation module
//!
//! Optimized POW algorithms for Intel Meteor Lake with SIMD support

use anyhow::Result;
use std::time::Instant;

/// POW statistics
#[derive(Debug, Clone)]
pub struct PowStats {
    pub attempts: u64,
    pub duration_ms: u64,
    pub hash_rate: f64,
}

/// Compute proof-of-work with difficulty target
pub fn compute_pow(data: &[u8], difficulty: u32) -> Result<(u64, Vec<u8>, PowStats)> {
    let start = Instant::now();
    let mut attempts = 0u64;

    for nonce in 0..u64::MAX {
        attempts += 1;

        let hash = compute_hash_with_nonce(data, nonce);

        if check_difficulty(&hash, difficulty) {
            let duration = start.elapsed();
            let hash_rate = attempts as f64 / duration.as_secs_f64();

            let stats = PowStats {
                attempts,
                duration_ms: duration.as_millis() as u64,
                hash_rate,
            };

            return Ok((nonce, hash, stats));
        }
    }

    anyhow::bail!("POW computation failed: no solution found")
}

/// Compute hash with nonce
fn compute_hash_with_nonce(data: &[u8], nonce: u64) -> Vec<u8> {
    use blake3::Hasher;

    let mut hasher = Hasher::new();
    hasher.update(data);
    hasher.update(&nonce.to_le_bytes());
    hasher.finalize().as_bytes().to_vec()
}

/// Check if hash meets difficulty requirement
fn check_difficulty(hash: &[u8], difficulty: u32) -> bool {
    let leading_zeros = count_leading_zero_bits(hash);
    leading_zeros >= difficulty
}

/// Count leading zero bits in hash
fn count_leading_zero_bits(hash: &[u8]) -> u32 {
    let mut count = 0u32;

    for &byte in hash {
        if byte == 0 {
            count += 8;
        } else {
            count += byte.leading_zeros();
            break;
        }
    }

    count
}

/// Verify proof-of-work solution
pub fn verify_pow(data: &[u8], nonce: u64, difficulty: u32) -> Result<bool> {
    let hash = compute_hash_with_nonce(data, nonce);
    Ok(check_difficulty(&hash, difficulty))
}

#[cfg(feature = "parallel")]
pub mod parallel {
    use super::*;
    use rayon::prelude::*;
    use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
    use std::sync::Arc;

    /// Compute POW in parallel using all available cores
    pub fn compute_pow_parallel(data: &[u8], difficulty: u32) -> Result<(u64, Vec<u8>, PowStats)> {
        let start = Instant::now();
        let threads = num_cpus::get();
        let chunk_size = u64::MAX / threads as u64;

        let found = Arc::new(AtomicBool::new(false));
        let solution_nonce = Arc::new(AtomicU64::new(0));
        let attempts = Arc::new(AtomicU64::new(0));

        (0..threads).into_par_iter().for_each(|thread_id| {
            let start_nonce = thread_id as u64 * chunk_size;
            let end_nonce = if thread_id == threads - 1 {
                u64::MAX
            } else {
                start_nonce + chunk_size
            };

            for nonce in start_nonce..end_nonce {
                if found.load(Ordering::Relaxed) {
                    break;
                }

                attempts.fetch_add(1, Ordering::Relaxed);
                let hash = compute_hash_with_nonce(data, nonce);

                if check_difficulty(&hash, difficulty) {
                    found.store(true, Ordering::Relaxed);
                    solution_nonce.store(nonce, Ordering::Relaxed);
                    break;
                }
            }
        });

        if found.load(Ordering::Relaxed) {
            let nonce = solution_nonce.load(Ordering::Relaxed);
            let hash = compute_hash_with_nonce(data, nonce);
            let duration = start.elapsed();
            let total_attempts = attempts.load(Ordering::Relaxed);
            let hash_rate = total_attempts as f64 / duration.as_secs_f64();

            let stats = PowStats {
                attempts: total_attempts,
                duration_ms: duration.as_millis() as u64,
                hash_rate,
            };

            Ok((nonce, hash, stats))
        } else {
            anyhow::bail!("POW computation failed: no solution found")
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_count_leading_zeros() {
        assert_eq!(count_leading_zero_bits(&[0, 0, 128]), 17);
        assert_eq!(count_leading_zero_bits(&[0, 0, 0, 1]), 31);
    }

    #[test]
    fn test_pow_compute_verify() {
        let data = b"test data";
        let difficulty = 12; // Low difficulty for testing

        let (nonce, _hash, stats) = compute_pow(data, difficulty).unwrap();
        assert!(stats.attempts > 0);
        assert!(verify_pow(data, nonce, difficulty).unwrap());
    }

    #[cfg(feature = "parallel")]
    #[test]
    fn test_parallel_pow() {
        let data = b"parallel test";
        let difficulty = 12;

        let (nonce, _hash, stats) = parallel::compute_pow_parallel(data, difficulty).unwrap();
        assert!(stats.attempts > 0);
        assert!(verify_pow(data, nonce, difficulty).unwrap());
    }
}
