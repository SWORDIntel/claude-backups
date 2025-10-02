/**
 * Cryptographic Proof-of-Work Verification System - Demonstration
 * Enterprise-Grade C Implementation with Zero Fake Code Tolerance
 *
 * This demonstration shows the complete verification process for a code component,
 * including structural analysis, behavioral testing, and cryptographic proof-of-work.
 */

#define _GNU_SOURCE
#define OPENSSL_SUPPRESS_DEPRECATED

#include "crypto_pow_architecture.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <inttypes.h>

int main(int argc, char *argv[]) {
    printf("=======================================================\n");
    printf("Cryptographic Proof-of-Work Verification System v1.0\n");
    printf("Enterprise-Grade Implementation Authenticity Verifier\n");
    printf("=======================================================\n\n");

    // Check command line arguments
    if (argc < 2) {
        printf("Usage: %s <component_path> [component_name]\n\n", argv[0]);
        printf("This tool performs comprehensive cryptographic verification to determine\n");
        printf("if a code component is a real implementation (not fake/simulated).\n\n");
        printf("Verification process:\n");
        printf("  1. Structural Analysis (40%% weight)\n");
        printf("     - Pattern detection for simulation indicators\n");
        printf("     - Real implementation evidence\n");
        printf("     - Cryptographic operation detection\n\n");
        printf("  2. Behavioral Testing (30%% weight)\n");
        printf("     - Secure subprocess execution\n");
        printf("     - System interaction validation\n");
        printf("     - Timing analysis\n\n");
        printf("  3. Cryptographic Proof-of-Work (30%% weight)\n");
        printf("     - SHA-256 mining with Intel acceleration\n");
        printf("     - RSA-4096 digital signatures\n");
        printf("     - Hardware-backed authenticity proof\n\n");
        printf("Example:\n");
        printf("  %s crypto_pow_core.c \"CryptoCore\"\n", argv[0]);
        return 1;
    }

    const char *component_path = argv[1];
    const char *component_name = (argc > 2) ? argv[2] : "TestComponent";

    printf("Initializing verification system...\n");

    // Initialize the verification system
    verification_system_t system;
    pow_status_t status = verification_system_init(&system, "verification_audit.log");
    if (status != POW_STATUS_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to initialize verification system: %s\n",
                pow_status_to_string(status));
        return 1;
    }

    printf("✓ Verification system initialized\n");
    printf("✓ Hardware tier: %d\n", system.hardware_tier);
    printf("✓ RSA-4096 keypair generated\n");
    printf("✓ Pattern database loaded\n\n");

    // Perform the complete verification
    printf("Starting verification of component: %s\n", component_name);
    printf("Component path: %s\n\n", component_path);

    real_implementation_proof_t proof;
    status = verify_implementation_authenticity(&system, component_name, component_path, &proof);

    printf("\n=======================================================\n");
    printf("VERIFICATION RESULTS\n");
    printf("=======================================================\n\n");

    printf("Component: %s\n", proof.component_name);
    printf("Path: %s\n", proof.component_path);
    printf("Verification ID: %" PRIu64 "\n", proof.verification_id);
    printf("Verification Time: %ld\n", proof.verification_time);

    printf("\n--- Structural Analysis Results ---\n");
    printf("Simulation matches: %u (score: %.3f)\n",
           proof.structural.simulation_matches, proof.structural.simulation_score);
    printf("Real implementation matches: %u (score: %.3f)\n",
           proof.structural.real_matches, proof.structural.real_score);
    printf("Has crypto operations: %s\n",
           proof.structural.has_crypto_operations ? "Yes" : "No");
    printf("Has network operations: %s\n",
           proof.structural.has_network_operations ? "Yes" : "No");
    printf("Has database operations: %s\n",
           proof.structural.has_database_operations ? "Yes" : "No");
    printf("Has hardware operations: %s\n",
           proof.structural.has_hardware_operations ? "Yes" : "No");

    printf("\n--- Behavioral Testing Results ---\n");
    printf("Tests executed: %zu\n", proof.behavioral.test_count);
    printf("Tests passed: %u\n", proof.behavioral.passed_tests);
    printf("Tests failed: %u\n", proof.behavioral.failed_tests);
    printf("Execution time: %.2f ms\n", proof.behavioral.total_execution_time);
    printf("Security validated: %s\n",
           proof.behavioral.subprocess_security_validated ? "Yes" : "No");

    printf("\n--- Cryptographic Proof-of-Work Results ---\n");
    printf("Mining difficulty: %u leading zeros\n", proof.proof.difficulty_bits);
    printf("Nonce found: %" PRIu64 "\n", proof.proof.nonce);
    printf("Verification hash: %s\n", proof.proof.verification_hash);
    printf("Mining iterations: %" PRIu64 "\n", proof.proof.mining_iterations);
    printf("Mining duration: %.2f ms\n", proof.proof.mining_duration_ms);

    printf("\n--- Final Assessment ---\n");
    printf("Overall Confidence Score: %.3f\n", proof.confidence_score);
    printf("Quantum Resistant: %s\n", proof.is_quantum_resistant ? "Yes" : "No");

    bool is_authentic = (status == POW_STATUS_SUCCESS && proof.confidence_score >= 0.7);

    if (is_authentic) {
        printf("\n🟢 VERIFICATION RESULT: AUTHENTIC IMPLEMENTATION\n");
        printf("This component has been cryptographically verified as a real,\n");
        printf("non-simulated implementation with high confidence.\n");
    } else {
        printf("\n🔴 VERIFICATION RESULT: REJECTED\n");
        printf("This component failed authenticity verification.\n");
        if (strlen(proof.error_message) > 0) {
            printf("Error: %s\n", proof.error_message);
        }
        printf("Possible reasons:\n");
        printf("- Contains simulation/fake patterns\n");
        printf("- Failed behavioral tests\n");
        printf("- Insufficient cryptographic proof\n");
    }

    // Export detailed results
    char json_filename[256];
    snprintf(json_filename, sizeof(json_filename), "verification_%" PRIu64 ".json", proof.verification_id);

    pow_status_t export_status = export_verification_json(&proof, json_filename);
    if (export_status == POW_STATUS_SUCCESS) {
        printf("\n✓ Detailed results exported to: %s\n", json_filename);
    }

    // Log the verification result
    log_verification_result(&system, &proof);

    printf("\n--- Performance Summary ---\n");
    printf("Hardware tier: %d\n", system.hardware_tier);
    printf("Memory allocated: %zu bytes (peak: %zu bytes)\n",
           system.memory_mgr.total_allocated,
           system.memory_mgr.peak_allocated);
    printf("Pattern database: %zu patterns loaded\n", system.pattern_db.pattern_count);

    // Clean up
    verification_system_cleanup(&system);
    printf("\n✓ Verification system cleaned up\n");

    return is_authentic ? 0 : 1;
}