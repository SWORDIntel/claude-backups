//! TPM signing example (requires TPM feature)

#[cfg(feature = "tpm")]
use anyhow::Result;

#[cfg(feature = "tpm")]
fn main() -> Result<()> {
    use crypto_pow_enhanced::tpm::TpmContext;

    println!("=== TPM Signing Example ===\n");

    // Initialize TPM context
    let tpm = TpmContext::new()?;

    println!("TPM initialized successfully");

    // Generate a key in TPM
    println!("Generating TPM key...");
    let _key = tpm.generate_key()?;

    println!("✅ Key generated");

    // Sign some data
    let data = b"Sign this data";
    println!("Signing data...");
    let _signature = tpm.sign(data)?;

    println!("✅ Data signed successfully");

    Ok(())
}

#[cfg(not(feature = "tpm"))]
fn main() {
    eprintln!("This example requires the 'tpm' feature.");
    eprintln!("Run with: cargo run --example tpm_signing --features tpm");
}
