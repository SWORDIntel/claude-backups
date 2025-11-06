//! Cryptographic operations module
//!
//! Provides hardware-accelerated cryptographic primitives

use anyhow::Result;
use ed25519_dalek::{Signer, Verifier, SigningKey, VerifyingKey, Signature};
use rand::rngs::OsRng;

/// Cryptographic key pair
pub struct KeyPair {
    signing_key: SigningKey,
    verifying_key: VerifyingKey,
}

impl KeyPair {
    /// Generate a new key pair
    pub fn generate() -> Result<Self> {
        let mut csprng = OsRng;
        let signing_key = SigningKey::generate(&mut csprng);
        let verifying_key = signing_key.verifying_key();

        Ok(Self {
            signing_key,
            verifying_key,
        })
    }

    /// Sign data
    pub fn sign(&self, data: &[u8]) -> Signature {
        self.signing_key.sign(data)
    }

    /// Get verifying key
    pub fn verifying_key(&self) -> &VerifyingKey {
        &self.verifying_key
    }

    /// Verify signature
    pub fn verify(verifying_key: &VerifyingKey, data: &[u8], signature: &Signature) -> Result<()> {
        verifying_key
            .verify(data, signature)
            .map_err(|e| anyhow::anyhow!("Signature verification failed: {}", e))
    }
}

/// Hardware-accelerated hash computation
pub mod hash {
    use blake3::Hasher;

    /// Compute Blake3 hash (optimized for AVX2/AVX-512)
    pub fn blake3(data: &[u8]) -> [u8; 32] {
        blake3::hash(data).into()
    }

    /// Compute Blake3 hash incrementally
    pub fn blake3_incremental(chunks: &[&[u8]]) -> [u8; 32] {
        let mut hasher = Hasher::new();
        for chunk in chunks {
            hasher.update(chunk);
        }
        hasher.finalize().into()
    }

    /// Compute SHA-256 hash
    pub fn sha256(data: &[u8]) -> [u8; 32] {
        use sha2::{Sha256, Digest};
        let mut hasher = Sha256::new();
        hasher.update(data);
        hasher.finalize().into()
    }

    /// Compute SHA3-256 hash
    pub fn sha3_256(data: &[u8]) -> [u8; 32] {
        use sha3::{Sha3_256, Digest};
        let mut hasher = Sha3_256::new();
        hasher.update(data);
        hasher.finalize().into()
    }
}

/// Generate cryptographically secure random bytes
pub fn random_bytes(len: usize) -> Result<Vec<u8>> {
    use rand::RngCore;
    let mut bytes = vec![0u8; len];
    OsRng.fill_bytes(&mut bytes);
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_keypair_generation() {
        let keypair = KeyPair::generate().unwrap();
        let data = b"test message";
        let signature = keypair.sign(data);
        assert!(KeyPair::verify(keypair.verifying_key(), data, &signature).is_ok());
    }

    #[test]
    fn test_blake3_hash() {
        let data = b"test data";
        let hash1 = hash::blake3(data);
        let hash2 = hash::blake3(data);
        assert_eq!(hash1, hash2);
    }

    #[test]
    fn test_random_bytes() {
        let bytes1 = random_bytes(32).unwrap();
        let bytes2 = random_bytes(32).unwrap();
        assert_ne!(bytes1, bytes2);
        assert_eq!(bytes1.len(), 32);
    }
}
