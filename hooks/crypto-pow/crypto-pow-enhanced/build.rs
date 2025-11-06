// Build script for Crypto-POW Enhanced
// Configures C integration and target-specific optimizations

use std::env;

fn main() {
    let target = env::var("TARGET").unwrap();
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap();

    println!("cargo:rerun-if-changed=build.rs");

    // Enable target-specific optimizations
    if target_arch == "x86_64" {
        // Check for AVX2 support at compile time
        if is_x86_feature_detected!("avx2") {
            println!("cargo:rustc-cfg=has_avx2");
        }

        // Enable SIMD optimizations
        println!("cargo:rustc-env=RUSTFLAGS=-C target-cpu=native");
    }

    // Link against OpenSSL if available (for hardware crypto acceleration)
    #[cfg(target_os = "linux")]
    {
        if pkg_config::probe_library("openssl").is_ok() {
            println!("cargo:rustc-cfg=has_openssl");
        }
    }

    // Optimization flags for meteorlake
    if target.contains("x86_64") {
        println!("cargo:rustc-env=CFLAGS=-march=native -mtune=native");
    }
}

// Runtime detection helper
#[cfg(any(target_arch = "x86", target_arch = "x86_64"))]
fn is_x86_feature_detected(feature: &str) -> bool {
    match feature {
        "avx2" => cfg!(target_feature = "avx2") || std::is_x86_feature_detected!("avx2"),
        "avx512f" => cfg!(target_feature = "avx512f") || std::is_x86_feature_detected!("avx512f"),
        _ => false,
    }
}

#[cfg(not(any(target_arch = "x86", target_arch = "x86_64")))]
fn is_x86_feature_detected(_feature: &str) -> bool {
    false
}
