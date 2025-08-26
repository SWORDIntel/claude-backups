#!/bin/bash
set -x

echo "Testing bash output..."
echo "Current directory: $(pwd)"
echo "PATH: $PATH"
echo "Testing simple command:"
echo "Hello World Test"
ls -la | head -3
echo "Test complete"