# Database Components

This directory contains all database-related components for the Claude Agent Framework v7.0.

## Directory Structure

```
database/
├── sql/                    # SQL schemas and scripts
│   └── auth_db_setup.sql
├── python/                 # Python utilities
│   └── auth_redis_setup.py
├── scripts/                # Deployment scripts
│   └── deploy_auth_database.sh
├── tests/                  # Test suites
│   └── auth_db_performance_test.py
├── docs/                   # Documentation
│   ├── auth_database_architecture.md
│   └── DATABASE_AGENT_DELIVERABLE_SUMMARY.md
└── manage_database.sh      # Convenience management script
```

## Quick Start

```bash
# Setup database
./manage_database.sh setup

# Run tests
./manage_database.sh test

# Setup Redis
./manage_database.sh redis

# Show status
./manage_database.sh status
```

## Original Functionality

All original functionality is preserved with updated path references.
No breaking changes have been introduced.
