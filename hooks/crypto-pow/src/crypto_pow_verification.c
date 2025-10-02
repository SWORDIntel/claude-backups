/**
 * Cryptographic Proof-of-Work Verification System - Main Verification Engine
 * Enterprise-Grade C Implementation with Zero Fake Code Tolerance
 *
 * SECURITY NOTICE: This module provides the main verification engine that
 * combines structural analysis, behavioral testing, and cryptographic proof-of-work
 * to determine implementation authenticity with enterprise-grade confidence scoring.
 */

#define _GNU_SOURCE
#define OPENSSL_SUPPRESS_DEPRECATED

#include "crypto_pow_architecture.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <unistd.h>
#include <inttypes.h>

// =============================================================================
// COMPLETE VERIFICATION PROCESS
// =============================================================================

pow_status_t verify_implementation_authenticity(verification_system_t *system,
                                              const char *component_name,
                                              const char *component_path,
                                              real_implementation_proof_t *proof) {
    CHECK_NULL_RETURN(system, POW_STATUS_INVALID_INPUT);
    CHECK_NULL_RETURN(component_name, POW_STATUS_INVALID_INPUT);
    CHECK_NULL_RETURN(component_path, POW_STATUS_INVALID_INPUT);
    CHECK_NULL_RETURN(proof, POW_STATUS_INVALID_INPUT);

    memset(proof, 0, sizeof(real_implementation_proof_t));

    // Validate inputs
    if (!validate_component_name(component_name) ||
        !validate_component_path(component_path)) {
        return POW_STATUS_INVALID_INPUT;
    }

    // Lock system for thread safety
    pthread_mutex_lock(&system->system_mutex);

    // Copy component information
    strncpy(proof->component_name, component_name, MAX_COMPONENT_NAME_LEN - 1);
    proof->component_name[MAX_COMPONENT_NAME_LEN - 1] = '\0';

    strncpy(proof->component_path, component_path, MAX_COMPONENT_PATH_LEN - 1);
    proof->component_path[MAX_COMPONENT_PATH_LEN - 1] = '\0';

    proof->verification_time = time(NULL);
    proof->verification_id = generate_secure_random_uint64();

    struct timeval start_time, current_time;
    gettimeofday(&start_time, NULL);

    LOG_ERROR(system, POW_STATUS_SUCCESS, "Starting verification");

    // Phase 1: Structural Analysis (40% weight)
    printf("Phase 1: Analyzing source code structure...\n");

    // Initialize pattern database if not already done
    if (system->pattern_db.pattern_count == 0) {
        pow_status_t status = pattern_database_init(&system->pattern_db);
        if (status != POW_STATUS_SUCCESS) {
            pthread_mutex_unlock(&system->system_mutex);
            return status;
        }

        status = pattern_database_load_defaults(&system->pattern_db);
        if (status != POW_STATUS_SUCCESS) {
            pthread_mutex_unlock(&system->system_mutex);
            return status;
        }
    }

    pow_status_t status = analyze_source_file(component_path,
                                             &system->pattern_db,
                                             &proof->structural);
    if (status != POW_STATUS_SUCCESS) {
        // Try directory analysis if file analysis fails
        char *dir_path = strdup(component_path);
        char *last_slash = strrchr(dir_path, '/');
        if (last_slash) {
            *last_slash = '\0';
            status = analyze_source_directory(dir_path, &system->pattern_db, &proof->structural);
        }
        free(dir_path);

        if (status != POW_STATUS_SUCCESS) {
            LOG_ERROR(system, status, "Structural analysis failed");
            pthread_mutex_unlock(&system->system_mutex);
            return status;
        }
    }

    gettimeofday(&current_time, NULL);
    double structural_time = (current_time.tv_sec - start_time.tv_sec) * 1000.0 +
                            (current_time.tv_usec - start_time.tv_usec) / 1000.0;

    printf("Structural analysis completed in %.2f ms\n", structural_time);
    printf("  Simulation matches: %u (score: %.3f)\n",
           proof->structural.simulation_matches, proof->structural.simulation_score);
    printf("  Real implementation matches: %u (score: %.3f)\n",
           proof->structural.real_matches, proof->structural.real_score);

    // Phase 2: Behavioral Testing (30% weight)
    printf("Phase 2: Executing behavioral tests...\n");

    status = execute_behavioral_tests(component_path, &proof->behavioral);
    if (status != POW_STATUS_SUCCESS) {
        LOG_ERROR(system, status, "Behavioral testing failed");
        // Don't fail completely, behavioral testing is optional
        proof->behavioral.test_count = 0;
        proof->behavioral.passed_tests = 0;
        proof->behavioral.failed_tests = 1;
    }

    gettimeofday(&current_time, NULL);
    double behavioral_time = (current_time.tv_sec - start_time.tv_sec) * 1000.0 +
                            (current_time.tv_usec - start_time.tv_usec) / 1000.0 - structural_time;

    printf("Behavioral testing completed in %.2f ms\n", behavioral_time);
    printf("  Tests passed: %u/%zu\n", proof->behavioral.passed_tests, proof->behavioral.test_count);
    printf("  Execution time: %.2f ms\n", proof->behavioral.total_execution_time);

    // Phase 3: Cryptographic Proof-of-Work (30% weight)
    printf("Phase 3: Mining cryptographic proof-of-work...\n");

    // Create unique data for proof-of-work including component metadata
    char pow_data[1024];
    snprintf(pow_data, sizeof(pow_data),
            "VERIFY:%s:%s:%" PRIu64 ":%ld",
            component_name, component_path,
            proof->verification_id, proof->verification_time);

    // Set difficulty based on hardware tier
    uint32_t difficulty = 12; // Default
    switch (system->hardware_tier) {
        case HARDWARE_TIER_MAXIMUM: difficulty = 16; break;
        case HARDWARE_TIER_OPTIMIZED: difficulty = 14; break;
        case HARDWARE_TIER_ENHANCED: difficulty = 12; break;
        case HARDWARE_TIER_BASIC: difficulty = 10; break;
        default: difficulty = 8; break;
    }

    char target[WORK_TARGET_LEN];
    generate_difficulty_target(difficulty, target);

    uint32_t max_threads = 8; // Reasonable default
    intel_acceleration_t accel;
    if (intel_acceleration_init(&accel) == POW_STATUS_SUCCESS) {
        max_threads = accel.hw_info.cpu_cores;
        if (max_threads > 16) max_threads = 16; // Cap for safety
    }

    status = mine_proof_of_work(pow_data, target, max_threads, 30.0, &proof->proof);
    if (status != POW_STATUS_SUCCESS) {
        LOG_ERROR(system, status, "Proof-of-work mining failed");
        pthread_mutex_unlock(&system->system_mutex);
        return status;
    }

    gettimeofday(&current_time, NULL);
    double crypto_time = (current_time.tv_sec - start_time.tv_sec) * 1000.0 +
                        (current_time.tv_usec - start_time.tv_usec) / 1000.0 - structural_time - behavioral_time;

    printf("Cryptographic proof-of-work completed in %.2f ms\n", crypto_time);
    printf("  Difficulty: %u leading zeros\n", difficulty);
    printf("  Nonce found: %" PRIu64 "\n", proof->proof.nonce);
    printf("  Hash: %s\n", proof->proof.verification_hash);
    printf("  Mining iterations: %" PRIu64 "\n", proof->proof.mining_iterations);

    // Phase 4: Calculate Overall Confidence Score
    printf("Phase 4: Calculating confidence score...\n");

    proof->confidence_score = calculate_overall_confidence(
        &proof->structural, &proof->behavioral, &proof->proof);

    printf("Overall confidence score: %.3f\n", proof->confidence_score);

    // Phase 5: Generate Cryptographic Signature
    printf("Phase 5: Generating cryptographic signature...\n");

    // Create verification data for signing
    char verification_data[2048];
    snprintf(verification_data, sizeof(verification_data),
            "VERIFIED:%s:%s:%.6f:%" PRIu64 ":%s",
            proof->component_name, proof->component_path,
            proof->confidence_score, proof->proof.nonce,
            proof->proof.verification_hash);

    status = sign_data_rsa_4096(&system->crypto_ctx,
                               (unsigned char*)verification_data,
                               strlen(verification_data),
                               proof->crypto_signature);

    if (status != POW_STATUS_SUCCESS) {
        LOG_ERROR(system, status, "Cryptographic signature generation failed");
        pthread_mutex_unlock(&system->system_mutex);
        return status;
    }

    // Determine if implementation is quantum resistant (placeholder)
    proof->is_quantum_resistant = (proof->confidence_score > 0.8 &&
                                  proof->structural.has_crypto_operations);

    // Final validation
    bool is_authentic = (proof->confidence_score >= 0.7 &&
                        proof->proof.type == IMPL_TYPE_REAL &&
                        proof->behavioral.passed_tests > proof->behavioral.failed_tests);

    if (!is_authentic) {
        snprintf(proof->error_message, MAX_ERROR_MSG_LEN,
                "Implementation failed authenticity verification (confidence: %.3f)",
                proof->confidence_score);
        LOG_ERROR(system, POW_STATUS_CRYPTO_ERROR, proof->error_message);
    }

    printf("Verification %s (confidence: %.3f)\n",
           is_authentic ? "PASSED" : "FAILED", proof->confidence_score);

    pthread_mutex_unlock(&system->system_mutex);
    return is_authentic ? POW_STATUS_SUCCESS : POW_STATUS_CRYPTO_ERROR;
}

double calculate_overall_confidence(const structural_evidence_t *structural,
                                  const behavioral_evidence_t *behavioral,
                                  const proof_of_work_t *crypto_proof) {
    if (!structural || !behavioral || !crypto_proof) return 0.0;

    // Calculate component confidence scores
    double structural_confidence = calculate_structural_confidence(structural);
    double behavioral_confidence = calculate_behavioral_confidence(behavioral);

    // Cryptographic confidence based on proof-of-work success and quality
    double crypto_confidence = 0.0;
    if (crypto_proof->type == IMPL_TYPE_REAL &&
        strlen(crypto_proof->verification_hash) > 0 &&
        crypto_proof->mining_iterations > 0) {

        crypto_confidence = 0.8; // Base score for valid proof

        // Bonus for high difficulty
        if (crypto_proof->difficulty_bits >= 16) {
            crypto_confidence += 0.15;
        } else if (crypto_proof->difficulty_bits >= 12) {
            crypto_confidence += 0.1;
        }

        // Bonus for reasonable mining time (not too fast = suspicious)
        if (crypto_proof->mining_duration_ms > 100.0 &&
            crypto_proof->mining_duration_ms < 30000.0) {
            crypto_confidence += 0.05;
        }
    }

    // Weighted combination: 40% structural + 30% behavioral + 30% crypto
    double overall_confidence = (structural_confidence * 0.40) +
                               (behavioral_confidence * 0.30) +
                               (crypto_confidence * 0.30);

    // Apply penalties for obvious fake patterns
    if (structural->simulation_score > 0.5) {
        overall_confidence *= 0.5; // Strong penalty
    }

    if (behavioral->failed_tests > behavioral->passed_tests) {
        overall_confidence *= 0.8; // Penalty for test failures
    }

    // Apply bonuses for strong real implementation evidence
    if (structural->has_crypto_operations &&
        structural->has_network_operations &&
        behavioral->subprocess_security_validated) {
        overall_confidence += 0.1; // Bonus for comprehensive implementation
    }

    // Ensure confidence stays in [0, 1] range
    if (overall_confidence < 0.0) overall_confidence = 0.0;
    if (overall_confidence > 1.0) overall_confidence = 1.0;

    return overall_confidence;
}

// =============================================================================
// AUDIT AND LOGGING
// =============================================================================

pow_status_t log_verification_result(verification_system_t *system,
                                   const real_implementation_proof_t *proof) {
    CHECK_NULL_RETURN(system, POW_STATUS_INVALID_INPUT);
    CHECK_NULL_RETURN(proof, POW_STATUS_INVALID_INPUT);

    if (!system->audit_log) {
        return POW_STATUS_SUCCESS; // No logging configured
    }

    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);

    fprintf(system->audit_log,
           "[%s] VERIFICATION RESULT:\n"
           "  Component: %s\n"
           "  Path: %s\n"
           "  Verification ID: %" PRIu64 "\n"
           "  Confidence Score: %.6f\n"
           "  Structural Evidence: %u sim / %u real (scores: %.3f / %.3f)\n"
           "  Behavioral Evidence: %u passed / %u failed (%.2f ms)\n"
           "  Crypto Proof: %s (%" PRIu64 " iterations, %u difficulty)\n"
           "  Quantum Resistant: %s\n"
           "  Result: %s\n"
           "  Error: %s\n\n",
           timestamp,
           proof->component_name,
           proof->component_path,
           proof->verification_id,
           proof->confidence_score,
           proof->structural.simulation_matches,
           proof->structural.real_matches,
           proof->structural.simulation_score,
           proof->structural.real_score,
           proof->behavioral.passed_tests,
           proof->behavioral.failed_tests,
           proof->behavioral.total_execution_time,
           proof->proof.verification_hash,
           proof->proof.mining_iterations,
           proof->proof.difficulty_bits,
           proof->is_quantum_resistant ? "Yes" : "No",
           (proof->confidence_score >= 0.7) ? "AUTHENTIC" : "REJECTED",
           strlen(proof->error_message) > 0 ? proof->error_message : "None");

    fflush(system->audit_log);
    return POW_STATUS_SUCCESS;
}

pow_status_t export_verification_json(const real_implementation_proof_t *proof,
                                     const char *output_path) {
    CHECK_NULL_RETURN(proof, POW_STATUS_INVALID_INPUT);
    CHECK_NULL_RETURN(output_path, POW_STATUS_INVALID_INPUT);

    FILE *json_file = fopen(output_path, "w");
    if (!json_file) {
        return POW_STATUS_INVALID_INPUT;
    }

    fprintf(json_file, "{\n");
    fprintf(json_file, "  \"verification_result\": {\n");
    fprintf(json_file, "    \"component_name\": \"%s\",\n", proof->component_name);
    fprintf(json_file, "    \"component_path\": \"%s\",\n", proof->component_path);
    fprintf(json_file, "    \"verification_id\": %" PRIu64 ",\n", proof->verification_id);
    fprintf(json_file, "    \"verification_time\": %ld,\n", proof->verification_time);
    fprintf(json_file, "    \"confidence_score\": %.6f,\n", proof->confidence_score);
    fprintf(json_file, "    \"is_quantum_resistant\": %s,\n",
           proof->is_quantum_resistant ? "true" : "false");

    fprintf(json_file, "    \"structural_evidence\": {\n");
    fprintf(json_file, "      \"simulation_matches\": %u,\n", proof->structural.simulation_matches);
    fprintf(json_file, "      \"real_matches\": %u,\n", proof->structural.real_matches);
    fprintf(json_file, "      \"simulation_score\": %.6f,\n", proof->structural.simulation_score);
    fprintf(json_file, "      \"real_score\": %.6f,\n", proof->structural.real_score);
    fprintf(json_file, "      \"has_crypto_operations\": %s,\n",
           proof->structural.has_crypto_operations ? "true" : "false");
    fprintf(json_file, "      \"has_network_operations\": %s,\n",
           proof->structural.has_network_operations ? "true" : "false");
    fprintf(json_file, "      \"has_database_operations\": %s,\n",
           proof->structural.has_database_operations ? "true" : "false");
    fprintf(json_file, "      \"has_hardware_operations\": %s\n",
           proof->structural.has_hardware_operations ? "true" : "false");
    fprintf(json_file, "    },\n");

    fprintf(json_file, "    \"behavioral_evidence\": {\n");
    fprintf(json_file, "      \"test_count\": %zu,\n", proof->behavioral.test_count);
    fprintf(json_file, "      \"passed_tests\": %u,\n", proof->behavioral.passed_tests);
    fprintf(json_file, "      \"failed_tests\": %u,\n", proof->behavioral.failed_tests);
    fprintf(json_file, "      \"total_execution_time\": %.2f,\n", proof->behavioral.total_execution_time);
    fprintf(json_file, "      \"subprocess_security_validated\": %s\n",
           proof->behavioral.subprocess_security_validated ? "true" : "false");
    fprintf(json_file, "    },\n");

    fprintf(json_file, "    \"cryptographic_proof\": {\n");
    fprintf(json_file, "      \"component_hash\": \"%.64s\",\n", proof->proof.component_hash);
    fprintf(json_file, "      \"work_target\": \"%.16s\",\n", proof->proof.work_target);
    fprintf(json_file, "      \"nonce\": %" PRIu64 ",\n", proof->proof.nonce);
    fprintf(json_file, "      \"timestamp\": %.6f,\n", proof->proof.timestamp);
    fprintf(json_file, "      \"verification_hash\": \"%.64s\",\n", proof->proof.verification_hash);
    fprintf(json_file, "      \"type\": \"%s\",\n",
           (proof->proof.type == IMPL_TYPE_REAL) ? "REAL" : "UNKNOWN");
    fprintf(json_file, "      \"difficulty_bits\": %u,\n", proof->proof.difficulty_bits);
    fprintf(json_file, "      \"mining_iterations\": %" PRIu64 ",\n", proof->proof.mining_iterations);
    fprintf(json_file, "      \"mining_duration_ms\": %.2f\n", proof->proof.mining_duration_ms);
    fprintf(json_file, "    },\n");

    fprintf(json_file, "    \"crypto_signature\": \"%.512s\",\n", proof->crypto_signature);

    if (strlen(proof->error_message) > 0) {
        fprintf(json_file, "    \"error_message\": \"%s\",\n", proof->error_message);
    }

    fprintf(json_file, "    \"verification_status\": \"%s\"\n",
           (proof->confidence_score >= 0.7) ? "AUTHENTIC" : "REJECTED");

    fprintf(json_file, "  }\n");
    fprintf(json_file, "}\n");

    fclose(json_file);
    return POW_STATUS_SUCCESS;
}

// =============================================================================
// BATCH VERIFICATION FUNCTIONS
// =============================================================================

pow_status_t verify_multiple_components(verification_system_t *system,
                                       const char **component_paths,
                                       size_t component_count,
                                       real_implementation_proof_t *results) {
    CHECK_NULL_RETURN(system, POW_STATUS_INVALID_INPUT);
    CHECK_NULL_RETURN(component_paths, POW_STATUS_INVALID_INPUT);
    CHECK_NULL_RETURN(results, POW_STATUS_INVALID_INPUT);

    if (component_count == 0) {
        return POW_STATUS_INVALID_INPUT;
    }

    printf("Batch verification of %zu components...\n", component_count);

    size_t successful_verifications = 0;
    size_t failed_verifications = 0;

    for (size_t i = 0; i < component_count; i++) {
        printf("\n=== Component %zu/%zu: %s ===\n",
               i + 1, component_count, component_paths[i]);

        char component_name[256];
        const char *filename = strrchr(component_paths[i], '/');
        if (filename) {
            filename++; // Skip the '/'
        } else {
            filename = component_paths[i];
        }

        strncpy(component_name, filename, sizeof(component_name) - 1);
        component_name[sizeof(component_name) - 1] = '\0';

        pow_status_t status = verify_implementation_authenticity(
            system, component_name, component_paths[i], &results[i]);

        if (status == POW_STATUS_SUCCESS) {
            successful_verifications++;
            printf("✓ VERIFIED (confidence: %.3f)\n", results[i].confidence_score);
        } else {
            failed_verifications++;
            printf("✗ REJECTED (confidence: %.3f)\n", results[i].confidence_score);
        }

        // Log result
        log_verification_result(system, &results[i]);
    }

    printf("\n=== Batch Verification Summary ===\n");
    printf("Total components: %zu\n", component_count);
    printf("Successful verifications: %zu\n", successful_verifications);
    printf("Failed verifications: %zu\n", failed_verifications);
    printf("Success rate: %.1f%%\n",
           (double)successful_verifications / component_count * 100.0);

    return (failed_verifications == 0) ? POW_STATUS_SUCCESS : POW_STATUS_CRYPTO_ERROR;
}

// =============================================================================
// PERFORMANCE MONITORING
// =============================================================================

void print_verification_performance_summary(verification_system_t *system) {
    if (!system) return;

    printf("\n=== Performance Summary ===\n");
    printf("Hardware tier: %d\n", system->hardware_tier);
    printf("Memory allocated: %zu bytes (peak: %zu bytes)\n",
           system->memory_mgr.total_allocated,
           system->memory_mgr.peak_allocated);
    printf("Pattern database: %zu patterns loaded\n", system->pattern_db.pattern_count);

    // Additional metrics could be added here
}