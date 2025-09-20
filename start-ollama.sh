#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Host: $OLLAMA_HOST"
echo "Port: ${PORT:-8080}"

# Use a lighter approach - install via Go if available, or download smaller binary
if ! command -v ollama &> /dev/null && [ ! -f "/app/ollama" ]; then
    echo "Installing Ollama (lightweight approach)..."
    
    # Try to download just the binary without the full package
    OLLAMA_VERSION="0.9.6"  # Smaller, more stable version
    OLLAMA_URL="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64"
    
    echo "Downloading Ollama v${OLLAMA_VERSION} binary..."
    if curl -L -f -o /app/ollama "$OLLAMA_URL" --connect-timeout 30 --max-time 300; then
        chmod +x /app/ollama
        echo "Ollama installed successfully"
    else
        echo "Failed to download Ollama binary"
        exit 1
    fi
fi

# Verify installation
if [ ! -f "/app/ollama" ]; then
    echo "ERROR: Ollama binary not found"
    exit 1
fi

# Test the binary
echo "Testing Ollama binary..."
/app/ollama version || echo "Version check failed, continuing anyway..."

# Set port and environment
export OLLAMA_PORT=${PORT:-8080}
export OLLAMA_HOST="0.0.0.0"
export OLLAMA_MODELS="/app/.ollama"
mkdir -p /app/.ollama

# Start Ollama server
echo "Starting Ollama server..."
/app/ollama serve &
OLLAMA_PID=$!

# Wait for startup with shorter timeout
echo "Waiting for Ollama to start..."
for i in {1..20}; do
    if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
        echo "Ollama is ready!"
        break
    fi
    echo "Attempt $i/20 - waiting 3 seconds..."
    sleep 3
done

# Final check
if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
    echo "✅ Ollama service is running on port ${OLLAMA_PORT}"
    echo "API available at: http://localhost:${OLLAMA_PORT}/api"
    
    # Download models in background (non-blocking)
    (
        sleep 60
        echo "Downloading TinyLlama model..."
        /app/ollama pull tinyllama:latest || echo "Model download failed"
    ) &
else
    echo "❌ Failed to start Ollama service"
    exit 1
fi

# Handle shutdown
trap 'echo "Shutting down..."; kill $OLLAMA_PID 2>/dev/null || true; exit 0' SIGTERM SIGINT

# Keep running
wait $OLLAMA_PID