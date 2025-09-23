#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# CLAUDE HARDCODED PATH MIGRATION TOOL v1.0
#
# Systematically removes ALL hardcoded paths from the claude-backups system
# Makes the entire system truly portable across users and installations
# ════════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Configuration
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/migration-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
VERBOSE=false
FORCE=false

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

log_verbose() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${CYAN}[VERBOSE]${RESET} $1"
}

print_header() {
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════════════════"
    echo -e "$1"
    echo -e "════════════════════════════════════════════════════════════════════════════════${RESET}"
}

create_backup() {
    local file="$1"
    local backup_file="$BACKUP_DIR/$(realpath --relative-to="$PROJECT_ROOT" "$file")"

    mkdir -p "$(dirname "$backup_file")"
    cp "$file" "$backup_file"
    log_verbose "Backed up: $file"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PATH PATTERN DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

detect_hardcoded_patterns() {
    local file="$1"
    local patterns_found=()

    # Home directory patterns
    if grep -q "/home/[a-zA-Z0-9_-]\+" "$file" 2>/dev/null; then
        patterns_found+=("USER_HOME")
    fi

    # Project-specific patterns
    if grep -q "claude-backups" "$file" 2>/dev/null; then
        patterns_found+=("PROJECT_NAME")
    fi

    # System paths
    if grep -q "/usr/local\|/usr/bin\|/opt/" "$file" 2>/dev/null; then
        patterns_found+=("SYSTEM_PATHS")
    fi

    # OpenVINO paths
    if grep -q "/opt/openvino" "$file" 2>/dev/null; then
        patterns_found+=("OPENVINO_PATHS")
    fi

    echo "${patterns_found[@]}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# REPLACEMENT STRATEGIES
# ═══════════════════════════════════════════════════════════════════════════════

replace_user_home_patterns() {
    local file="$1"
    local temp_file="$(mktemp)"

    # Replace specific user home patterns
    sed -e 's|/home/john|${CLAUDE_USER_HOME:-$HOME}|g' \
        -e 's|/home/ubuntu|${CLAUDE_USER_HOME:-$HOME}|g' \
        -e 's|/home/[a-zA-Z0-9_-]\+|${CLAUDE_USER_HOME:-$HOME}|g' \
        "$file" > "$temp_file"

    if [[ "$DRY_RUN" == "false" ]]; then
        mv "$temp_file" "$file"
    else
        rm "$temp_file"
    fi
}

replace_project_paths() {
    local file="$1"
    local temp_file="$(mktemp)"

    # Replace project-specific paths
    sed -e 's|$HOME/claude-backups|${CLAUDE_PROJECT_ROOT}|g' \
        -e 's|$HOME/Downloads/claude-backups|${CLAUDE_PROJECT_ROOT}|g' \
        -e 's|$HOME/Documents/claude-backups|${CLAUDE_PROJECT_ROOT}|g' \
        -e 's|"claude-backups"|"${CLAUDE_PROJECT_ROOT##*/}"|g' \
        -e 's|/claude-backups/|/${CLAUDE_PROJECT_ROOT##*/}/|g' \
        "$file" > "$temp_file"

    if [[ "$DRY_RUN" == "false" ]]; then
        mv "$temp_file" "$file"
    else
        rm "$temp_file"
    fi
}

replace_system_paths() {
    local file="$1"
    local temp_file="$(mktemp)"

    # Replace system paths with dynamic detection
    sed -e 's|/usr/local/bin|${CLAUDE_SYSTEM_BIN:-/usr/local/bin}|g' \
        -e 's|/usr/bin|${CLAUDE_SYSTEM_BIN:-/usr/bin}|g' \
        -e 's|$HOME/.local/bin|${CLAUDE_USER_BIN:-$HOME/.local/bin}|g' \
        "$file" > "$temp_file"

    if [[ "$DRY_RUN" == "false" ]]; then
        mv "$temp_file" "$file"
    else
        rm "$temp_file"
    fi
}

replace_openvino_paths() {
    local file="$1"
    local temp_file="$(mktemp)"

    # Replace OpenVINO paths
    sed -e 's|/opt/openvino|${OPENVINO_ROOT:-/opt/openvino}|g' \
        "$file" > "$temp_file"

    if [[ "$DRY_RUN" == "false" ]]; then
        mv "$temp_file" "$file"
    else
        rm "$temp_file"
    fi
}

add_path_resolver_integration() {
    local file="$1"
    local file_type="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    case "$file_type" in
        "shell")
            # Add path resolver source to shell scripts
            if ! grep -q "claude-path-resolver.sh" "$file"; then
                local temp_file="$(mktemp)"
                {
                    echo "# ═══════════════════════════════════════════════════════════════════════════════"
                    echo "# CLAUDE PORTABLE PATH INTEGRATION"
                    echo "# ═══════════════════════════════════════════════════════════════════════════════"
                    echo ""
                    echo "# Source path resolver if available"
                    echo 'SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")"'
                    echo 'for resolver in "$SCRIPT_DIR/claude-path-resolver.sh" "$SCRIPT_DIR/../scripts/claude-path-resolver.sh" "./scripts/claude-path-resolver.sh"; do'
                    echo '    if [[ -f "$resolver" ]]; then'
                    echo '        source "$resolver" init'
                    echo '        break'
                    echo '    fi'
                    echo 'done'
                    echo ""
                    cat "$file"
                } > "$temp_file"
                mv "$temp_file" "$file"
            fi
            ;;
        "python")
            # Add Python path resolver import
            if ! grep -q "claude_path_resolver" "$file"; then
                local temp_file="$(mktemp)"
                {
                    head -n 5 "$file"
                    echo ""
                    echo "# Claude Portable Path Integration"
                    echo "import sys"
                    echo "import os"
                    echo "from pathlib import Path"
                    echo ""
                    echo "# Add path resolver to Python path"
                    echo "script_dir = Path(__file__).parent.resolve()"
                    echo "for resolver_path in [script_dir / 'claude_path_resolver.py', script_dir.parent / 'scripts' / 'claude_path_resolver.py']:"
                    echo "    if resolver_path.exists():"
                    echo "        sys.path.insert(0, str(resolver_path.parent))"
                    echo "        try:"
                    echo "            from claude_path_resolver import apply_to_environment"
                    echo "            apply_to_environment()"
                    echo "            break"
                    echo "        except ImportError:"
                    echo "            pass"
                    echo ""
                    tail -n +6 "$file"
                } > "$temp_file"
                mv "$temp_file" "$file"
            fi
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# FILE PROCESSING
# ═══════════════════════════════════════════════════════════════════════════════

process_file() {
    local file="$1"
    local patterns=($(detect_hardcoded_patterns "$file"))

    if [[ ${#patterns[@]} -eq 0 ]]; then
        log_verbose "No hardcoded paths in: $file"
        return 0
    fi

    log_info "Processing: $file (patterns: ${patterns[*]})"

    # Create backup
    create_backup "$file"

    # Apply replacements based on detected patterns
    for pattern in "${patterns[@]}"; do
        case "$pattern" in
            "USER_HOME")
                replace_user_home_patterns "$file"
                ;;
            "PROJECT_NAME")
                replace_project_paths "$file"
                ;;
            "SYSTEM_PATHS")
                replace_system_paths "$file"
                ;;
            "OPENVINO_PATHS")
                replace_openvino_paths "$file"
                ;;
        esac
    done

    # Add path resolver integration
    local file_ext="${file##*.}"
    case "$file_ext" in
        "sh"|"bash")
            add_path_resolver_integration "$file" "shell"
            ;;
        "py")
            add_path_resolver_integration "$file" "python"
            ;;
    esac

    log_success "Updated: $file"
}

scan_and_process_files() {
    local total_files=0
    local processed_files=0

    # Find all relevant files
    local file_patterns=(
        "*.sh"
        "*.py"
        "*.json"
        "*.md"
        "*.yml"
        "*.yaml"
    )

    # Exclude certain directories
    local exclude_dirs=(
        ".git"
        "deprecated"
        "backup"
        "node_modules"
        "__pycache__"
        ".venv"
        "venv"
    )

    print_header "SCANNING FOR FILES WITH HARDCODED PATHS"

    for pattern in "${file_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            # Skip excluded directories
            local skip=false
            for exclude in "${exclude_dirs[@]}"; do
                if [[ "$file" == *"/$exclude/"* ]]; then
                    skip=true
                    break
                fi
            done
            [[ "$skip" == "true" ]] && continue

            # Skip binary files
            if file "$file" | grep -q "binary"; then
                continue
            fi

            ((total_files++))

            local patterns=($(detect_hardcoded_patterns "$file"))
            if [[ ${#patterns[@]} -gt 0 ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "Would process: $file (patterns: ${patterns[*]})"
                else
                    process_file "$file"
                fi
                ((processed_files++))
            fi

        done < <(find "$PROJECT_ROOT" -name "$pattern" -type f -print0)
    done

    log_info "Scanned $total_files files, found hardcoded paths in $processed_files files"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

validate_migrations() {
    print_header "VALIDATING MIGRATIONS"

    local validation_failed=false

    # Check if path resolver exists
    if [[ ! -f "$PROJECT_ROOT/scripts/claude-path-resolver.sh" ]]; then
        log_error "Path resolver not found: $PROJECT_ROOT/scripts/claude-path-resolver.sh"
        validation_failed=true
    fi

    # Check for remaining hardcoded paths
    local remaining_patterns=(
        "/home/john"
        "/home/ubuntu"
        "claude-backups"
    )

    for pattern in "${remaining_patterns[@]}"; do
        local remaining_files=$(find "$PROJECT_ROOT" -type f -name "*.sh" -o -name "*.py" -o -name "*.json" | \
                               xargs grep -l "$pattern" 2>/dev/null || true)

        if [[ -n "$remaining_files" ]]; then
            log_warning "Pattern '$pattern' still found in:"
            echo "$remaining_files" | while read -r file; do
                echo "  - $file"
            done
            validation_failed=true
        fi
    done

    if [[ "$validation_failed" == "true" ]]; then
        log_error "Validation failed - some hardcoded paths remain"
        return 1
    else
        log_success "Validation passed - no hardcoded paths detected"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

show_usage() {
    cat << EOF
Claude Hardcoded Path Migration Tool v1.0

Usage: $0 [OPTIONS]

OPTIONS:
    --dry-run           Show what would be changed without making changes
    --verbose           Enable verbose output
    --force             Force migration without confirmation
    --help              Show this help message

DESCRIPTION:
    This tool systematically removes ALL hardcoded paths from the claude-backups
    system, making it truly portable across different users and installations.

    The tool will:
    1. Scan all shell scripts, Python files, and configuration files
    2. Detect hardcoded paths (user homes, project paths, system paths)
    3. Replace them with dynamic path resolution variables
    4. Add path resolver integration to scripts
    5. Create backups of all modified files
    6. Validate the migration was successful

EXAMPLES:
    $0 --dry-run --verbose    # Preview changes with detailed output
    $0 --force               # Run migration without confirmation
    $0                       # Interactive migration with confirmation

EOF
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_header "CLAUDE HARDCODED PATH MIGRATION TOOL v1.0"

    log_info "Project Root: $PROJECT_ROOT"
    log_info "Backup Directory: $BACKUP_DIR"
    log_info "Dry Run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"

    # Confirmation unless forced or dry run
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        echo ""
        log_warning "This will modify files in your claude-backups installation!"
        log_warning "Backups will be created in: $BACKUP_DIR"
        echo ""
        read -p "Continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Migration cancelled by user"
            exit 0
        fi
    fi

    # Create backup directory
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Created backup directory: $BACKUP_DIR"
    fi

    # Run migration
    scan_and_process_files

    # Validate results
    if [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        validate_migrations

        if [[ $? -eq 0 ]]; then
            log_success "Migration completed successfully!"
            log_info "Backups available in: $BACKUP_DIR"
            echo ""
            log_info "Next steps:"
            log_info "1. Test the system: $PROJECT_ROOT/scripts/claude-path-resolver.sh status"
            log_info "2. Test a wrapper: $PROJECT_ROOT/claude-wrapper-portable.sh --status"
            log_info "3. Update environment variables as needed"
        else
            log_error "Migration completed with warnings - please review the issues above"
            exit 1
        fi
    else
        log_info "Dry run completed - use --force to apply changes"
    fi
}

# Execute main function
main "$@"