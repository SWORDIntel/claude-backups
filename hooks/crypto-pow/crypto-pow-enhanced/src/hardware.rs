//! Hardware detection and optimization module
//!
//! Detects CPU features and provides hardware-specific optimizations

use std::sync::OnceLock;

static HARDWARE_INFO: OnceLock<HardwareInfo> = OnceLock::new();

#[derive(Debug, Clone)]
pub struct HardwareInfo {
    pub cpu_model: String,
    pub cpu_features: Vec<String>,
    pub core_count: usize,
    pub has_avx2: bool,
    pub has_avx512: bool,
    pub has_aes_ni: bool,
}

impl HardwareInfo {
    fn detect() -> Self {
        #[cfg(target_arch = "x86_64")]
        {
            Self::detect_x86_64()
        }

        #[cfg(not(target_arch = "x86_64"))]
        {
            Self::detect_generic()
        }
    }

    #[cfg(target_arch = "x86_64")]
    fn detect_x86_64() -> Self {
        let mut features = Vec::new();

        // Detect CPU features
        if is_x86_feature_detected!("avx2") {
            features.push("avx2".to_string());
        }
        if is_x86_feature_detected!("avx512f") {
            features.push("avx512f".to_string());
        }
        if is_x86_feature_detected!("aes") {
            features.push("aes".to_string());
        }
        if is_x86_feature_detected!("sha") {
            features.push("sha".to_string());
        }
        if is_x86_feature_detected!("fma") {
            features.push("fma".to_string());
        }

        Self {
            cpu_model: get_cpu_model_x86(),
            cpu_features: features.clone(),
            core_count: num_cpus::get(),
            has_avx2: features.contains(&"avx2".to_string()),
            has_avx512: features.contains(&"avx512f".to_string()),
            has_aes_ni: features.contains(&"aes".to_string()),
        }
    }

    #[cfg(not(target_arch = "x86_64"))]
    fn detect_generic() -> Self {
        Self {
            cpu_model: "unknown".to_string(),
            cpu_features: vec![],
            core_count: num_cpus::get(),
            has_avx2: false,
            has_avx512: false,
            has_aes_ni: false,
        }
    }
}

#[cfg(target_arch = "x86_64")]
fn get_cpu_model_x86() -> String {
    // Try to read from /proc/cpuinfo on Linux
    #[cfg(target_os = "linux")]
    {
        if let Ok(cpuinfo) = std::fs::read_to_string("/proc/cpuinfo") {
            for line in cpuinfo.lines() {
                if line.starts_with("model name") {
                    if let Some(model) = line.split(':').nth(1) {
                        return model.trim().to_string();
                    }
                }
            }
        }
    }

    "x86_64".to_string()
}

/// Get hardware information (cached)
pub fn get_hardware_info() -> &'static HardwareInfo {
    HARDWARE_INFO.get_or_init(HardwareInfo::detect)
}

/// Get CPU model
pub fn get_cpu_model() -> String {
    get_hardware_info().cpu_model.clone()
}

/// Get CPU features
pub fn get_cpu_features() -> Vec<String> {
    get_hardware_info().cpu_features.clone()
}

/// Get hardware ID (based on CPU info)
pub fn get_hardware_id() -> String {
    use sha2::{Sha256, Digest};

    let info = get_hardware_info();
    let mut hasher = Sha256::new();

    hasher.update(info.cpu_model.as_bytes());
    hasher.update(&info.core_count.to_le_bytes());

    hex::encode(hasher.finalize())
}

/// Check if TPM is available
pub fn has_tpm() -> bool {
    #[cfg(target_os = "linux")]
    {
        std::path::Path::new("/dev/tpm0").exists()
            || std::path::Path::new("/dev/tpmrm0").exists()
    }

    #[cfg(not(target_os = "linux"))]
    {
        false
    }
}

/// Check if Secure Boot is enabled
pub fn has_secure_boot() -> bool {
    #[cfg(target_os = "linux")]
    {
        if let Ok(content) = std::fs::read_to_string("/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c") {
            // SecureBoot variable exists and contains non-zero value
            return content.bytes().any(|b| b != 0);
        }
    }

    false
}

/// Get optimal thread count for POW operations
pub fn get_optimal_threads() -> usize {
    let info = get_hardware_info();

    // Use all cores for POW
    info.core_count
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hardware_detection() {
        let info = get_hardware_info();
        assert!(info.core_count > 0);
        assert!(!info.cpu_model.is_empty());
    }

    #[test]
    fn test_hardware_id() {
        let id = get_hardware_id();
        assert_eq!(id.len(), 64); // SHA-256 hex = 64 chars
    }

    #[test]
    fn test_optimal_threads() {
        let threads = get_optimal_threads();
        assert!(threads > 0);
    }
}
