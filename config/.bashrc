# Claude default output style (set by installer)
export CLAUDE_OUTPUT_STYLE='precision-orchestration'
export CLAUDE_VERBOSE=true

# Claude virtual environment (added by installer)
export CLAUDE_VENV='/home/ubuntu/.local/share/claude/venv'
alias claude-venv='source /home/ubuntu/.local/share/claude/venv/bin/activate'

# Smart GitHub Sync alias that works based on current directory
ghsync() {
    local current_dir=$(pwd)
    local repo_type=""
    local repo_root=""
    local sync_script=""
    
    # Detect repository type based on current directory
    if [[ "$current_dir" == *"/claude-backups"* ]]; then
        repo_type="claude-backups"
        repo_root=$(echo "$current_dir" | sed 's|\(.*claude-backups\).*|\1|')
        sync_script="$repo_root/github-sync.sh"
    elif [[ "$current_dir" == *"/livecd-gen"* ]]; then
        repo_type="livecd-gen"
        repo_root=$(echo "$current_dir" | sed 's|\(.*livecd-gen\).*|\1|')
        sync_script="$repo_root/github-sync.sh"
    else
        echo -e "\033[0;31m[ERROR]\033[0m Unknown repository location: $current_dir"
        echo -e "\033[0;34m[INFO]\033[0m ghsync only works within these directories:"
        echo "  - /home/ubuntu/Downloads/claude-backups (and subdirectories)"
        echo "  - /home/ubuntu/Downloads/livecd-gen (and subdirectories)"
        return 1
    fi
    
    # Check if sync script exists
    if [ ! -f "$sync_script" ]; then
        echo -e "\033[0;31m[ERROR]\033[0m GitHub sync script not found: $sync_script"
        return 1
    fi
    
    # Show info and execute
    echo -e "\033[0;34m[GHSYNC]\033[0m Detected repository: $repo_type"
    echo -e "\033[0;34m[GHSYNC]\033[0m Repository root: $repo_root" 
    echo -e "\033[0;34m[GHSYNC]\033[0m Current directory: $current_dir"
    echo -e "\033[0;34m[GHSYNC]\033[0m Executing: $sync_script"
    echo -e "\033[0;34m================================================\033[0m"
    
    # Change to repo root and execute sync script
    cd "$repo_root" && "$sync_script" "$@"
}

# Load bash aliases if they exist
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi