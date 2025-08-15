/*
 * AGENT SYSTEM INTEGRATION TEST
 * 
 * Comprehensive test suite for the complete Claude Agent Communication System
 * - Service discovery integration tests
 * - Message routing validation
 * - Director orchestration tests
 * - Project workflow execution
 * - Security system validation
 * - Performance and stress testing
 * - End-to-end integration scenarios
 * 
 * This test validates the complete system functioning together
 * 
 * Author: Agent Communication System
 * Version: 1.0 Production
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <pthread.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <assert.h>

// Include the unified agent system header
#include "agent_system.h"

// ============================================================================
// TEST FRAMEWORK
// ============================================================================

typedef struct {
    const char* name;
    bool (*test_func)(void);
    bool required;  // If true, failure stops all testing
    double timeout_seconds;
} test_case_t;

typedef struct {
    int tests_run;
    int tests_passed;
    int tests_failed;
    int tests_skipped;
    double total_time_seconds;
} test_results_t;

static test_results_t g_test_results = {0};

// Color output for better readability
#define COLOR_RESET   "\033[0m"
#define COLOR_RED     "\033[31m"
#define COLOR_GREEN   "\033[32m"
#define COLOR_YELLOW  "\033[33m"
#define COLOR_BLUE    "\033[34m"
#define COLOR_CYAN    "\033[36m"

// Test result macros
#define TEST_PASS(msg) do { \
    printf("  " COLOR_GREEN "✓ PASS" COLOR_RESET ": %s\n", msg); \
    return true; \
} while(0)

#define TEST_FAIL(msg) do { \
    printf("  " COLOR_RED "✗ FAIL" COLOR_RESET ": %s\n", msg); \
    return false; \
} while(0)

#define TEST_SKIP(msg) do { \
    printf("  " COLOR_YELLOW "⚠ SKIP" COLOR_RESET ": %s\n", msg); \
    return true; \
} while(0)

#define ASSERT_TRUE(condition, msg) do { \
    if (!(condition)) { \
        TEST_FAIL("Assertion failed: " msg); \
    } \
} while(0)

#define ASSERT_EQ(expected, actual, msg) do { \
    if ((expected) != (actual)) { \
        printf("  Expected: %ld, Actual: %ld\n", (long)(expected), (long)(actual)); \
        TEST_FAIL("Assertion failed: " msg); \
    } \
} while(0)

#define ASSERT_NOT_NULL(ptr, msg) do { \
    if ((ptr) == NULL) { \
        TEST_FAIL("Assertion failed: " msg " (pointer is NULL)"); \
    } \
} while(0)

// ============================================================================
// EXTERNAL FUNCTION DECLARATIONS
// ============================================================================

// Discovery service functions
extern int discovery_service_init();
extern void discovery_service_cleanup();
extern int register_agent(const char* name, int type, uint32_t instance_id,
                         const void* capabilities, uint32_t capability_count,
                         const void* endpoints, uint32_t endpoint_count);
extern void* discover_agent_by_name(const char* name);
extern void* discover_agent_by_type(int type);
extern void print_discovery_statistics();

// Router service functions
extern int router_service_init();
extern void router_service_cleanup();
extern int create_topic(const char* topic_name, int strategy, bool persistent);
extern int subscribe_to_topic(const char* topic_name, uint32_t agent_id, const char* agent_name);
extern int publish_to_topic(const char* topic_name, uint32_t source_agent_id,
                           const void* payload, size_t payload_size, int priority);
extern int create_work_queue(const char* queue_name, int strategy);
extern int register_worker(const char* queue_name, uint32_t worker_agent_id);
extern int distribute_work_item(const char* queue_name, const void* work_item, size_t item_size);
extern void print_router_statistics();

// Director functions
extern int director_service_init();
extern void director_service_cleanup();
extern uint32_t create_execution_plan(const char* name, const char* description, int priority);
extern int add_execution_step(uint32_t plan_id, const char* step_name, const char* description,
                             int required_agent_type, const char* capability,
                             const char* action, const char* parameters,
                             uint32_t timeout_ms, int priority);
extern int add_step_dependency(uint32_t plan_id, uint32_t step_id, uint32_t dependency_step_id);
extern int start_plan_execution(uint32_t plan_id);
extern int start_director_threads();
extern void print_director_statistics();

// Orchestrator functions
extern int orchestrator_service_init();
extern void orchestrator_service_cleanup();
extern uint32_t create_project(const char* name, const char* description, uint32_t max_concurrent_workflows);
extern int activate_project(uint32_t project_id);
extern uint32_t create_workflow(uint32_t project_id, const char* name, const char* description,
                               int strategy, uint32_t max_parallel_tasks);
extern int add_workflow_task(uint32_t workflow_id, const char* task_name, const char* description,
                            int type, int priority, uint32_t required_agent_type, const char* capability,
                            const char* action, const char* parameters, uint32_t timeout_ms);
extern int add_task_dependency(uint32_t workflow_id, uint32_t task_id, uint32_t dependency_task_id);
extern int start_workflow_execution(uint32_t workflow_id);
extern int start_orchestrator_threads();
extern void print_orchestrator_statistics();

// Security functions
extern int security_service_init();
extern void security_service_cleanup();
extern uint32_t report_vulnerability(const char* title, const char* description,
                                    int severity, const char* file_path,
                                    uint32_t line_number, const char* cve_id);
extern int run_vulnerability_scan(const char* target_path, int scan_type);
extern uint32_t report_threat(const char* threat_name, const char* description,
                             int level, const char* category);
extern uint32_t create_security_incident(const char* title, const char* description,
                                        int severity, bool confirmed);
extern int start_security_threads();
extern void print_security_statistics();

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

static inline uint64_t get_timestamp_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

static double get_timestamp_seconds() {
    return get_timestamp_ns() / 1000000000.0;
}

static void sleep_ms(int milliseconds) {
    usleep(milliseconds * 1000);
}

// ============================================================================
// INDIVIDUAL COMPONENT TESTS
// ============================================================================

static bool test_service_discovery_basic() {
    printf("    Testing service discovery initialization...\n");
    
    int ret = discovery_service_init();
    ASSERT_TRUE(ret == 0, "Discovery service initialization failed");
    
    printf("    Testing agent registration...\n");
    
    // Test agent registration
    uint32_t agent_id = register_agent("TEST_AGENT", AGENT_TYPE_TESTBED, 1, NULL, 0, NULL, 0);
    ASSERT_TRUE(agent_id > 0, "Failed to register test agent");
    
    printf("    Testing agent discovery...\n");
    
    // Test agent discovery
    void* found_agent = discover_agent_by_name("TEST_AGENT");
    ASSERT_NOT_NULL(found_agent, "Failed to discover registered agent");
    
    found_agent = discover_agent_by_type(AGENT_TYPE_TESTBED);
    ASSERT_NOT_NULL(found_agent, "Failed to discover agent by type");
    
    printf("    Testing multiple agent registration...\n");
    
    // Register multiple agents
    uint32_t agent2_id = register_agent("SECURITY_AGENT", AGENT_TYPE_SECURITY, 1, NULL, 0, NULL, 0);
    uint32_t agent3_id = register_agent("DIRECTOR_AGENT", AGENT_TYPE_DIRECTOR, 1, NULL, 0, NULL, 0);
    
    ASSERT_TRUE(agent2_id > 0 && agent3_id > 0, "Failed to register multiple agents");
    
    // Print discovery statistics
    print_discovery_statistics();
    
    discovery_service_cleanup();
    
    TEST_PASS("Service discovery basic functionality");
}

static bool test_message_routing_basic() {
    printf("    Testing message routing initialization...\n");
    
    int ret = router_service_init();
    ASSERT_TRUE(ret == 0, "Message router initialization failed");
    
    printf("    Testing topic creation...\n");
    
    // Test topic creation
    ret = create_topic("test.topic", ROUTE_ROUND_ROBIN, false);
    ASSERT_TRUE(ret == 0, "Failed to create topic");
    
    ret = create_topic("system.alerts", ROUTE_HIGHEST_PRIORITY, true);
    ASSERT_TRUE(ret == 0, "Failed to create persistent topic");
    
    printf("    Testing subscription...\n");
    
    // Test subscription
    ret = subscribe_to_topic("test.topic", 1, "TEST_SUBSCRIBER");
    ASSERT_TRUE(ret == 0, "Failed to subscribe to topic");
    
    ret = subscribe_to_topic("system.alerts", 2, "ALERT_SUBSCRIBER");
    ASSERT_TRUE(ret == 0, "Failed to subscribe to alerts topic");
    
    printf("    Testing message publishing...\n");
    
    // Test message publishing
    const char* test_message = "Hello from test system";
    int delivered = publish_to_topic("test.topic", 100, test_message, strlen(test_message), PRIORITY_NORMAL);
    ASSERT_TRUE(delivered > 0, "Failed to publish message");
    
    printf("    Testing work queue functionality...\n");
    
    // Test work queue
    ret = create_work_queue("test.workqueue", ROUTE_ROUND_ROBIN);
    ASSERT_TRUE(ret == 0, "Failed to create work queue");
    
    ret = register_worker("test.workqueue", 10);
    ASSERT_TRUE(ret == 0, "Failed to register worker");
    
    const char* work_item = "Process this task";
    uint32_t worker_id = distribute_work_item("test.workqueue", work_item, strlen(work_item));
    ASSERT_TRUE(worker_id > 0, "Failed to distribute work item");
    
    // Print router statistics
    print_router_statistics();
    
    router_service_cleanup();
    
    TEST_PASS("Message routing basic functionality");
}

static bool test_director_orchestration() {
    printf("    Testing director service initialization...\n");
    
    int ret = director_service_init();
    ASSERT_TRUE(ret == 0, "Director service initialization failed");
    
    printf("    Testing execution plan creation...\n");
    
    // Test execution plan creation
    uint32_t plan_id = create_execution_plan("Test Plan", "Test execution plan", PRIORITY_HIGH);
    ASSERT_TRUE(plan_id > 0, "Failed to create execution plan");
    
    printf("    Testing execution step addition...\n");
    
    // Add execution steps
    int step1_id = add_execution_step(plan_id, "Step 1", "First test step",
                                     AGENT_TYPE_TESTBED, "testing",
                                     "run_test", "type=unit", 30000, PRIORITY_HIGH);
    ASSERT_TRUE(step1_id > 0, "Failed to add execution step 1");
    
    int step2_id = add_execution_step(plan_id, "Step 2", "Second test step",
                                     AGENT_TYPE_SECURITY, "security_scan",
                                     "scan", "target=code", 45000, PRIORITY_NORMAL);
    ASSERT_TRUE(step2_id > 0, "Failed to add execution step 2");
    
    int step3_id = add_execution_step(plan_id, "Step 3", "Third test step",
                                     AGENT_TYPE_LINTER, "static_analysis",
                                     "analyze", "rules=strict", 20000, PRIORITY_NORMAL);
    ASSERT_TRUE(step3_id > 0, "Failed to add execution step 3");
    
    printf("    Testing step dependencies...\n");
    
    // Add dependencies
    ret = add_step_dependency(plan_id, step2_id, step1_id);  // Step 2 depends on Step 1
    ASSERT_TRUE(ret == 0, "Failed to add step dependency");
    
    ret = add_step_dependency(plan_id, step3_id, step1_id);  // Step 3 depends on Step 1
    ASSERT_TRUE(ret == 0, "Failed to add step dependency");
    
    printf("    Testing plan execution startup...\n");
    
    // Start director threads
    ret = start_director_threads();
    ASSERT_TRUE(ret == 0, "Failed to start director threads");
    
    // Start plan execution
    ret = start_plan_execution(plan_id);
    ASSERT_TRUE(ret == 0, "Failed to start plan execution");
    
    printf("    Monitoring plan execution...\n");
    
    // Monitor execution for a short time
    sleep_ms(5000);  // 5 seconds
    
    print_director_statistics();
    
    director_service_cleanup();
    
    TEST_PASS("Director orchestration functionality");
}

static bool test_project_orchestrator() {
    printf("    Testing orchestrator service initialization...\n");
    
    int ret = orchestrator_service_init();
    ASSERT_TRUE(ret == 0, "Orchestrator service initialization failed");
    
    printf("    Testing project creation...\n");
    
    // Test project creation
    uint32_t project_id = create_project("Test Project", "Integration test project", 2);
    ASSERT_TRUE(project_id > 0, "Failed to create project");
    
    ret = activate_project(project_id);
    ASSERT_TRUE(ret == 0, "Failed to activate project");
    
    printf("    Testing workflow creation...\n");
    
    // Test workflow creation
    uint32_t workflow_id = create_workflow(project_id, "Test Workflow", "Test workflow execution",
                                          STRATEGY_PARALLEL_LIMITED, 3);
    ASSERT_TRUE(workflow_id > 0, "Failed to create workflow");
    
    printf("    Testing task addition...\n");
    
    // Add workflow tasks
    int task1_id = add_workflow_task(workflow_id, "Analysis Task", "Code analysis task",
                                    TASK_TYPE_ANALYSIS, PRIORITY_HIGH,
                                    AGENT_TYPE_LINTER, "static_analysis",
                                    "analyze_code", "depth=full", 60000);
    ASSERT_TRUE(task1_id > 0, "Failed to add analysis task");
    
    int task2_id = add_workflow_task(workflow_id, "Build Task", "Code compilation task",
                                    TASK_TYPE_BUILD, PRIORITY_HIGH,
                                    AGENT_TYPE_C_INTERNAL, "compilation",
                                    "build_project", "target=release", 90000);
    ASSERT_TRUE(task2_id > 0, "Failed to add build task");
    
    int task3_id = add_workflow_task(workflow_id, "Test Task", "Unit testing task",
                                    TASK_TYPE_TEST, PRIORITY_HIGH,
                                    AGENT_TYPE_TESTBED, "unit_testing",
                                    "run_tests", "coverage=80", 120000);
    ASSERT_TRUE(task3_id > 0, "Failed to add test task");
    
    int task4_id = add_workflow_task(workflow_id, "Security Task", "Security scanning task",
                                    TASK_TYPE_SECURITY, PRIORITY_NORMAL,
                                    AGENT_TYPE_SECURITY, "vulnerability_scan",
                                    "security_scan", "type=full", 180000);
    ASSERT_TRUE(task4_id > 0, "Failed to add security task");
    
    printf("    Testing task dependencies...\n");
    
    // Add task dependencies
    ret = add_task_dependency(workflow_id, task2_id, task1_id);  // Build after analysis
    ASSERT_TRUE(ret == 0, "Failed to add task dependency");
    
    ret = add_task_dependency(workflow_id, task3_id, task2_id);  // Test after build
    ASSERT_TRUE(ret == 0, "Failed to add task dependency");
    
    ret = add_task_dependency(workflow_id, task4_id, task2_id);  // Security scan after build
    ASSERT_TRUE(ret == 0, "Failed to add task dependency");
    
    printf("    Testing workflow execution startup...\n");
    
    // Start orchestrator threads
    ret = start_orchestrator_threads();
    ASSERT_TRUE(ret == 0, "Failed to start orchestrator threads");
    
    // Start workflow execution
    ret = start_workflow_execution(workflow_id);
    ASSERT_TRUE(ret == 0, "Failed to start workflow execution");
    
    printf("    Monitoring workflow execution...\n");
    
    // Monitor execution
    sleep_ms(8000);  // 8 seconds
    
    print_orchestrator_statistics();
    
    orchestrator_service_cleanup();
    
    TEST_PASS("Project orchestrator functionality");
}

static bool test_security_system() {
    printf("    Testing security service initialization...\n");
    
    int ret = security_service_init();
    ASSERT_TRUE(ret == 0, "Security service initialization failed");
    
    printf("    Testing vulnerability reporting...\n");
    
    // Test vulnerability reporting
    uint32_t vuln_id = report_vulnerability("Buffer Overflow Test",
                                           "Test buffer overflow vulnerability",
                                           VULN_SEVERITY_CRITICAL,
                                           "/test/vulnerable.c", 123, "CVE-2023-TEST");
    ASSERT_TRUE(vuln_id > 0, "Failed to report vulnerability");
    
    vuln_id = report_vulnerability("SQL Injection Test",
                                  "Test SQL injection vulnerability",
                                  VULN_SEVERITY_HIGH,
                                  "/test/database.c", 456, NULL);
    ASSERT_TRUE(vuln_id > 0, "Failed to report second vulnerability");
    
    printf("    Testing threat reporting...\n");
    
    // Test threat reporting
    uint32_t threat_id = report_threat("Test Malware",
                                      "Test malware detection",
                                      THREAT_LEVEL_HIGH,
                                      "malware");
    ASSERT_TRUE(threat_id > 0, "Failed to report threat");
    
    threat_id = report_threat("Brute Force Attack",
                             "Test brute force attack detection",
                             THREAT_LEVEL_CRITICAL,
                             "brute_force");
    ASSERT_TRUE(threat_id > 0, "Failed to report second threat");
    
    printf("    Testing security scanning...\n");
    
    // Test vulnerability scanning
    int vulns_found = run_vulnerability_scan("/test/codebase", SCAN_TYPE_STATIC_CODE);
    ASSERT_TRUE(vulns_found >= 0, "Vulnerability scan failed");
    
    vulns_found = run_vulnerability_scan("/test/dependencies", SCAN_TYPE_DEPENDENCY_CHECK);
    ASSERT_TRUE(vulns_found >= 0, "Dependency scan failed");
    
    printf("    Testing incident creation...\n");
    
    // Test incident creation
    uint32_t incident_id = create_security_incident("Test Security Incident",
                                                   "Test incident for validation",
                                                   VULN_SEVERITY_HIGH, true);
    ASSERT_TRUE(incident_id > 0, "Failed to create security incident");
    
    printf("    Testing security monitoring threads...\n");
    
    // Start security threads
    ret = start_security_threads();
    ASSERT_TRUE(ret == 0, "Failed to start security threads");
    
    // Let security monitoring run briefly
    sleep_ms(3000);  // 3 seconds
    
    print_security_statistics();
    
    security_service_cleanup();
    
    TEST_PASS("Security system functionality");
}

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

static bool test_end_to_end_integration() {
    printf("    Testing complete system integration...\n");
    
    // Initialize all services
    printf("      Initializing all services...\n");
    
    int ret = discovery_service_init();
    ASSERT_TRUE(ret == 0, "Failed to initialize discovery service");
    
    ret = router_service_init();
    ASSERT_TRUE(ret == 0, "Failed to initialize router service");
    
    ret = director_service_init();
    ASSERT_TRUE(ret == 0, "Failed to initialize director service");
    
    ret = orchestrator_service_init();
    ASSERT_TRUE(ret == 0, "Failed to initialize orchestrator service");
    
    ret = security_service_init();
    ASSERT_TRUE(ret == 0, "Failed to initialize security service");
    
    printf("      Registering agents in discovery service...\n");
    
    // Register agents
    uint32_t director_agent_id = register_agent("DIRECTOR", AGENT_TYPE_DIRECTOR, 1, NULL, 0, NULL, 0);
    uint32_t orchestrator_agent_id = register_agent("ORCHESTRATOR", AGENT_TYPE_PROJECT_ORCHESTRATOR, 1, NULL, 0, NULL, 0);
    uint32_t security_agent_id = register_agent("SECURITY", AGENT_TYPE_SECURITY, 1, NULL, 0, NULL, 0);
    uint32_t testbed_agent_id = register_agent("TESTBED", AGENT_TYPE_TESTBED, 1, NULL, 0, NULL, 0);
    
    ASSERT_TRUE(director_agent_id > 0 && orchestrator_agent_id > 0 && 
                security_agent_id > 0 && testbed_agent_id > 0, 
                "Failed to register all agents");
    
    printf("      Setting up message routing...\n");
    
    // Set up message routing
    ret = create_topic("system.coordination", ROUTE_ROUND_ROBIN, true);
    ASSERT_TRUE(ret == 0, "Failed to create coordination topic");
    
    ret = create_topic("security.alerts", ROUTE_HIGHEST_PRIORITY, true);
    ASSERT_TRUE(ret == 0, "Failed to create security alerts topic");
    
    ret = subscribe_to_topic("system.coordination", director_agent_id, "DIRECTOR");
    ret &= subscribe_to_topic("system.coordination", orchestrator_agent_id, "ORCHESTRATOR");
    ret &= subscribe_to_topic("security.alerts", director_agent_id, "DIRECTOR");
    ret &= subscribe_to_topic("security.alerts", security_agent_id, "SECURITY");
    ASSERT_TRUE(ret == 0, "Failed to set up subscriptions");
    
    ret = create_work_queue("analysis.tasks", ROUTE_LEAST_LOADED);
    ASSERT_TRUE(ret == 0, "Failed to create work queue");
    
    ret = register_worker("analysis.tasks", testbed_agent_id);
    ASSERT_TRUE(ret == 0, "Failed to register worker");
    
    printf("      Creating integrated project workflow...\n");
    
    // Create integrated project workflow
    uint32_t project_id = create_project("Integration Test Project", 
                                        "End-to-end integration test", 1);
    ASSERT_TRUE(project_id > 0, "Failed to create integration project");
    
    ret = activate_project(project_id);
    ASSERT_TRUE(ret == 0, "Failed to activate integration project");
    
    uint32_t workflow_id = create_workflow(project_id, "Security-Aware Development",
                                          "Complete development workflow with security integration",
                                          STRATEGY_ADAPTIVE, 4);
    ASSERT_TRUE(workflow_id > 0, "Failed to create integration workflow");
    
    // Add comprehensive workflow tasks
    int security_scan_id = add_workflow_task(workflow_id, "Initial Security Scan",
                                            "Perform initial security assessment",
                                            TASK_TYPE_SECURITY, PRIORITY_CRITICAL,
                                            AGENT_TYPE_SECURITY, "vulnerability_scan",
                                            "full_security_scan", "baseline=true", 120000);
    ASSERT_TRUE(security_scan_id > 0, "Failed to add security scan task");
    
    int code_analysis_id = add_workflow_task(workflow_id, "Code Analysis",
                                           "Static code analysis and quality check",
                                           TASK_TYPE_ANALYSIS, PRIORITY_HIGH,
                                           AGENT_TYPE_LINTER, "static_analysis",
                                           "analyze_codebase", "rules=security", 90000);
    ASSERT_TRUE(code_analysis_id > 0, "Failed to add code analysis task");
    
    int build_id = add_workflow_task(workflow_id, "Secure Build",
                                    "Build with security hardening",
                                    TASK_TYPE_BUILD, PRIORITY_HIGH,
                                    AGENT_TYPE_C_INTERNAL, "secure_build",
                                    "build_hardened", "security_flags=true", 120000);
    ASSERT_TRUE(build_id > 0, "Failed to add build task");
    
    int test_id = add_workflow_task(workflow_id, "Security Testing",
                                   "Comprehensive security testing",
                                   TASK_TYPE_TEST, PRIORITY_HIGH,
                                   AGENT_TYPE_TESTBED, "security_testing",
                                   "run_security_tests", "include_penetration=true", 180000);
    ASSERT_TRUE(test_id > 0, "Failed to add security testing task");
    
    // Set up task dependencies for proper execution order
    ret = add_task_dependency(workflow_id, code_analysis_id, security_scan_id);
    ret &= add_task_dependency(workflow_id, build_id, code_analysis_id);
    ret &= add_task_dependency(workflow_id, test_id, build_id);
    ASSERT_TRUE(ret == 0, "Failed to set up task dependencies");
    
    printf("      Starting all system threads...\n");
    
    // Start all system threads
    ret = start_director_threads();
    ret &= start_orchestrator_threads();
    ret &= start_security_threads();
    ASSERT_TRUE(ret == 0, "Failed to start system threads");
    
    printf("      Starting workflow execution...\n");
    
    // Start workflow execution
    ret = start_workflow_execution(workflow_id);
    ASSERT_TRUE(ret == 0, "Failed to start workflow execution");
    
    printf("      Testing message publishing during execution...\n");
    
    // Test cross-service communication during execution
    const char* coord_message = "Workflow started - all agents coordinate";
    int delivered = publish_to_topic("system.coordination", director_agent_id, 
                                    coord_message, strlen(coord_message), PRIORITY_HIGH);
    ASSERT_TRUE(delivered > 0, "Failed to publish coordination message");
    
    const char* alert_message = "Security monitoring active";
    delivered = publish_to_topic("security.alerts", security_agent_id,
                                alert_message, strlen(alert_message), PRIORITY_CRITICAL);
    ASSERT_TRUE(delivered > 0, "Failed to publish security alert");
    
    printf("      Testing work distribution...\n");
    
    // Test work distribution
    const char* analysis_work = "Analyze module security patterns";
    uint32_t worker_id = distribute_work_item("analysis.tasks", analysis_work, strlen(analysis_work));
    ASSERT_TRUE(worker_id > 0, "Failed to distribute analysis work");
    
    printf("      Testing security event generation...\n");
    
    // Generate some security events
    uint32_t vuln_id = report_vulnerability("Integration Test Vulnerability",
                                           "Test vulnerability for integration",
                                           VULN_SEVERITY_MEDIUM,
                                           "/integration/test.c", 999, NULL);
    ASSERT_TRUE(vuln_id > 0, "Failed to report integration vulnerability");
    
    uint32_t threat_id = report_threat("Integration Test Threat",
                                      "Test threat for integration",
                                      THREAT_LEVEL_LOW,
                                      "test_category");
    ASSERT_TRUE(threat_id > 0, "Failed to report integration threat");
    
    printf("      Monitoring integrated system execution...\n");
    
    // Monitor the integrated system for a reasonable time
    for (int i = 0; i < 15; i++) {  // 15 seconds total
        sleep_ms(1000);
        
        if (i % 5 == 4) {  // Every 5 seconds
            printf("        System running for %d seconds...\n", i + 1);
        }
    }
    
    printf("      Collecting final statistics...\n");
    
    // Print comprehensive statistics
    printf("\n      === INTEGRATION TEST RESULTS ===\n");
    print_discovery_statistics();
    print_router_statistics();
    print_director_statistics();
    print_orchestrator_statistics();
    print_security_statistics();
    
    // Cleanup all services
    printf("      Cleaning up all services...\n");
    
    security_service_cleanup();
    orchestrator_service_cleanup();
    director_service_cleanup();
    router_service_cleanup();
    discovery_service_cleanup();
    
    TEST_PASS("End-to-end system integration with cross-service communication");
}

// ============================================================================
// PERFORMANCE TESTS
// ============================================================================

static bool test_system_performance() {
    printf("    Testing system performance under load...\n");
    
    // Initialize core services for performance testing
    int ret = discovery_service_init();
    ret &= router_service_init();
    ASSERT_TRUE(ret == 0, "Failed to initialize services for performance test");
    
    printf("      Testing agent registration performance...\n");
    
    // Test agent registration performance
    uint64_t start_time = get_timestamp_ns();
    
    for (int i = 0; i < 100; i++) {
        char agent_name[64];
        snprintf(agent_name, sizeof(agent_name), "PERF_AGENT_%d", i);
        
        uint32_t agent_id = register_agent(agent_name, AGENT_TYPE_TESTBED, i + 1, NULL, 0, NULL, 0);
        if (agent_id == 0) {
            TEST_FAIL("Failed to register agent during performance test");
        }
    }
    
    uint64_t registration_time = get_timestamp_ns() - start_time;
    double registration_rate = 100.0 / (registration_time / 1000000000.0);
    
    printf("        Agent registration rate: %.1f agents/second\n", registration_rate);
    ASSERT_TRUE(registration_rate > 10.0, "Agent registration rate too slow");
    
    printf("      Testing message routing performance...\n");
    
    // Test message routing performance
    ret = create_topic("performance.test", ROUTE_ROUND_ROBIN, false);
    ASSERT_TRUE(ret == 0, "Failed to create performance test topic");
    
    // Subscribe multiple agents
    for (int i = 1; i <= 10; i++) {
        char subscriber_name[64];
        snprintf(subscriber_name, sizeof(subscriber_name), "PERF_SUB_%d", i);
        ret = subscribe_to_topic("performance.test", i, subscriber_name);
        ASSERT_TRUE(ret == 0, "Failed to subscribe to performance topic");
    }
    
    start_time = get_timestamp_ns();
    
    // Send many messages
    const char* perf_message = "Performance test message payload";
    int total_delivered = 0;
    
    for (int i = 0; i < 1000; i++) {
        int delivered = publish_to_topic("performance.test", 100, 
                                        perf_message, strlen(perf_message), PRIORITY_NORMAL);
        if (delivered > 0) {
            total_delivered += delivered;
        }
    }
    
    uint64_t routing_time = get_timestamp_ns() - start_time;
    double message_rate = total_delivered / (routing_time / 1000000000.0);
    
    printf("        Message routing rate: %.1f messages/second\n", message_rate);
    ASSERT_TRUE(message_rate > 1000.0, "Message routing rate too slow");
    ASSERT_TRUE(total_delivered >= 1000, "Too many messages failed to deliver");
    
    printf("      Testing discovery performance...\n");
    
    // Test discovery performance
    start_time = get_timestamp_ns();
    
    for (int i = 0; i < 1000; i++) {
        void* found_agent = discover_agent_by_type(AGENT_TYPE_TESTBED);
        if (found_agent == NULL) {
            TEST_FAIL("Discovery failed during performance test");
        }
    }
    
    uint64_t discovery_time = get_timestamp_ns() - start_time;
    double discovery_rate = 1000.0 / (discovery_time / 1000000000.0);
    
    printf("        Discovery rate: %.1f lookups/second\n", discovery_rate);
    ASSERT_TRUE(discovery_rate > 10000.0, "Discovery rate too slow");
    
    // Cleanup
    router_service_cleanup();
    discovery_service_cleanup();
    
    TEST_PASS("System performance under load meets requirements");
}

// ============================================================================
// TEST SUITE DEFINITION
// ============================================================================

static test_case_t test_cases[] = {
    // Individual component tests
    {"Service Discovery Basic", test_service_discovery_basic, true, 30.0},
    {"Message Routing Basic", test_message_routing_basic, true, 30.0},
    {"Director Orchestration", test_director_orchestration, true, 45.0},
    {"Project Orchestrator", test_project_orchestrator, true, 60.0},
    {"Security System", test_security_system, true, 45.0},
    
    // Integration tests
    {"End-to-End Integration", test_end_to_end_integration, true, 120.0},
    
    // Performance tests
    {"System Performance", test_system_performance, false, 60.0},
    
    // Sentinel
    {NULL, NULL, false, 0.0}
};

// ============================================================================
// TEST RUNNER
// ============================================================================

static bool run_test_with_timeout(test_case_t* test) {
    printf("  " COLOR_BLUE "Running:" COLOR_RESET " %s\n", test->name);
    
    double start_time = get_timestamp_seconds();
    bool result = test->test_func();
    double end_time = get_timestamp_seconds();
    
    double elapsed = end_time - start_time;
    
    if (result) {
        printf("  " COLOR_GREEN "✓ PASSED" COLOR_RESET " %s (%.2fs)\n", test->name, elapsed);
        g_test_results.tests_passed++;
    } else {
        printf("  " COLOR_RED "✗ FAILED" COLOR_RESET " %s (%.2fs)\n", test->name, elapsed);
        g_test_results.tests_failed++;
    }
    
    if (elapsed > test->timeout_seconds) {
        printf("  " COLOR_YELLOW "⚠ WARNING:" COLOR_RESET " Test exceeded expected time (%.2fs > %.2fs)\n",
               elapsed, test->timeout_seconds);
    }
    
    g_test_results.total_time_seconds += elapsed;
    g_test_results.tests_run++;
    
    return result;
}

static void print_test_summary() {
    printf("\n");
    printf(COLOR_CYAN "===================================\n");
    printf("    TEST SUITE SUMMARY\n");
    printf("===================================\n" COLOR_RESET);
    printf("Tests run:    %d\n", g_test_results.tests_run);
    printf("Tests passed: " COLOR_GREEN "%d" COLOR_RESET "\n", g_test_results.tests_passed);
    printf("Tests failed: " COLOR_RED "%d" COLOR_RESET "\n", g_test_results.tests_failed);
    printf("Tests skipped: " COLOR_YELLOW "%d" COLOR_RESET "\n", g_test_results.tests_skipped);
    printf("Total time:   %.2f seconds\n", g_test_results.total_time_seconds);
    
    if (g_test_results.tests_failed == 0) {
        printf("\n" COLOR_GREEN "🎉 ALL TESTS PASSED!" COLOR_RESET "\n");
        printf("Claude Agent Communication System is functioning correctly.\n");
    } else {
        printf("\n" COLOR_RED "❌ %d TESTS FAILED" COLOR_RESET "\n", g_test_results.tests_failed);
        printf("System may have issues that need attention.\n");
    }
    
    // System health assessment
    double pass_rate = (double)g_test_results.tests_passed / g_test_results.tests_run * 100.0;
    printf("\nSystem Health Score: ");
    
    if (pass_rate >= 90.0) {
        printf(COLOR_GREEN "%.1f%% (EXCELLENT)" COLOR_RESET, pass_rate);
    } else if (pass_rate >= 75.0) {
        printf(COLOR_YELLOW "%.1f%% (GOOD)" COLOR_RESET, pass_rate);
    } else if (pass_rate >= 50.0) {
        printf(COLOR_YELLOW "%.1f%% (NEEDS ATTENTION)" COLOR_RESET, pass_rate);
    } else {
        printf(COLOR_RED "%.1f%% (CRITICAL ISSUES)" COLOR_RESET, pass_rate);
    }
    
    printf("\n");
}

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================

int main(int argc, char* argv[]) {
    printf(COLOR_CYAN);
    printf("===============================================\n");
    printf("  CLAUDE AGENT COMMUNICATION SYSTEM TEST\n");
    printf("  Comprehensive Integration Test Suite\n");
    printf("  Version 1.0 Production\n");
    printf("===============================================\n");
    printf(COLOR_RESET);
    printf("\n");
    
    // Check if running with specific test filter
    const char* test_filter = NULL;
    if (argc > 1) {
        test_filter = argv[1];
        printf("Running tests matching filter: %s\n\n", test_filter);
    }
    
    // Initialize test results
    memset(&g_test_results, 0, sizeof(g_test_results));
    
    printf("Starting test execution...\n\n");
    
    // Run all test cases
    for (int i = 0; test_cases[i].name != NULL; i++) {
        test_case_t* test = &test_cases[i];
        
        // Apply filter if specified
        if (test_filter && strstr(test->name, test_filter) == NULL) {
            continue;
        }
        
        printf(COLOR_BLUE "=== TEST %d: %s ===" COLOR_RESET "\n", i + 1, test->name);
        
        bool result = run_test_with_timeout(test);
        
        // Stop on critical test failure
        if (!result && test->required) {
            printf("\n" COLOR_RED "❌ CRITICAL TEST FAILED - STOPPING TEST SUITE" COLOR_RESET "\n");
            printf("Test '%s' is required for system functionality.\n", test->name);
            g_test_results.tests_failed++;
            break;
        }
        
        printf("\n");
    }
    
    // Print final summary
    print_test_summary();
    
    // Return appropriate exit code
    return (g_test_results.tests_failed == 0) ? 0 : 1;
}