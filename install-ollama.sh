#!/bin/bash
set -e

echo "Installing Ollama manually..."

# Check if Ollama already exists
if [ -f "/app/ollama" ]; then
    echo "Ollama already installed"
    export PATH="/app:$PATH"
    return 0
fi

# Download Ollama binary directly (avoid the install script that requires root)
OLLAMA_VERSION="0.3.12"
OLLAMA_URL="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64"

echo "Downloading Ollama v${OLLAMA_VERSION}..."
curl -L -o /app/ollama $OLLAMA_URL

echo "Making Ollama executable..."
chmod +x /app/ollama

# Add to PATH
export PATH="/app:$PATH"

echo "Ollama installed successfully to /app/ollama"