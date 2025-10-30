#!/bin/bash
#
# Robust Environment Setup Script
#
# This script sets up the necessary Python virtual environment, installs
# dependencies, and verifies other required tools like Docker.
# It is designed to be safe to run multiple times.

set -e # Exit immediately if a command exits with a non-zero status.

echo "### Starting Robust Environment Setup ###"
echo

# --- 1. System Dependency Check ---
echo "--> Phase 1: Checking for essential system dependencies..."

# Function to check if a command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Python 3 and pip
if ! command_exists python3; then
    echo "Error: python3 is not found. Please install Python 3.10 or higher."
    exit 1
fi
if ! python3 -m pip --version >/dev/null 2>&1; then
    echo "Error: python3-pip is not found. Please install pip for your Python 3 installation."
    exit 1
fi

# Check for python3-venv module
if ! python3 -c "import venv" >/dev/null 2>&1; then
    echo "Warning: The 'venv' module is not available for your Python installation."
    echo "         On Debian/Ubuntu, you can install it with: sudo apt-get install python3-venv"
    echo "         On Fedora/CentOS, you can install it with: sudo dnf install python3-virtualenv"
    exit 1
fi

echo "    System dependencies are satisfied."
echo

# --- 2. Virtual Environment Setup ---
VENV_DIR=".venv"
echo "--> Phase 2: Setting up Python virtual environment in './${VENV_DIR}'..."

if [ -d "$VENV_DIR" ]; then
    echo "    Virtual environment already exists. Skipping creation."
else
    python3 -m venv "$VENV_DIR"
    echo "    Successfully created virtual environment."
fi
echo

# --- 3. Install Python Dependencies ---
echo "--> Phase 3: Activating environment and installing Python packages..."
# Activate the virtual environment for this script session
source "${VENV_DIR}/bin/activate"

# Ensure pip is up-to-date
echo "    Upgrading pip..."
python3 -m pip install --upgrade pip > /dev/null

# Install dependencies from requirements.txt
REQUIREMENTS_FILE="config/requirements.txt"
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "    Installing packages from ${REQUIREMENTS_FILE}..."
    python3 -m pip install -r "$REQUIREMENTS_FILE"
    echo "    Python packages installed successfully."
else
    echo "Warning: ${REQUIREMENTS_FILE} not found. Skipping Python package installation."
fi
echo

# --- 4. Docker Sanity Check ---
echo "--> Phase 4: Checking Docker status..."
if command_exists docker; then
    echo "    Docker command found."
    if docker info > /dev/null 2>&1; then
        echo "    Docker daemon is running and accessible."
    else
        echo "Warning: Docker command found, but the Docker daemon is not running or accessible."
        echo "         Some features may fail. Consider starting the Docker service."
    fi
else
    echo "Warning: Docker is not installed. Features relying on Docker will not be available."
fi
echo

# --- 5. Completion ---
echo "========================================="
echo "### Environment setup complete! ###"
echo
echo "To activate the virtual environment in your shell, run:"
echo "  source ${VENV_DIR}/bin/activate"
echo
echo "You should now be able to run the project's tests and applications."
echo "========================================="