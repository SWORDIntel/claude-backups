#ifndef CLAUDE_PATHS_H
#define CLAUDE_PATHS_H

#include <stdlib.h>
#include <string.h>
#include <limits.h>

/**
 * Path Resolution Header for Claude Agent System
 * Provides runtime-initialized path management
 */

static inline const char* get_env_or_default(const char* env_var, const char* default_val) {
    const char* val = getenv(env_var);
    return val ? val : default_val;
}

// Path buffers (initialized at runtime)
static char claude_venv_path[PATH_MAX];
static char claude_toolchain_path[PATH_MAX];
static char claude_obsidian_vault[PATH_MAX];
static char claude_data_home[PATH_MAX];

/**
 * Initialize all path buffers
 * Call once at program startup
 */
static void claude_init_paths(void) {
    const char* data_home_env = getenv("CLAUDE_DATA_HOME");
    const char* home = getenv("HOME");

    // Initialize data home
    if (data_home_env && strlen(data_home_env) > 0) {
        snprintf(claude_data_home, PATH_MAX, "%s", data_home_env);
    } else if (home) {
        snprintf(claude_data_home, PATH_MAX, "%s/.local/share/claude", home);
    } else {
        claude_data_home[0] = '\0';
    }

    // Initialize venv and toolchain paths
    if (strlen(claude_data_home) > 0) {
        snprintf(claude_venv_path, PATH_MAX, "%s/datascience", claude_data_home);
        snprintf(claude_toolchain_path, PATH_MAX, "%s/c-toolchain", claude_data_home);
    } else {
        claude_venv_path[0] = '\0';
        claude_toolchain_path[0] = '\0';
    }

    // Initialize Obsidian vault
    if (home) {
        snprintf(claude_obsidian_vault, PATH_MAX, "%s/Documents/Obsidian/DataScience", home);
    } else {
        claude_obsidian_vault[0] = '\0';
    }
}

// Public accessors
#define VENV_PATH claude_venv_path
#define CUSTOM_TOOLCHAIN_PATH claude_toolchain_path
#define OBSIDIAN_VAULT_PATH claude_obsidian_vault

static inline int claude_path_is_valid(const char* path) {
    return path && strlen(path) > 0;
}

#endif // CLAUDE_PATHS_H
