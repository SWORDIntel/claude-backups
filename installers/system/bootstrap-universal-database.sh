#!/bin/bash
# Universal Database Bootstrap (Simplified for Phase 1)
# Sets up optimization database infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="$HOME/.claude/system/db"

echo "Bootstrapping Universal Optimizer Database..."

# Create database directories
mkdir -p "$DB_DIR"/{data,logs,config,migrations,backups}
echo "✓ Database directories created"

# Check for Docker (optional for full functionality)
if command -v docker >/dev/null 2>&1; then
    echo "✓ Docker available - full database functionality possible"
    
    # Create docker-compose.yml for future use
    cat > "$DB_DIR/docker-compose.yml" << 'EOF'
version: '3.8'
services:
  postgres:
    image: pgvector/pgvector:pg16
    container_name: claude-optimizer-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: claude_optimizer
      POSTGRES_USER: claude_optimizer
      POSTGRES_PASSWORD: secure_password
    ports:
      - "5434:5432"
    volumes:
      - ./data:/var/lib/postgresql/data
      - ./logs:/var/log/postgresql
EOF
    echo "✓ Docker configuration created (not started)"
else
    echo "⚠ Docker not available - using SQLite fallback"
fi

# Create SQLite database for immediate use
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$DB_DIR/optimizer.db" << 'EOF'
CREATE TABLE IF NOT EXISTS optimization_contexts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    context_hash TEXT UNIQUE NOT NULL,
    original_tokens INTEGER NOT NULL,
    optimized_tokens INTEGER NOT NULL,
    reduction_ratio REAL NOT NULL,
    optimization_patterns TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS token_reduction_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rule_name TEXT NOT NULL,
    pattern_regex TEXT NOT NULL,
    replacement TEXT NOT NULL,
    priority INTEGER DEFAULT 100,
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS optimization_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    measured_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_contexts_hash ON optimization_contexts(context_hash);
CREATE INDEX IF NOT EXISTS idx_contexts_reduction ON optimization_contexts(reduction_ratio DESC);
CREATE INDEX IF NOT EXISTS idx_rules_priority ON token_reduction_rules(priority DESC, is_active);
CREATE INDEX IF NOT EXISTS idx_metrics_name_time ON optimization_metrics(metric_name, measured_at DESC);

-- Insert default rules
INSERT OR IGNORE INTO token_reduction_rules (rule_name, pattern_regex, replacement, priority) VALUES
('Remove extra whitespace', '\s+', ' ', 10),
('Compress JSON', ':\s+', ':', 20),
('Remove trailing commas', ',\s*}', '}', 30);
EOF
    echo "✓ SQLite database initialized"
else
    echo "⚠ SQLite not available - database will be created on first use"
fi

# Copy schema files if available
if [[ -f "$SCRIPT_DIR/database/sql/final_comprehensive_schema.sql" ]]; then
    cp "$SCRIPT_DIR/database/sql/final_comprehensive_schema.sql" "$DB_DIR/migrations/001_schema.sql"
    echo "✓ Schema migration prepared"
fi

# Create status script
cat > "$DB_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "Claude Universal Optimizer Database Status"
echo "=========================================="

DB_DIR="$(dirname "$0")"

if [[ -f "$DB_DIR/optimizer.db" ]]; then
    echo "✓ SQLite database exists"
    if command -v sqlite3 >/dev/null 2>&1; then
        CONTEXTS=$(sqlite3 "$DB_DIR/optimizer.db" "SELECT COUNT(*) FROM optimization_contexts;" 2>/dev/null || echo 0)
        RULES=$(sqlite3 "$DB_DIR/optimizer.db" "SELECT COUNT(*) FROM token_reduction_rules WHERE is_active=1;" 2>/dev/null || echo 0)
        echo "  Optimization contexts: $CONTEXTS"
        echo "  Active rules: $RULES"
    fi
else
    echo "✗ SQLite database not found"
fi

if command -v docker >/dev/null 2>&1; then
    if docker ps | grep -q claude-optimizer-db; then
        echo "✓ Docker PostgreSQL running"
    else
        echo "⚠ Docker PostgreSQL not running (optional)"
    fi
else
    echo "⚠ Docker not available (optional)"
fi
EOF

chmod +x "$DB_DIR/status.sh"

echo ""
echo "Database bootstrap complete!"
echo "Database directory: $DB_DIR"
echo "Check status: $DB_DIR/status.sh"