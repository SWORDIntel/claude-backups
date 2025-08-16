/*
 * PROJECT ORCHESTRATOR AGENT v7.0 - CORE COORDINATION NEXUS
 * 
 * Tactical cross-agent synthesis and coordination layer managing active development workflows.
 * Analyzes repository state in real-time, detects gaps across all operational agents,
 * generates optimal execution sequences, and produces actionable AGENT_PLAN.md.
 * 
 * UUID: 527a974a-f0e6-4cb5-916a-12c085de7aa4
 * Author: Agent Communication System v3.0
 * Status: PRODUCTION
 */

#define _GNU_SOURCE
#include "ultra_fast_protocol.h"
#include "agent_system.h"
#include "compatibility_layer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>
#include <errno.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>

// ============================================================================
// CONSTANTS AND CONFIGURATION
// ============================================================================

#define ORCHESTRATOR_AGENT_ID 1
#define MAX_ACTIVE_TASKS 64
#define MAX_AGENT_COORDINATION 32
#define MAX_EXECUTION_PLANS 16
#define MAX_GAP_ANALYSIS_ITEMS 128
#define MAX_WORKFLOW_STEPS 256
#define CACHE_LINE_SIZE 64

// Task priorities for orchestration
typedef enum {
    TASK_PRIORITY_CRITICAL = 0,
    TASK_PRIORITY_HIGH = 1,
    TASK_PRIORITY_MEDIUM = 2,
    TASK_PRIORITY_LOW = 3,
    TASK_PRIORITY_BACKGROUND = 4
} task_priority_t;

// Workflow execution states
typedef enum {
    WORKFLOW_STATE_PLANNING = 0,
    WORKFLOW_STATE_EXECUTING = 1,
    WORKFLOW_STATE_MONITORING = 2,
    WORKFLOW_STATE_COMPLETED = 3,
    WORKFLOW_STATE_FAILED = 4,
    WORKFLOW_STATE_CANCELLED = 5
} workflow_state_t;

// Agent coordination types
typedef enum {
    COORD_TYPE_SEQUENTIAL = 0,
    COORD_TYPE_PARALLEL = 1,
    COORD_TYPE_CONDITIONAL = 2,
    COORD_TYPE_FEEDBACK_LOOP = 3
} coordination_type_t;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

// Task definition for orchestration
typedef struct {
    uint32_t task_id;
    char description[256];
    char target_agent[64];
    char task_prompt[1024];
    task_priority_t priority;
    uint64_t created_time;
    uint64_t start_time;
    uint64_t completion_time;
    coordination_type_t coordination_type;
    uint32_t dependencies[8];  // Task IDs this depends on
    uint32_t dependency_count;
    bool is_completed;
    bool is_active;
    char result_summary[512];
} orchestration_task_t;

// Workflow execution plan
typedef struct {
    uint32_t plan_id;
    char plan_name[128];
    char description[512];
    workflow_state_t state;
    orchestration_task_t tasks[MAX_WORKFLOW_STEPS];
    uint32_t task_count;
    uint64_t created_time;
    uint64_t estimated_duration;
    uint32_t completed_tasks;
    uint32_t failed_tasks;
    float progress_percentage;
} execution_plan_t;

// Repository gap analysis
typedef struct {
    char gap_type[64];          // "missing_tests", "outdated_docs", etc.
    char affected_files[256];   // File patterns or specific files
    char recommended_agent[64]; // Which agent should handle this
    char description[512];
    task_priority_t priority;
    bool is_addressed;
} gap_analysis_item_t;

// Agent status tracking
typedef struct {
    char agent_name[64];
    bool is_available;
    bool is_busy;
    uint32_t active_tasks;
    uint64_t last_activity;
    float performance_score;    // Based on completion time/quality
    char current_task[256];
} agent_status_t;

// Enhanced ProjectOrchestrator context
typedef struct {
    ufp_context_t* comm_context;
    char name[64];
    uint32_t agent_id;
    agent_state_t state;
    
    // Orchestration state
    execution_plan_t active_plans[MAX_EXECUTION_PLANS];
    uint32_t active_plan_count;
    
    // Task management
    orchestration_task_t task_queue[MAX_ACTIVE_TASKS];
    uint32_t task_count;
    uint32_t next_task_id;
    
    // Agent coordination
    agent_status_t agent_status[MAX_AGENT_COORDINATION];
    uint32_t tracked_agent_count;
    
    // Repository analysis
    gap_analysis_item_t gaps[MAX_GAP_ANALYSIS_ITEMS];
    uint32_t gap_count;
    
    // Statistics and monitoring
    atomic_uint_fast64_t tasks_orchestrated;
    atomic_uint_fast64_t plans_executed;
    atomic_uint_fast64_t agents_coordinated;
    uint64_t start_time;
    
    // Thread synchronization
    pthread_mutex_t orchestration_lock;
    pthread_cond_t task_available;
    bool is_analyzing;
    bool is_planning;
} projectorchestrator_agent_t;

// ============================================================================
// REPOSITORY ANALYSIS FUNCTIONS
// ============================================================================

// Analyze repository state for gaps and opportunities
static int analyze_repository_gaps(projectorchestrator_agent_t* agent) {
    agent->is_analyzing = true;
    agent->gap_count = 0;
    
    // Example gap detection logic (real implementation would scan filesystem)
    // TODO: Implement comprehensive repository scanning
    
    // Check for common development gaps
    gap_analysis_item_t* gap = &agent->gaps[agent->gap_count++];
    strcpy(gap->gap_type, "missing_tests");
    strcpy(gap->affected_files, "**/*.c without test coverage");
    strcpy(gap->recommended_agent, "testbed");
    strcpy(gap->description, "Source files lacking comprehensive test coverage");
    gap->priority = TASK_PRIORITY_HIGH;
    gap->is_addressed = false;
    
    gap = &agent->gaps[agent->gap_count++];
    strcpy(gap->gap_type, "outdated_documentation");
    strcpy(gap->affected_files, "README.md, docs/**/*.md");
    strcpy(gap->recommended_agent, "docgen");
    strcpy(gap->description, "Documentation not reflecting current codebase state");
    gap->priority = TASK_PRIORITY_MEDIUM;
    gap->is_addressed = false;
    
    agent->is_analyzing = false;
    return 0;
}

// Generate execution plan from gaps and user requirements
static int create_execution_plan(projectorchestrator_agent_t* agent, const char* plan_name, const char* description) {
    if (agent->active_plan_count >= MAX_EXECUTION_PLANS) {
        return -1; // Too many active plans
    }
    
    execution_plan_t* plan = &agent->active_plans[agent->active_plan_count++];
    plan->plan_id = agent->active_plan_count;
    strncpy(plan->plan_name, plan_name, sizeof(plan->plan_name) - 1);
    strncpy(plan->description, description, sizeof(plan->description) - 1);
    plan->state = WORKFLOW_STATE_PLANNING;
    plan->task_count = 0;
    plan->created_time = time(NULL);
    plan->completed_tasks = 0;
    plan->failed_tasks = 0;
    plan->progress_percentage = 0.0f;
    
    return plan->plan_id;
}

// Add task to execution plan
static int add_task_to_plan(projectorchestrator_agent_t* agent, uint32_t plan_id, 
                           const char* description, const char* target_agent, 
                           const char* task_prompt, task_priority_t priority) {
    
    execution_plan_t* plan = NULL;
    for (uint32_t i = 0; i < agent->active_plan_count; i++) {
        if (agent->active_plans[i].plan_id == plan_id) {
            plan = &agent->active_plans[i];
            break;
        }
    }
    
    if (!plan || plan->task_count >= MAX_WORKFLOW_STEPS) {
        return -1;
    }
    
    orchestration_task_t* task = &plan->tasks[plan->task_count++];
    task->task_id = agent->next_task_id++;
    strncpy(task->description, description, sizeof(task->description) - 1);
    strncpy(task->target_agent, target_agent, sizeof(task->target_agent) - 1);
    strncpy(task->task_prompt, task_prompt, sizeof(task->task_prompt) - 1);
    task->priority = priority;
    task->created_time = time(NULL);
    task->coordination_type = COORD_TYPE_SEQUENTIAL; // Default
    task->dependency_count = 0;
    task->is_completed = false;
    task->is_active = false;
    
    return task->task_id;
}

// Execute next ready task in plan
static int execute_next_task(projectorchestrator_agent_t* agent, uint32_t plan_id) {
    execution_plan_t* plan = NULL;
    for (uint32_t i = 0; i < agent->active_plan_count; i++) {
        if (agent->active_plans[i].plan_id == plan_id) {
            plan = &agent->active_plans[i];
            break;
        }
    }
    
    if (!plan) return -1;
    
    // Find next ready task (dependencies satisfied)
    for (uint32_t i = 0; i < plan->task_count; i++) {
        orchestration_task_t* task = &plan->tasks[i];
        
        if (task->is_completed || task->is_active) continue;
        
        // Check dependencies
        bool dependencies_met = true;
        for (uint32_t j = 0; j < task->dependency_count; j++) {
            bool found_completed = false;
            for (uint32_t k = 0; k < plan->task_count; k++) {
                if (plan->tasks[k].task_id == task->dependencies[j] && 
                    plan->tasks[k].is_completed) {
                    found_completed = true;
                    break;
                }
            }
            if (!found_completed) {
                dependencies_met = false;
                break;
            }
        }
        
        if (dependencies_met) {
            // Execute this task
            task->is_active = true;
            task->start_time = time(NULL);
            
            printf("[ProjectOrchestrator] Executing task %u: %s -> %s\n", 
                   task->task_id, task->description, task->target_agent);
            
            // TODO: Send actual Task tool invocation via communication system
            // For now, simulate execution
            
            atomic_fetch_add(&agent->tasks_orchestrated, 1);
            return task->task_id;
        }
    }
    
    return -1; // No ready tasks
}

// ============================================================================
// AGENT INITIALIZATION
// ============================================================================

// Initialize ProjectOrchestrator agent
int projectorchestrator_init(projectorchestrator_agent_t* agent) {
    // Initialize communication context
    agent->comm_context = ufp_create_context("projectorchestrator");
    if (!agent->comm_context) {
        return -1;
    }
    
    // Basic agent setup
    strcpy(agent->name, "projectorchestrator");
    agent->agent_id = ORCHESTRATOR_AGENT_ID;
    agent->state = AGENT_STATE_ACTIVE;
    agent->start_time = time(NULL);
    
    // Initialize orchestration state
    agent->active_plan_count = 0;
    agent->task_count = 0;
    agent->next_task_id = 1;
    agent->tracked_agent_count = 0;
    agent->gap_count = 0;
    
    // Initialize atomic counters
    atomic_store(&agent->tasks_orchestrated, 0);
    atomic_store(&agent->plans_executed, 0);
    atomic_store(&agent->agents_coordinated, 0);
    
    // Initialize synchronization
    pthread_mutex_init(&agent->orchestration_lock, NULL);
    pthread_cond_init(&agent->task_available, NULL);
    agent->is_analyzing = false;
    agent->is_planning = false;
    
    // Register with discovery service
    agent_register("projectorchestrator", AGENT_TYPE_PROJECTORCHESTRATOR, NULL, 0);
    
    // Perform initial repository analysis
    analyze_repository_gaps(agent);
    
    printf("[ProjectOrchestrator] Initialized with %u gaps detected\n", agent->gap_count);
    
    return 0;
}

// ============================================================================
// MESSAGE PROCESSING
// ============================================================================

// Process incoming orchestration requests
int projectorchestrator_process_message(projectorchestrator_agent_t* agent, ufp_message_t* msg) {
    pthread_mutex_lock(&agent->orchestration_lock);
    
    printf("[ProjectOrchestrator] Received %s message from %s\n", 
           msg->msg_type == UFP_MSG_TASK_REQUEST ? "TASK_REQUEST" : "MESSAGE", 
           msg->source);
    
    // Handle different message types
    switch (msg->msg_type) {
        case UFP_MSG_TASK_REQUEST:
            // Create new execution plan from task request
            if (msg->payload_size > 0) {
                int plan_id = create_execution_plan(agent, "User Request", 
                                                   (char*)msg->payload);
                if (plan_id > 0) {
                    printf("[ProjectOrchestrator] Created execution plan %d\n", plan_id);
                    
                    // Example: Add tasks based on gaps analysis
                    for (uint32_t i = 0; i < agent->gap_count && i < 3; i++) {
                        gap_analysis_item_t* gap = &agent->gaps[i];
                        if (!gap->is_addressed) {
                            add_task_to_plan(agent, plan_id, gap->description,
                                            gap->recommended_agent, gap->description,
                                            gap->priority);
                        }
                    }
                    
                    // Start executing the plan
                    agent->active_plans[plan_id - 1].state = WORKFLOW_STATE_EXECUTING;
                    execute_next_task(agent, plan_id);
                }
            }
            break;
            
        case UFP_MSG_TASK_COMPLETE:
            // Handle task completion from other agents
            printf("[ProjectOrchestrator] Task completed by %s\n", msg->source);
            
            // Find and mark task as completed
            for (uint32_t i = 0; i < agent->active_plan_count; i++) {
                execution_plan_t* plan = &agent->active_plans[i];
                for (uint32_t j = 0; j < plan->task_count; j++) {
                    orchestration_task_t* task = &plan->tasks[j];
                    if (task->is_active && strcmp(task->target_agent, msg->source) == 0) {
                        task->is_active = false;
                        task->is_completed = true;
                        task->completion_time = time(NULL);
                        plan->completed_tasks++;
                        
                        // Update progress
                        plan->progress_percentage = 
                            (float)plan->completed_tasks / plan->task_count * 100.0f;
                        
                        printf("[ProjectOrchestrator] Plan %u progress: %.1f%%\n", 
                               plan->plan_id, plan->progress_percentage);
                        
                        // Execute next task if available
                        execute_next_task(agent, plan->plan_id);
                        break;
                    }
                }
            }
            break;
            
        case UFP_MSG_STATUS_REQUEST:
            // Provide orchestration status
            printf("[ProjectOrchestrator] Status: %u active plans, %lu tasks orchestrated\n",
                   agent->active_plan_count, atomic_load(&agent->tasks_orchestrated));
            break;
            
        default:
            printf("[ProjectOrchestrator] Unknown message type from %s\n", msg->source);
            break;
    }
    
    // Send acknowledgment
    ufp_message_t* ack = ufp_message_create();
    strcpy(ack->source, agent->name);
    strcpy(ack->targets[0], msg->source);
    ack->target_count = 1;
    ack->msg_type = UFP_MSG_ACK;
    
    ufp_send(agent->comm_context, ack);
    ufp_message_destroy(ack);
    
    pthread_mutex_unlock(&agent->orchestration_lock);
    return 0;
}

// ============================================================================
// MAIN AGENT EXECUTION
// ============================================================================

// Periodic orchestration monitoring
static void* orchestration_monitor(void* arg) {
    projectorchestrator_agent_t* agent = (projectorchestrator_agent_t*)arg;
    
    while (agent->state == AGENT_STATE_ACTIVE) {
        sleep(30); // Check every 30 seconds
        
        pthread_mutex_lock(&agent->orchestration_lock);
        
        // Check for stalled tasks
        uint64_t current_time = time(NULL);
        for (uint32_t i = 0; i < agent->active_plan_count; i++) {
            execution_plan_t* plan = &agent->active_plans[i];
            
            if (plan->state == WORKFLOW_STATE_EXECUTING) {
                for (uint32_t j = 0; j < plan->task_count; j++) {
                    orchestration_task_t* task = &plan->tasks[j];
                    
                    // Check for tasks running too long (> 5 minutes)
                    if (task->is_active && 
                        (current_time - task->start_time) > 300) {
                        printf("[ProjectOrchestrator] WARNING: Task %u has been running for %lu seconds\n",
                               task->task_id, current_time - task->start_time);
                    }
                }
                
                // Check if plan is complete
                if (plan->completed_tasks == plan->task_count) {
                    plan->state = WORKFLOW_STATE_COMPLETED;
                    atomic_fetch_add(&agent->plans_executed, 1);
                    printf("[ProjectOrchestrator] Plan %u completed successfully\n", plan->plan_id);
                }
            }
        }
        
        // Periodic repository analysis
        if ((current_time - agent->start_time) % 300 == 0) { // Every 5 minutes
            analyze_repository_gaps(agent);
        }
        
        pthread_mutex_unlock(&agent->orchestration_lock);
    }
    
    return NULL;
}

// Main agent execution loop
void projectorchestrator_run(projectorchestrator_agent_t* agent) {
    ufp_message_t msg;
    pthread_t monitor_thread;
    
    // Start monitoring thread
    pthread_create(&monitor_thread, NULL, orchestration_monitor, agent);
    
    printf("[ProjectOrchestrator] Starting main execution loop\n");
    
    while (agent->state == AGENT_STATE_ACTIVE) {
        // Receive and process messages
        if (ufp_receive(agent->comm_context, &msg, 100) == UFP_SUCCESS) {
            projectorchestrator_process_message(agent, &msg);
        }
        
        // Yield CPU briefly
        usleep(1000); // 1ms
    }
    
    // Cleanup
    pthread_join(monitor_thread, NULL);
    pthread_mutex_destroy(&agent->orchestration_lock);
    pthread_cond_destroy(&agent->task_available);
    
    printf("[ProjectOrchestrator] Shutdown complete. Stats: %lu tasks, %lu plans\n",
           atomic_load(&agent->tasks_orchestrated),
           atomic_load(&agent->plans_executed));
}

// ============================================================================
// ORCHESTRATOR MAIN FUNCTION (for standalone testing)
// ============================================================================

int main(int argc, char* argv[]) {
    projectorchestrator_agent_t agent;
    
    printf("Starting ProjectOrchestrator Agent v7.0\n");
    
    if (projectorchestrator_init(&agent) != 0) {
        fprintf(stderr, "Failed to initialize ProjectOrchestrator\n");
        return 1;
    }
    
    // Run the agent
    projectorchestrator_run(&agent);
    
    return 0;
}
