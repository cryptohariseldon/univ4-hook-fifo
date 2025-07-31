#!/bin/bash

# Continuum Relayer Startup Script
# This script starts the relayer service on port 8091

echo "Starting Continuum Relayer Service..."
echo "======================================"

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RELAYER_DIR="$SCRIPT_DIR/.."

# Navigate to relayer directory
cd "$RELAYER_DIR"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "Warning: .env file not found. Using default configuration."
    echo "Please create a .env file with your contract addresses."
fi

# Export environment variables
export NODE_ENV=${NODE_ENV:-development}
export PORT=${PORT:-8091}

# Start the relayer
echo ""
echo "Starting relayer on port $PORT..."
echo "Press Ctrl+C to stop"
echo ""

# Run the relayer
node src/index.js