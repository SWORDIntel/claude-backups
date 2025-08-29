#!/bin/bash
# pgvector Extension Installation Script
# Installs pgvector extension during PostgreSQL container initialization

set -e

echo "Installing pgvector extension..."

# Install build dependencies
apt-get update
apt-get install -y build-essential git postgresql-server-dev-16 wget

# Download and install pgvector
cd /tmp
git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git
cd pgvector

# Build and install
make clean
make OPTFLAGS=""
make install

# Clean up
cd /
rm -rf /tmp/pgvector
apt-get remove -y build-essential git wget
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "pgvector extension installation complete!"
echo "Extension will be available for CREATE EXTENSION vector;"