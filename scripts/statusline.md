# God-Tier Statusline Setup - Installation Guide

## Neovim Configuration (Primary)

### 1. Install Configuration File
```bash
# Create lua directory if it doesn't exist
mkdir -p ~/.config/nvim/lua

# Save the configuration
curl -o ~/.config/nvim/lua/god_statusline.lua [artifact_url]
# OR manually save the lua artifact as god_statusline.lua
```

### 2. Add to init.lua
```lua
-- ~/.config/nvim/init.lua
require('god_statusline').setup()
```

### 3. Dependencies (Optional but Recommended)
```bash
# For enhanced JSON parsing and performance
npm install -g jq

# For Python projects
pip install flake8 pip-audit

# For Node.js projects  
npm install -g eslint

# For enhanced git performance
git config --global core.preloadindex true
git config --global core.fscache true
```

---

## Alternative Configurations

### Vim (Legacy Support)
```vim
" ~/.vimrc - Simplified version for standard vim
function! GitStatus()
  let l:branch = system('git symbolic-ref --short HEAD 2>/dev/null | tr -d "\n"')
  if l:branch == ""
    return ""
  endif
  
  let l:status = system('git status --porcelain 2>/dev/null | wc -l | tr -d " \n"')
  let l:status_text = l:status > 0 ? ' [' . l:status . ']' : ' [✓]'
  
  return '🔀 ' . l:branch . l:status_text
endfunction

function! ProjectInfo()
  let l:project = fnamemodify(getcwd(), ':t')
  let l:type = 'unknown'
  
  if filereadable('package.json') | let l:type = 'node' | endif
  if filereadable('requirements.txt') | let l:type = 'python' | endif
  if filereadable('Cargo.toml') | let l:type = 'rust' | endif
  if filereadable('go.mod') | let l:type = 'go' | endif
  
  return '🎯 ' . l:project . ' [' . l:type . ']'
endfunction

set statusline=%{ProjectInfo()}\ │\ %{GitStatus()}\ │\ %f\ %m%r%h%w\ %=%l,%c\ %P
set laststatus=2
```

### Tmux Status Bar Integration
```bash
# ~/.tmux.conf - Complement the vim statusline
set -g status-interval 10
set -g status-left-length 50
set -g status-right-length 100

# Custom script for tmux
set -g status-left '#[fg=green]🖥️  #H #[fg=blue]│ #[fg=yellow]#{session_name}'
set -g status-right '#[fg=cyan]🔀 #(cd #{pane_current_path}; git symbolic-ref --short HEAD 2>/dev/null || echo "no git") #[fg=blue]│ #[fg=white]%H:%M'

# Enhanced with project detection
set -g status-right '#[fg=magenta]🎯 #(basename "#{pane_current_path}") #[fg=cyan]🔀 #(cd #{pane_current_path}; git symbolic-ref --short HEAD 2>/dev/null || echo "no git") #[fg=blue]│ #[fg=white]%H:%M'
```

### Shell Integration (Bash/Zsh)
```bash
# ~/.bashrc or ~/.zshrc - Command prompt integration

# Git status function
git_status_prompt() {
  local git_dir=$(git rev-parse --git-dir 2>/dev/null)
  if [ -n "$git_dir" ]; then
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    local status=$(git status --porcelain 2>/dev/null | wc -l)
    local ahead=$(git status -b --porcelain=v1 2>/dev/null | grep -o "ahead [0-9]*" | grep -o "[0-9]*")
    local behind=$(git status -b --porcelain=v1 2>/dev/null | grep -o "behind [0-9]*" | grep -o "[0-9]*")
    
    local git_info="🔀 $branch"
    [ "$status" -gt 0 ] && git_info="$git_info [$status]"
    [ -n "$ahead" ] && git_info="$git_info ↑$ahead"
    [ -n "$behind" ] && git_info="$git_info ↓$behind"
    
    echo "$git_info"
  fi
}

# Project type detection
project_type_prompt() {
  local project=$(basename "$PWD")
  local type="unknown"
  
  [ -f "package.json" ] && type="node"
  [ -f "requirements.txt" ] && type="python"  
  [ -f "Cargo.toml" ] && type="rust"
  [ -f "go.mod" ] && type="go"
  [ -f "pom.xml" ] && type="java"
  
  echo "🎯 $project [$type]"
}

# Enhanced PS1 with project info
export PS1='\[\033[35m\]$(project_type_prompt)\[\033[0m\] │ \[\033[36m\]$(git_status_prompt)\[\033[0m\] │ \[\033[32m\]\u@\h\[\033[0m\]:\[\033[34m\]\w\[\033[0m\]\$ '
```

---

## Performance Optimizations

### Git Configuration
```bash
# Optimize git for large repositories
git config --global core.preloadindex true
git config --global core.fscache true
git config --global gc.auto 0
git config --global index.threads 0

# Enable partial clone for very large repos
git config --global core.partialclonefilter blob:none
```

### System Dependencies
```bash
# Ubuntu/Debian
sudo apt install jq fd-find ripgrep

# macOS
brew install jq fd ripgrep

# Performance monitoring tools
sudo apt install htop iotop

# Git performance tools
sudo apt install git-extras tig
```

### Cache Configuration
```lua
-- Enhanced caching in neovim config
vim.g.git_cache_timeout = 2000  -- Increase for slower systems
vim.g.statusline_update_events = {'BufWritePost', 'FocusGained'}  -- Reduce events
vim.g.statusline_max_components = 8  -- Limit components for performance
```

---

## Monitoring and Debugging

### Performance Monitoring
```bash
# Monitor statusline performance
:StatuslineDebug  " Toggle debug mode in neovim

# Check git performance
time git status --porcelain

# Monitor file system
iostat -x 1 5
```

### Troubleshooting
```bash
# Test individual components
:lua print(require('god_statusline').get_git_status().branch)
:lua print(require('god_statusline').get_ci_status())

# Check dependencies
which jq git node npm pip

# Performance analysis
:lua vim.g.statusline_debug = true
```

### Custom Indicators
```lua
-- Add custom project indicators to god_statusline.lua
local custom_indicators = {
  kubernetes = function()
    if vim.fn.filereadable("k8s/") == 1 then
      return "☸️ k8s"
    end
    return ""
  end,
  
  docker = function()
    if vim.fn.filereadable("Dockerfile") == 1 then
      return "🐳 docker"
    end
    return ""
  end,
  
  terraform = function()
    if vim.fn.filereadable("main.tf") == 1 then
      return "🏗️ tf"
    end
    return ""
  end
}
```

---

## Advanced Features

### CI/CD Integration
```yaml
# .github/workflows/statusline.yml - Update status file
name: Update Statusline Status
on: [push, pull_request]
jobs:
  status:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update CI Status
        run: |
          echo "passing" > .ci_status
          git add .ci_status
          git commit -m "Update CI status" || exit 0
```

### Security Scanning Integration  
```bash
# Add to project scripts
#!/bin/bash
# scripts/security-check.sh
set -e

npm audit --json > security-report.json 2>/dev/null || echo '{"vulnerabilities":{}}' > security-report.json
pip-audit --format=json > security-report-py.json 2>/dev/null || echo '{"vulnerabilities":[]}' > security-report-py.json

# Combine reports
jq -s '.[0].vulnerabilities as $npm | .[1].vulnerabilities as $py | {"total": (($npm | length) + ($py | length))}' security-report.json security-report-py.json > security-summary.json
```

### Project Health Monitoring
```bash
# Add to crontab for automatic updates
# */5 * * * * cd /path/to/project && ./scripts/update-health.sh

#!/bin/bash
# scripts/update-health.sh
cd "$(dirname "$0")/.."

# Update test coverage
if [ -f "pytest.ini" ]; then
  python -m pytest --cov=. --cov-report=json > coverage.json 2>/dev/null || true
fi

# Update performance metrics
if [ -f "package.json" ]; then
  npm run build 2>&1 | grep -o "[0-9.]*s" | tail -1 > build-time.txt || true
fi

# Update lint status  
flake8 --statistics 2>/dev/null | tail -1 > lint-report.txt || true
```

---

## Configuration Variants

### Minimal Setup (Fast)
```lua
-- Minimal god_statusline for performance-critical environments
local function minimal_statusline()
  local branch = vim.fn.system('git symbolic-ref --short HEAD 2>/dev/null'):gsub('\n', '')
  local project = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
  
  if branch == '' then
    return string.format('🎯 %s', project)
  else
    return string.format('🎯 %s │ 🔀 %s', project, branch)
  end
end

vim.o.statusline = "%{luaeval('minimal_statusline()')}"
```

### Maximum Information Setup
```lua
-- Maximum detail version - add to god_statusline.lua
local function get_extended_info()
  local info = {}
  
  -- System load
  local load = vim.fn.system("uptime | grep -o 'load average: [0-9.]*' | cut -d' ' -f3"):gsub('\n', '')
  if load ~= '' then table.insert(info, '📊 ' .. load) end
  
  -- Memory usage (project directory)
  local mem = vim.fn.system("du -sh . 2>/dev/null | cut -f1"):gsub('\n', '')
  if mem ~= '' then table.insert(info, '💾 ' .. mem) end
  
  -- File count
  local files = vim.fn.system("find . -type f | wc -l"):gsub('\n', '')
  if files ~= '' then table.insert(info, '📄 ' .. files) end
  
  return table.concat(info, ' │ ')
end
```

---

## Integration Examples

### LSP Integration
```lua
-- Add to god_statusline.lua for LSP status
local function get_lsp_status()
  local clients = vim.lsp.get_active_clients()
  if #clients == 0 then return "" end
  
  local client_names = {}
  for _, client in ipairs(clients) do
    table.insert(client_names, client.name)
  end
  
  return "🔧 " .. table.concat(client_names, ",")
end
```

### Database Connection Status
```lua
-- Add database connection monitoring
local function get_db_status()
  local status_file = ".db_status"
  if vim.fn.filereadable(status_file) == 1 then
    local status = vim.fn.readfile(status_file)[1] or "unknown"
    local icon = status == "connected" and "🟢" or "🔴"
    return icon .. " DB:" .. status
  end
  return ""
end
```

---

## Success Criteria

Configuration successful when:
- [ ] Statusline updates within 50ms
- [ ] Git status accurate and cached
- [ ] Project type correctly detected
- [ ] CI/CD status displayed when available
- [ ] No performance impact on editor responsiveness
- [ ] All custom indicators functional
- [ ] Debug mode provides timing information

Performance targets:
- Git status check: <20ms
- Full statusline render: <50ms  
- Memory overhead: <5MB
- Update frequency: 1-30 seconds

---

## Maintenance

### Regular Updates
```bash
# Update dependencies monthly
npm update -g eslint jq
pip install --upgrade flake8 pip-audit

# Clean cache quarterly  
rm -rf ~/.cache/nvim/god_statusline/
git gc --aggressive
```

### Monitor Performance
```bash
# Weekly performance check
:StatuslineDebug
# Check timing output
:messages
```
