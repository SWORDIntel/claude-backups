//! Crypto-POW CLI tool
//!
//! Command-line interface for cryptographic proof-of-work operations

use anyhow::Result;
use clap::{Parser, Subcommand};
use colored::Colorize;
use crypto_pow_enhanced::{CryptoPowEngine, EngineConfig, HashAlgorithm};
use std::time::Instant;

#[derive(Parser)]
#[command(name = "crypto-pow")]
#[command(about = "Hardware-accelerated cryptographic proof-of-work", long_about = None)]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Enable verbose output
    #[arg(short, long, global = true)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Solve a proof-of-work challenge
    Solve {
        /// Challenge data (hex encoded)
        #[arg(short, long)]
        data: String,

        /// Difficulty (number of leading zero bits)
        #[arg(short = 'D', long, default_value = "20")]
        difficulty: u32,

        /// Hash algorithm to use
        #[arg(short = 'a', long, value_enum, default_value = "blake3")]
        algorithm: Algorithm,

        /// Use parallel processing
        #[arg(short, long)]
        parallel: bool,
    },

    /// Verify a proof-of-work solution
    Verify {
        /// Challenge data (hex encoded)
        #[arg(short, long)]
        data: String,

        /// Nonce (solution)
        #[arg(short, long)]
        nonce: u64,

        /// Difficulty
        #[arg(short = 'D', long)]
        difficulty: u32,
    },

    /// Generate hardware attestation
    Attest {
        /// Data to attest (hex encoded)
        #[arg(short, long)]
        data: String,

        /// Output file
        #[arg(short, long)]
        output: Option<String>,
    },

    /// Show hardware information
    Info,

    /// Run benchmark
    Benchmark {
        /// Difficulty level
        #[arg(short = 'D', long, default_value = "16")]
        difficulty: u32,

        /// Number of iterations
        #[arg(short, long, default_value = "5")]
        iterations: u32,
    },
}

#[derive(clap::ValueEnum, Clone, Copy)]
enum Algorithm {
    Sha256,
    Sha3_256,
    Blake3,
}

impl From<Algorithm> for HashAlgorithm {
    fn from(algo: Algorithm) -> Self {
        match algo {
            Algorithm::Sha256 => HashAlgorithm::SHA256,
            Algorithm::Sha3_256 => HashAlgorithm::SHA3_256,
            Algorithm::Blake3 => HashAlgorithm::Blake3,
        }
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    if cli.verbose {
        println!("{}", "Crypto-POW Enhanced v0.2.0".bright_cyan().bold());
        println!("{}", "━".repeat(50).bright_black());
    }

    match cli.command {
        Commands::Solve {
            data,
            difficulty,
            algorithm,
            parallel,
        } => solve_command(&data, difficulty, algorithm, parallel, cli.verbose),

        Commands::Verify {
            data,
            nonce,
            difficulty,
        } => verify_command(&data, nonce, difficulty, cli.verbose),

        Commands::Attest { data, output } => attest_command(&data, output.as_deref(), cli.verbose),

        Commands::Info => info_command(cli.verbose),

        Commands::Benchmark {
            difficulty,
            iterations,
        } => benchmark_command(difficulty, iterations, cli.verbose),
    }
}

fn solve_command(
    data: &str,
    difficulty: u32,
    algorithm: Algorithm,
    parallel: bool,
    verbose: bool,
) -> Result<()> {
    let data_bytes = hex::decode(data)?;

    let mut config = EngineConfig::default();
    config.difficulty = difficulty;
    config.hash_algorithm = algorithm.into();
    config.parallel = parallel;

    if verbose {
        println!("📊 Configuration:");
        println!("  Difficulty: {} bits", difficulty);
        println!("  Algorithm: {:?}", config.hash_algorithm);
        println!("  Parallel: {}", parallel);
        println!("  Threads: {}", config.threads);
        println!();
    }

    let engine = CryptoPowEngine::new(config);
    let challenge = engine.generate_challenge(&data_bytes)?;

    println!("{}", "⚙️  Solving challenge...".yellow());
    let start = Instant::now();

    let solution = engine.solve(&challenge)?;
    let duration = start.elapsed();

    println!("{}", "✅ Solution found!".green().bold());
    println!("  Nonce: {}", solution.nonce.to_string().cyan());
    println!("  Hash: {}", hex::encode(&solution.hash).bright_black());
    println!(
        "  Time: {:.2}s",
        duration.as_secs_f64().to_string().yellow()
    );

    Ok(())
}

fn verify_command(data: &str, nonce: u64, difficulty: u32, verbose: bool) -> Result<()> {
    let data_bytes = hex::decode(data)?;

    let mut config = EngineConfig::default();
    config.difficulty = difficulty;

    let engine = CryptoPowEngine::new(config);
    let challenge = engine.generate_challenge(&data_bytes)?;

    let solution = crypto_pow_enhanced::Solution {
        nonce,
        hash: vec![],
        timestamp: chrono::Utc::now().timestamp(),
    };

    // Recompute hash for solution
    let valid = crypto_pow_enhanced::pow::verify_pow(&data_bytes, nonce, difficulty)?;

    if valid {
        println!("{}", "✅ Solution is valid!".green().bold());
    } else {
        println!("{}", "❌ Solution is invalid!".red().bold());
    }

    Ok(())
}

fn attest_command(data: &str, output: Option<&str>, verbose: bool) -> Result<()> {
    let data_bytes = hex::decode(data)?;

    if verbose {
        println!("{}", "🔐 Generating hardware attestation...".cyan());
    }

    let attestation = crypto_pow_enhanced::attestation::generate_attestation(&data_bytes)?;

    if let Some(output_path) = output {
        let json = serde_json::to_string_pretty(&attestation)?;
        std::fs::write(output_path, json)?;
        println!("{} {}", "✅ Attestation saved to:".green(), output_path.cyan());
    } else {
        let json = serde_json::to_string_pretty(&attestation)?;
        println!("{}", json);
    }

    Ok(())
}

fn info_command(verbose: bool) -> Result<()> {
    let hw_info = crypto_pow_enhanced::hardware::get_hardware_info();

    println!("{}", "🖥️  Hardware Information".bright_cyan().bold());
    println!("{}", "━".repeat(50).bright_black());
    println!("  CPU Model: {}", hw_info.cpu_model.cyan());
    println!("  Cores: {}", hw_info.core_count.to_string().yellow());

    println!("\n{}", "⚡ CPU Features:".bright_cyan());
    for feature in &hw_info.cpu_features {
        println!("  ✓ {}", feature.green());
    }

    println!("\n{}", "🔒 Security:".bright_cyan());
    println!(
        "  TPM: {}",
        if crypto_pow_enhanced::hardware::has_tpm() {
            "Present".green()
        } else {
            "Not found".red()
        }
    );
    println!(
        "  Secure Boot: {}",
        if crypto_pow_enhanced::hardware::has_secure_boot() {
            "Enabled".green()
        } else {
            "Disabled".yellow()
        }
    );

    println!("\n{}", "🆔 Hardware ID:".bright_cyan());
    println!("  {}", crypto_pow_enhanced::hardware::get_hardware_id());

    Ok(())
}

fn benchmark_command(difficulty: u32, iterations: u32, verbose: bool) -> Result<()> {
    use indicatif::{ProgressBar, ProgressStyle};

    println!("{}", "🏁 Running benchmark...".bright_cyan().bold());
    println!("  Difficulty: {} bits", difficulty);
    println!("  Iterations: {}", iterations);
    println!();

    let pb = ProgressBar::new(iterations as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} ({eta})")?
            .progress_chars("#>-"),
    );

    let mut total_time = 0f64;
    let mut total_attempts = 0u64;

    for i in 0..iterations {
        let data = format!("benchmark_{}", i);
        let data_bytes = data.as_bytes();

        let config = EngineConfig {
            difficulty,
            ..Default::default()
        };

        let engine = CryptoPowEngine::new(config);
        let challenge = engine.generate_challenge(data_bytes)?;

        let start = Instant::now();
        let solution = engine.solve(&challenge)?;
        let duration = start.elapsed();

        total_time += duration.as_secs_f64();

        pb.inc(1);
    }

    pb.finish_with_message("Complete!");

    println!();
    println!("{}", "📊 Results:".bright_cyan().bold());
    println!(
        "  Avg time: {:.2}s",
        (total_time / iterations as f64).to_string().yellow()
    );
    println!("  Total time: {:.2}s", total_time.to_string().cyan());

    Ok(())
}
