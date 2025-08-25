#!/bin/bash

# GitHub Sync Script for claude-backups
# Automatically handles authentication and syncs entire repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
REPO_DIR="/home/ubuntu/Downloads/claude-backups"
REMOTE_REPO="https://github.com/SWORDIntel/claude-backups"
LOG_FILE="$REPO_DIR/logs/github-sync-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory if it doesn't exist
mkdir -p "$REPO_DIR/logs"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if gh CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed!"
        print_status "Installing GitHub CLI..."
        
        # Install GitHub CLI
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y gh
        elif command -v brew &> /dev/null; then
            brew install gh
        else
            print_error "Cannot install GitHub CLI. Please install manually."
            exit 1
        fi
    else
        print_success "GitHub CLI is installed"
    fi
}

# Function to check GitHub authentication
check_gh_auth() {
    print_status "Checking GitHub authentication..."
    
    if gh auth status &> /dev/null; then
        print_success "Already authenticated with GitHub"
        
        # Show current auth info
        echo -e "\n${BLUE}Current GitHub authentication:${NC}"
        gh auth status
        echo ""
        return 0
    else
        print_warning "Not authenticated with GitHub"
        return 1
    fi
}

# Function to authenticate with GitHub
authenticate_github() {
    print_status "Starting GitHub authentication process..."
    
    echo -e "\n${YELLOW}Please choose your authentication method:${NC}"
    echo "1) Browser authentication (recommended)"
    echo "2) Token authentication"
    
    read -p "Enter choice (1 or 2): " auth_choice
    
    case $auth_choice in
        1)
            print_status "Opening browser for authentication..."
            gh auth login --web --git-protocol https --hostname github.com
            ;;
        2)
            print_status "Using token authentication..."
            gh auth login --with-token --git-protocol https --hostname github.com
            ;;
        *)
            print_error "Invalid choice. Defaulting to browser authentication..."
            gh auth login --web --git-protocol https --hostname github.com
            ;;
    esac
    
    # Verify authentication worked
    if gh auth status &> /dev/null; then
        print_success "GitHub authentication successful!"
        gh auth status
    else
        print_error "GitHub authentication failed!"
        exit 1
    fi
}

# Function to setup git configuration
setup_git_config() {
    print_status "Setting up Git configuration..."
    
    # Check if git user is configured
    if ! git config --global user.name &> /dev/null; then
        print_status "Setting up Git user configuration..."
        
        # Get GitHub user info
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
        GH_EMAIL=$(gh api user --jq '.email' 2>/dev/null || echo "")
        
        if [ -n "$GH_USER" ]; then
            git config --global user.name "$GH_USER"
            print_success "Set Git username to: $GH_USER"
        else
            read -p "Enter your Git username: " git_username
            git config --global user.name "$git_username"
        fi
        
        if [ -n "$GH_EMAIL" ] && [ "$GH_EMAIL" != "null" ]; then
            git config --global user.email "$GH_EMAIL"
            print_success "Set Git email to: $GH_EMAIL"
        else
            read -p "Enter your Git email: " git_email
            git config --global user.email "$git_email"
        fi
    else
        print_success "Git user configuration already exists"
    fi
}

# Function to check and setup remote
setup_remote() {
    print_status "Checking Git remote configuration..."
    
    cd "$REPO_DIR"
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        print_status "Initializing Git repository..."
        git init
    fi
    
    # Check if remote exists
    if git remote get-url origin &> /dev/null; then
        CURRENT_REMOTE=$(git remote get-url origin)
        print_status "Current remote: $CURRENT_REMOTE"
        
        # Update remote if it's not correct
        if [ "$CURRENT_REMOTE" != "$REMOTE_REPO" ]; then
            print_status "Updating remote URL..."
            git remote set-url origin "$REMOTE_REPO"
        fi
    else
        print_status "Adding remote origin..."
        git remote add origin "$REMOTE_REPO"
    fi
    
    print_success "Remote configured: $REMOTE_REPO"
}

# Function to sync repository
sync_repository() {
    print_status "Starting repository sync..."
    
    cd "$REPO_DIR"
    
    # Fetch latest changes
    print_status "Fetching latest changes from remote..."
    git fetch origin || print_warning "Fetch failed - repository might be empty"
    
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    
    if [ -z "$CURRENT_BRANCH" ]; then
        print_status "Creating initial branch..."
        git checkout -b main
    else
        print_status "Current branch: $CURRENT_BRANCH"
    fi
    
    # Stage all changes
    print_status "Staging all changes..."
    git add -A
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        print_status "No changes to commit"
    else
        # Show what's being committed
        print_status "Changes to be committed:"
        git diff --staged --name-status | head -20
        if [ $(git diff --staged --name-only | wc -l) -gt 20 ]; then
            echo "... and $(($(git diff --staged --name-only | wc -l) - 20)) more files"
        fi
        
        # Commit changes
        COMMIT_MSG="Auto-sync: $(date '+%Y-%m-%d %H:%M:%S') - $(git diff --staged --name-only | wc -l) files updated"
        print_status "Committing changes: $COMMIT_MSG"
        git commit -m "$COMMIT_MSG"
    fi
    
    # Push to remote
    print_status "Pushing changes to remote repository..."
    
    # Check if remote branch exists
    if git ls-remote --heads origin main | grep -q "main"; then
        git push origin main
    else
        print_status "Creating remote branch..."
        git push -u origin main
    fi
    
    print_success "Repository sync completed successfully!"
}

# Function to show repository status
show_status() {
    print_status "Repository Status:"
    echo -e "\n${BLUE}Git Status:${NC}"
    git status --short
    
    echo -e "\n${BLUE}Recent Commits:${NC}"
    git log --oneline -5
    
    echo -e "\n${BLUE}Remote Information:${NC}"
    git remote -v
    
    echo -e "\n${BLUE}Branch Information:${NC}"
    git branch -va
}

# Main execution
main() {
    echo -e "${GREEN}GitHub Repository Sync Script${NC}"
    echo -e "${GREEN}==============================${NC}\n"
    
    print_status "Starting sync process for: $REPO_DIR"
    print_status "Target repository: $REMOTE_REPO"
    print_status "Log file: $LOG_FILE"
    
    # Check prerequisites
    check_gh_cli
    
    # Handle authentication
    if ! check_gh_auth; then
        authenticate_github
    fi
    
    # Setup git configuration
    setup_git_config
    
    # Setup remote repository
    setup_remote
    
    # Sync repository
    sync_repository
    
    # Show final status
    show_status
    
    print_success "All operations completed successfully!"
    echo -e "\n${YELLOW}Tip: You can run this script anytime to sync your changes${NC}"
    echo -e "${YELLOW}Log file saved to: $LOG_FILE${NC}"
}

# Handle script arguments
case "${1:-}" in
    --status|-s)
        cd "$REPO_DIR"
        show_status
        ;;
    --help|-h)
        echo "GitHub Sync Script for claude-backups"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --status, -s    Show repository status only"
        echo "  --help, -h      Show this help message"
        echo "  (no args)       Run full sync process"
        echo ""
        ;;
    *)
        main
        ;;
esac