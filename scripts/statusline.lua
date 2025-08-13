-- God-tier statusline with comprehensive project repo checking
-- Neovim configuration for advanced technical environments

local M = {}

-- Git status cache for performance
local git_cache = {
  branch = "",
  status = "",
  ahead = 0,
  behind = 0,
  stashed = 0,
  last_update = 0,
  cache_timeout = 1000 -- 1 second
}

-- Project health indicators
local health_indicators = {
  ci_status = "unknown",
  test_coverage = 0,
  build_status = "unknown",
  lint_errors = 0,
  security_issues = 0,
  performance_score = 0
}

-- Performance monitoring
local perf_monitor = {
  git_cmd_time = 0,
  file_check_time = 0,
  total_update_time = 0
}

-- Execute shell command with timeout and error handling
local function exec_cmd(cmd, timeout)
  timeout = timeout or 1000
  local start_time = vim.loop.hrtime()
  
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then return "" end
  
  local result = handle:read("*a") or ""
  handle:close()
  
  perf_monitor.git_cmd_time = (vim.loop.hrtime() - start_time) / 1000000
  return result:gsub("%s+$", "")
end

-- Fast git status check with caching
local function get_git_status()
  local current_time = vim.loop.hrtime() / 1000000
  
  if current_time - git_cache.last_update < git_cache.cache_timeout then
    return git_cache
  end
  
  local start_time = vim.loop.hrtime()
  
  -- Check if in git repo
  local git_dir = exec_cmd("git rev-parse --git-dir")
  if git_dir == "" then
    return { branch = "", status = "", in_repo = false }
  end
  
  -- Get branch name
  git_cache.branch = exec_cmd("git symbolic-ref --short HEAD") or 
                     exec_cmd("git rev-parse --short HEAD") or "detached"
  
  -- Get status counts efficiently
  local status_output = exec_cmd("git status --porcelain=v1")
  local modified, added, deleted, untracked = 0, 0, 0, 0
  
  for line in status_output:gmatch("[^\r\n]+") do
    local x, y = line:sub(1,1), line:sub(2,2)
    if x == "M" or y == "M" then modified = modified + 1 end
    if x == "A" or y == "A" then added = added + 1 end
    if x == "D" or y == "D" then deleted = deleted + 1 end
    if x == "?" then untracked = untracked + 1 end
  end
  
  -- Get ahead/behind counts
  local tracking = exec_cmd("git status -b --porcelain=v1 | head -1")
  git_cache.ahead = tonumber(tracking:match("ahead (%d+)")) or 0
  git_cache.behind = tonumber(tracking:match("behind (%d+)")) or 0
  
  -- Check stash
  git_cache.stashed = tonumber(exec_cmd("git stash list | wc -l")) or 0
  
  -- Build status string
  local status_parts = {}
  if modified > 0 then table.insert(status_parts, "~" .. modified) end
  if added > 0 then table.insert(status_parts, "+" .. added) end
  if deleted > 0 then table.insert(status_parts, "-" .. deleted) end
  if untracked > 0 then table.insert(status_parts, "?" .. untracked) end
  
  git_cache.status = table.concat(status_parts, " ")
  git_cache.last_update = current_time
  git_cache.in_repo = true
  
  perf_monitor.total_update_time = (vim.loop.hrtime() - start_time) / 1000000
  
  return git_cache
end

-- Check CI/CD status from common files
local function get_ci_status()
  local ci_files = {
    ".github/workflows/*.yml",
    ".github/workflows/*.yaml", 
    ".gitlab-ci.yml",
    "Jenkinsfile",
    ".travis.yml",
    "circle.yml"
  }
  
  for _, pattern in ipairs(ci_files) do
    local files = exec_cmd("ls " .. pattern)
    if files ~= "" then
      -- Check for common failure indicators in logs
      local status_file = ".ci_status"
      if vim.fn.filereadable(status_file) == 1 then
        local content = vim.fn.readfile(status_file)[1] or "unknown"
        health_indicators.ci_status = content
        return content
      end
      health_indicators.ci_status = "configured"
      return "configured"
    end
  end
  
  health_indicators.ci_status = "none"
  return "none"
end

-- Check test coverage
local function get_test_coverage()
  local coverage_files = {
    "coverage.xml",
    "coverage.json", 
    "coverage/index.html",
    ".coverage",
    "pytest_cache/coverage.xml"
  }
  
  for _, file in ipairs(coverage_files) do
    if vim.fn.filereadable(file) == 1 then
      -- Extract coverage percentage (simplified)
      local content = exec_cmd("grep -o '[0-9]\\+%' " .. file .. " | head -1")
      local percentage = tonumber(content:match("(%d+)%%")) or 0
      health_indicators.test_coverage = percentage
      return percentage
    end
  end
  
  health_indicators.test_coverage = 0
  return 0
end

-- Check linting status
local function get_lint_status()
  local lint_configs = {
    ".eslintrc.*",
    "pyproject.toml",
    ".pylintrc", 
    "flake8.cfg",
    ".golangci.yml"
  }
  
  for _, config in ipairs(lint_configs) do
    local files = exec_cmd("ls " .. config)
    if files ~= "" then
      -- Quick lint check if possible
      local errors = 0
      if config:match("eslint") then
        errors = tonumber(exec_cmd("npx eslint . --format json | jq '.[] | .errorCount' | paste -sd+ | bc")) or 0
      elseif config:match("py") then
        errors = tonumber(exec_cmd("flake8 --statistics 2>/dev/null | tail -1 | awk '{print $1}'")) or 0
      end
      health_indicators.lint_errors = errors
      return errors
    end
  end
  
  health_indicators.lint_errors = 0
  return 0
end

-- Check security issues
local function get_security_status()
  local security_files = {
    "security-report.json",
    "audit-results.json",
    ".snyk"
  }
  
  for _, file in ipairs(security_files) do
    if vim.fn.filereadable(file) == 1 then
      local issues = tonumber(exec_cmd("grep -c 'severity.*high\\|severity.*critical' " .. file)) or 0
      health_indicators.security_issues = issues
      return issues
    end
  end
  
  -- Quick npm/pip audit if available
  local npm_issues = tonumber(exec_cmd("npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities.total' 2>/dev/null")) or 0
  local pip_issues = tonumber(exec_cmd("pip-audit --format=json 2>/dev/null | jq '.vulnerabilities | length' 2>/dev/null")) or 0
  
  local total_issues = npm_issues + pip_issues
  health_indicators.security_issues = total_issues
  return total_issues
end

-- Get current project context
local function get_project_context()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ":t")
  
  -- Detect project type
  local project_type = "unknown"
  if vim.fn.filereadable("package.json") == 1 then project_type = "node" end
  if vim.fn.filereadable("requirements.txt") == 1 then project_type = "python" end
  if vim.fn.filereadable("Cargo.toml") == 1 then project_type = "rust" end
  if vim.fn.filereadable("go.mod") == 1 then project_type = "go" end
  if vim.fn.filereadable("pom.xml") == 1 then project_type = "java" end
  
  return project_name, project_type
end

-- Performance optimization indicators
local function get_performance_indicators()
  local indicators = {}
  
  -- Build time indicator
  if vim.fn.filereadable("build.log") == 1 then
    local build_time = exec_cmd("tail -1 build.log | grep -o '[0-9]\\+\\.[0-9]\\+s'")
    if build_time ~= "" then
      table.insert(indicators, "⚡" .. build_time)
    end
  end
  
  -- Bundle size indicator
  if vim.fn.isdirectory("dist") == 1 then
    local size = exec_cmd("du -sh dist 2>/dev/null | cut -f1")
    if size ~= "" then
      table.insert(indicators, "📦" .. size)
    end
  end
  
  return table.concat(indicators, " ")
end

-- Color scheme for different states
local colors = {
  git_clean = "#50fa7b",
  git_dirty = "#ffb86c", 
  git_conflict = "#ff5555",
  ci_passing = "#50fa7b",
  ci_failing = "#ff5555",
  ci_unknown = "#6272a4",
  coverage_good = "#50fa7b",
  coverage_medium = "#f1fa8c", 
  coverage_poor = "#ff5555",
  security_clean = "#50fa7b",
  security_issues = "#ff5555",
  performance_good = "#50fa7b",
  performance_poor = "#ff5555"
}

-- Main statusline function
function M.get_statusline()
  local git_status = get_git_status()
  local project_name, project_type = get_project_context()
  
  -- Core components
  local components = {}
  
  -- Project info
  table.insert(components, string.format("🎯 %s [%s]", project_name, project_type))
  
  -- Git information
  if git_status.in_repo then
    local git_color = git_status.status == "" and colors.git_clean or colors.git_dirty
    local git_info = string.format("🔀 %s", git_status.branch)
    
    if git_status.status ~= "" then
      git_info = git_info .. " (" .. git_status.status .. ")"
    end
    
    if git_status.ahead > 0 then
      git_info = git_info .. " ↑" .. git_status.ahead
    end
    
    if git_status.behind > 0 then
      git_info = git_info .. " ↓" .. git_status.behind  
    end
    
    if git_status.stashed > 0 then
      git_info = git_info .. " 📦" .. git_status.stashed
    end
    
    table.insert(components, git_info)
  end
  
  -- CI/CD Status
  local ci_status = get_ci_status()
  if ci_status ~= "none" then
    local ci_icon = ci_status == "passing" and "✅" or 
                   ci_status == "failing" and "❌" or "⚪"
    table.insert(components, ci_icon .. " CI:" .. ci_status)
  end
  
  -- Test Coverage
  local coverage = get_test_coverage()
  if coverage > 0 then
    local coverage_icon = coverage >= 80 and "🟢" or coverage >= 60 and "🟡" or "🔴"
    table.insert(components, coverage_icon .. " COV:" .. coverage .. "%")
  end
  
  -- Lint Status
  local lint_errors = get_lint_status()
  if lint_errors >= 0 then
    local lint_icon = lint_errors == 0 and "✨" or "⚠️"
    table.insert(components, lint_icon .. " LINT:" .. lint_errors)
  end
  
  -- Security Status
  local security_issues = get_security_status()
  if security_issues >= 0 then
    local security_icon = security_issues == 0 and "🔒" or "🚨"
    table.insert(components, security_icon .. " SEC:" .. security_issues)
  end
  
  -- Performance indicators
  local perf_info = get_performance_indicators()
  if perf_info ~= "" then
    table.insert(components, perf_info)
  end
  
  -- Performance monitoring (debug mode)
  if vim.g.statusline_debug then
    table.insert(components, string.format("⏱️ %.1fms", perf_monitor.total_update_time))
  end
  
  return table.concat(components, " │ ")
end

-- Update function to refresh all indicators
function M.update_all()
  get_git_status()
  get_ci_status()
  get_test_coverage()
  get_lint_status()
  get_security_status()
end

-- Setup autocommands for automatic updates
function M.setup()
  vim.api.nvim_create_augroup("StatuslineProjectCheck", { clear = true })
  
  -- Update on file write, buffer enter, and git operations
  vim.api.nvim_create_autocmd(
    { "BufWritePost", "BufEnter", "FocusGained" },
    {
      group = "StatuslineProjectCheck",
      callback = function()
        -- Async update to avoid blocking
        vim.defer_fn(function()
          M.update_all()
          vim.cmd("redrawstatus")
        end, 10)
      end,
    }
  )
  
  -- Periodic update every 30 seconds
  vim.fn.timer_start(30000, function()
    M.update_all()
    vim.cmd("redrawstatus")
  end, { ["repeat"] = -1 })
  
  -- Set the actual statusline
  vim.o.statusline = "%{luaeval('require(\"god_statusline\").get_statusline()')}"
  
  -- Enable debug mode with :StatuslineDebug
  vim.api.nvim_create_user_command("StatuslineDebug", function()
    vim.g.statusline_debug = not vim.g.statusline_debug
    print("Statusline debug:", vim.g.statusline_debug)
  end, {})
  
  -- Force update command
  vim.api.nvim_create_user_command("StatuslineUpdate", function()
    M.update_all()
    vim.cmd("redrawstatus")
    print("Statusline updated")
  end, {})
  
  -- Show detailed project status
  vim.api.nvim_create_user_command("ProjectStatus", function()
    local git_status = get_git_status()
    local project_name, project_type = get_project_context()
    
    print("━━━ PROJECT STATUS ━━━")
    print("Name:", project_name)
    print("Type:", project_type)
    print("Git Branch:", git_status.branch)
    print("Git Status:", git_status.status)
    print("CI Status:", health_indicators.ci_status)
    print("Test Coverage:", health_indicators.test_coverage .. "%")
    print("Lint Errors:", health_indicators.lint_errors)
    print("Security Issues:", health_indicators.security_issues)
    print("Performance (last update):", perf_monitor.total_update_time .. "ms")
  end, {})
end

-- Export module
return M
