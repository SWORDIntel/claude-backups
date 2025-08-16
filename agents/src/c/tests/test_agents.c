/*
 * INTEGRATED AGENT SYSTEM TEST
 * 
 * Comprehensive test of Director, Project Orchestrator, and Architect agents
 * working together with the coordination system.
 * 
 * Author: Agent Communication System  
 * Version: 1.0 Production
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

// Test mode defines
#define DIRECTOR_TEST_MODE
#define ORCHESTRATOR_TEST_MODE  
#define ARCHITECT_TEST_MODE

// Include agent implementations
#include "director_agent.c"
#include "project_orchestrator.c"
#include "architect_agent.c"
#include "agent_coordination.c"

// ============================================================================
// INTEGRATED SYSTEM TEST
// ============================================================================

static void test_coordination_system() {
    printf("\n=== Testing Coordination System ===\n");
    
    // Initialize coordination service
    if (coordination_service_init() != 0) {
        printf("Failed to initialize coordination service\n");
        return;
    }
    
    if (start_coordination_threads() != 0) {
        printf("Failed to start coordination threads\n");
        return;
    }
    
    // Register test agents
    register_agent(1, AGENT_TYPE_DIRECTOR, "Director Agent", "strategic_planning,coordination", "local");
    register_agent(2, AGENT_TYPE_PROJECT_ORCHESTRATOR, "Project Orchestrator", "workflow_management,dag_scheduling", "local");
    register_agent(28, AGENT_TYPE_ARCHITECT, "Architect Agent", "system_analysis,pattern_recognition", "local");
    register_agent(3, AGENT_TYPE_SECURITY, "Security Agent", "vulnerability_scan,risk_assessment", "local");
    register_agent(5, AGENT_TYPE_TESTBED, "Testbed Agent", "unit_testing,validation", "local");
    
    // Update agent states to active
    update_agent_status(1, AGENT_STATE_ACTIVE, 20, 2);
    update_agent_status(2, AGENT_STATE_ACTIVE, 30, 1);
    update_agent_status(28, AGENT_STATE_ACTIVE, 10, 0);
    update_agent_status(3, AGENT_STATE_ACTIVE, 40, 3);
    update_agent_status(5, AGENT_STATE_ACTIVE, 25, 1);
    
    // Test task delegation
    uint32_t delegation1 = delegate_task_to_agent(1, 28, "Analyze system architecture", 
                                                 "project=test_app depth=full", "system_analysis", 30000);
    uint32_t delegation2 = delegate_task_to_agent(1, 3, "Perform security scan", 
                                                 "target=webapp comprehensive=true", "vulnerability_scan", 45000);
    
    printf("Created delegations: %u, %u\n", delegation1, delegation2);
    
    // Simulate delegation completion
    sleep(1);
    complete_task_delegation(delegation1, 0, "Architecture analysis completed successfully");
    complete_task_delegation(delegation2, 0, "Security scan found 2 low-risk issues");
    
    // Test message processing
    enhanced_msg_header_t test_msg;
    init_message_header(&test_msg, MSG_TYPE_PING, 28, 1);
    test_msg.timestamp = get_timestamp_ns();
    test_msg.sequence = generate_sequence_number();
    
    enqueue_message(&test_msg, NULL);
    
    // Let system process messages
    sleep(2);
    
    print_coordination_statistics();
    
    // Cleanup
    coordination_service_cleanup();
}

static void test_director_strategic_decisions() {
    printf("\n=== Testing Director Strategic Decision Engine ===\n");
    
    if (director_service_init() != 0) {
        printf("Failed to initialize director service\n");
        return;
    }
    
    // Create resource pools for realistic testing
    create_resource_pool("Analysis Pool", AGENT_TYPE_ARCHITECT, 2);
    create_resource_pool("Security Pool", AGENT_TYPE_SECURITY, 3);
    create_resource_pool("Test Pool", AGENT_TYPE_TESTBED, 4);
    
    if (start_director_threads() != 0) {
        printf("Failed to start director threads\n");
        return;
    }
    
    // Test strategic decision making
    uint32_t plan1 = director_make_strategic_decision("emergency_security_breach", 
                                                     "Immediate response to security incident");
    uint32_t plan2 = director_make_strategic_decision("build_optimization", 
                                                     "Optimize build pipeline performance");
    uint32_t plan3 = director_make_strategic_decision("comprehensive_system_analysis", 
                                                     "Full system architecture review");
    
    printf("Director created strategic plans: %u, %u, %u\n", plan1, plan2, plan3);
    
    // Start plan execution
    if (plan1 > 0) start_plan_execution(plan1);
    if (plan2 > 0) start_plan_execution(plan2);
    if (plan3 > 0) start_plan_execution(plan3);
    
    // Monitor execution for 10 seconds
    for (int i = 0; i < 10; i++) {
        sleep(1);
        
        if (i % 3 == 0) {
            int health = director_evaluate_system_health();
            printf("System health: %d%%\n", health);
        }
    }
    
    print_director_statistics();
    
    // Cleanup
    director_service_cleanup();
}

static void test_orchestrator_dag_execution() {
    printf("\n=== Testing Project Orchestrator DAG Execution ===\n");
    
    if (orchestrator_service_init() != 0) {
        printf("Failed to initialize orchestrator service\n");
        return;
    }
    
    // Create test project
    uint32_t project_id = create_project("Advanced Web Application", 
                                        "Full-stack application with microservices architecture", 3);
    if (project_id == 0) {
        printf("Failed to create project\n");
        return;
    }
    
    activate_project(project_id);
    
    // Create complex workflow with dependencies
    uint32_t workflow_id = create_workflow(project_id, "Complex DAG Workflow", 
                                         "Multi-stage pipeline with complex dependencies",
                                         STRATEGY_PARALLEL_LIMITED, 4);
    
    if (workflow_id == 0) {
        printf("Failed to create workflow\n");
        return;
    }
    
    // Add tasks with complex dependency relationships
    uint32_t task1 = add_workflow_task(workflow_id, "Requirements Analysis", 
                                      "Analyze project requirements and constraints",
                                      TASK_TYPE_ANALYSIS, PRIORITY_CRITICAL,
                                      28, "requirements_analysis", "analyze_requirements",
                                      "scope=full stakeholders=all", 45000);
    
    uint32_t task2 = add_workflow_task(workflow_id, "Architecture Design", 
                                      "Design system architecture based on requirements",
                                      TASK_TYPE_ANALYSIS, PRIORITY_CRITICAL,
                                      28, "system_design", "design_architecture",
                                      "based_on=requirements patterns=microservices", 60000);
    
    uint32_t task3 = add_workflow_task(workflow_id, "Security Review", 
                                      "Review architecture for security vulnerabilities",
                                      TASK_TYPE_SECURITY, PRIORITY_HIGH,
                                      3, "security_review", "review_architecture",
                                      "depth=comprehensive compliance=required", 40000);
    
    uint32_t task4 = add_workflow_task(workflow_id, "Frontend Development", 
                                      "Develop frontend components",
                                      TASK_TYPE_BUILD, PRIORITY_HIGH,
                                      7, "frontend_dev", "develop_frontend",
                                      "framework=react components=all", 120000);
    
    uint32_t task5 = add_workflow_task(workflow_id, "Backend Development", 
                                      "Develop backend services",
                                      TASK_TYPE_BUILD, PRIORITY_HIGH,
                                      8, "backend_dev", "develop_backend",
                                      "language=python framework=fastapi", 150000);
    
    uint32_t task6 = add_workflow_task(workflow_id, "Integration Testing", 
                                      "Test integration between components",
                                      TASK_TYPE_TEST, PRIORITY_HIGH,
                                      5, "integration_test", "test_integration",
                                      "coverage=full environment=staging", 90000);
    
    uint32_t task7 = add_workflow_task(workflow_id, "Performance Testing", 
                                      "Load and performance testing",
                                      TASK_TYPE_TEST, PRIORITY_NORMAL,
                                      5, "performance_test", "test_performance",
                                      "load=1000_users duration=300s", 180000);
    
    uint32_t task8 = add_workflow_task(workflow_id, "Deployment", 
                                      "Deploy to production environment",
                                      TASK_TYPE_DEPLOY, PRIORITY_CRITICAL,
                                      26, "deployment", "deploy_production",
                                      "environment=prod strategy=blue_green", 60000);
    
    // Create complex DAG dependencies
    add_task_dependency(workflow_id, task2, task1);  // Architecture after requirements
    add_task_dependency(workflow_id, task3, task2);  // Security review after architecture
    add_task_dependency(workflow_id, task4, task2);  // Frontend after architecture
    add_task_dependency(workflow_id, task5, task2);  // Backend after architecture  
    add_task_dependency(workflow_id, task5, task3);  // Backend after security review
    add_task_dependency(workflow_id, task6, task4);  // Integration after frontend
    add_task_dependency(workflow_id, task6, task5);  // Integration after backend
    add_task_dependency(workflow_id, task7, task6);  // Performance after integration
    add_task_dependency(workflow_id, task8, task6);  // Deploy after integration
    add_task_dependency(workflow_id, task8, task7);  // Deploy after performance
    
    printf("Created complex DAG workflow with 8 tasks and dependencies\n");
    
    // Start executor threads
    if (start_orchestrator_threads() != 0) {
        printf("Failed to start orchestrator threads\n");
        return;
    }
    
    // Start workflow execution
    if (start_workflow_execution(workflow_id) != 0) {
        printf("Failed to start workflow execution\n");
        return;
    }
    
    // Monitor DAG execution
    printf("Monitoring DAG execution...\n");
    for (int i = 0; i < 30; i++) {
        sleep(1);
        
        if (i % 5 == 0) {
            print_orchestrator_statistics();
        }
        
        // Check workflow completion
        pthread_rwlock_rdlock(&g_orchestrator->workflows_lock);
        bool workflow_done = false;
        for (uint32_t j = 0; j < MAX_WORKFLOWS; j++) {
            if (g_orchestrator->workflows[j].workflow_id == workflow_id) {
                workflow_state_t state = g_orchestrator->workflows[j].state;
                workflow_done = (state == WORKFLOW_STATE_COMPLETED || state == WORKFLOW_STATE_FAILED);
                if (workflow_done) {
                    printf("DAG workflow completed with state: %s\n",
                           state == WORKFLOW_STATE_COMPLETED ? "SUCCESS" : "FAILED");
                }
                break;
            }
        }
        pthread_rwlock_unlock(&g_orchestrator->workflows_lock);
        
        if (workflow_done) break;
    }
    
    print_orchestrator_statistics();
    
    // Cleanup
    orchestrator_service_cleanup();
}

static void test_architect_analysis() {
    printf("\n=== Testing Architect System Analysis ===\n");
    
    if (architect_service_init() != 0) {
        printf("Failed to initialize architect service\n");
        return;
    }
    
    // Create test analysis projects
    uint32_t project1 = create_architecture_analysis("E-commerce Platform", "/tmp/ecommerce");
    uint32_t project2 = create_architecture_analysis("Microservices API", "/tmp/api-services");
    uint32_t project3 = create_architecture_analysis("Legacy Monolith", "/tmp/legacy-app");
    
    if (project1 == 0 || project2 == 0 || project3 == 0) {
        printf("Failed to create analysis projects\n");
        return;
    }
    
    // Perform comprehensive analyses
    printf("Performing system analyses...\n");
    perform_full_system_analysis(project1);
    perform_full_system_analysis(project2); 
    perform_full_system_analysis(project3);
    
    // Generate detailed reports
    printf("Architecture analysis results:\n");
    print_project_analysis_report(project1);
    print_project_analysis_report(project2);
    
    print_architect_statistics();
    
    // Cleanup
    architect_service_cleanup();
}

// ============================================================================
// MAIN TEST DRIVER
// ============================================================================

int main() {
    printf("Claude Agent System - Integrated Test Suite\n");
    printf("==========================================\n\n");
    
    // Test individual components
    test_coordination_system();
    test_architect_analysis();
    test_director_strategic_decisions();
    test_orchestrator_dag_execution();
    
    // Integrated system test
    printf("\n=== Integrated System Test ===\n");
    
    // Initialize all services
    if (coordination_service_init() != 0 ||
        director_service_init() != 0 ||
        orchestrator_service_init() != 0 ||
        architect_service_init() != 0) {
        printf("Failed to initialize integrated system\n");
        return 1;
    }
    
    start_coordination_threads();
    start_director_threads();
    start_orchestrator_threads();
    
    // Register agents with coordination system
    register_agent(1, AGENT_TYPE_DIRECTOR, "Director", "strategic_planning", "local");
    register_agent(2, AGENT_TYPE_PROJECT_ORCHESTRATOR, "Orchestrator", "workflow_management", "local");
    register_agent(28, AGENT_TYPE_ARCHITECT, "Architect", "system_analysis", "local");
    
    // Create integrated workflow
    uint32_t project_id = create_project("Integrated System Test", "Full system integration test", 5);
    activate_project(project_id);
    
    uint32_t workflow_id = create_workflow(project_id, "Integrated Workflow", 
                                         "Test all agent coordination", STRATEGY_ADAPTIVE, 6);
    
    // Create analysis project
    uint32_t analysis_id = create_architecture_analysis("Integration Test Project", "/tmp/integration");
    
    // Let system run and coordinate
    printf("Running integrated system for 15 seconds...\n");
    for (int i = 0; i < 15; i++) {
        sleep(1);
        
        if (i % 5 == 0) {
            printf("=== System Status at %ds ===\n", i);
            print_coordination_statistics();
            printf("Director Health: %d%%\n", director_evaluate_system_health());
        }
        
        // Trigger some activities
        if (i == 5) {
            perform_full_system_analysis(analysis_id);
        }
        if (i == 10) {
            director_make_strategic_decision("system_optimization", "Optimize integrated system performance");
        }
    }
    
    // Final statistics
    printf("\n=== Final System Statistics ===\n");
    print_coordination_statistics();
    print_director_statistics();
    print_orchestrator_statistics();
    print_architect_statistics();
    
    // Cleanup all services
    coordination_service_cleanup();
    director_service_cleanup();
    orchestrator_service_cleanup();
    architect_service_cleanup();
    
    printf("\nIntegrated system test completed successfully!\n");
    return 0;
}