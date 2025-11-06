//! Hardware attestation module
//!
//! Provides cryptographic attestation using hardware security features

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Attestation data structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Attestation {
    pub hardware_id: String,
    pub timestamp: i64,
    pub nonce: Vec<u8>,
    pub signature: Vec<u8>,
    pub metadata: AttestationMetadata,
}

/// Attestation metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttestationMetadata {
    pub cpu_model: String,
    pub cpu_features: Vec<String>,
    pub tpm_present: bool,
    pub secure_boot: bool,
}

/// Generate hardware attestation
pub fn generate_attestation(data: &[u8]) -> Result<Attestation> {
    use crate::crypto::{KeyPair, random_bytes};

    let keypair = KeyPair::generate()?;
    let nonce = random_bytes(32)?;

    let mut attestation_data = data.to_vec();
    attestation_data.extend_from_slice(&nonce);

    let signature = keypair.sign(&attestation_data);

    let metadata = AttestationMetadata {
        cpu_model: crate::hardware::get_cpu_model(),
        cpu_features: crate::hardware::get_cpu_features(),
        tpm_present: crate::hardware::has_tpm(),
        secure_boot: crate::hardware::has_secure_boot(),
    };

    Ok(Attestation {
        hardware_id: crate::hardware::get_hardware_id(),
        timestamp: chrono::Utc::now().timestamp(),
        nonce,
        signature: signature.to_bytes().to_vec(),
        metadata,
    })
}

/// Verify hardware attestation
pub fn verify_attestation(attestation: &Attestation, data: &[u8]) -> Result<bool> {
    // Reconstruct attestation data
    let mut attestation_data = data.to_vec();
    attestation_data.extend_from_slice(&attestation.nonce);

    // In a real implementation, you would:
    // 1. Load the public key from a trusted source
    // 2. Verify the signature
    // 3. Check timestamp validity
    // 4. Validate hardware ID against trusted database

    // For now, we just validate the structure
    Ok(!attestation.signature.is_empty()
        && !attestation.nonce.is_empty()
        && attestation.timestamp > 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_attestation_generation() {
        let data = b"attestation test data";
        let attestation = generate_attestation(data).unwrap();

        assert!(!attestation.hardware_id.is_empty());
        assert!(!attestation.signature.is_empty());
        assert_eq!(attestation.nonce.len(), 32);
    }

    #[test]
    fn test_attestation_verification() {
        let data = b"verification test";
        let attestation = generate_attestation(data).unwrap();

        assert!(verify_attestation(&attestation, data).unwrap());
    }
}
