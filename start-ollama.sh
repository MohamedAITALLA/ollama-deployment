#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Host: $OLLAMA_HOST"
echo "Port: ${PORT:-8080}"

# Install Ollama manually (without root privileges)
if ! command -v ollama &> /dev/null && [ ! -f "/app/ollama" ]; then
    echo "Installing Ollama..."
    
    # Download Ollama tarball (more reliable than single binary)
    OLLAMA_VERSION="0.10.0"
    OLLAMA_URL="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tgz"
    
    echo "Downloading Ollama v${OLLAMA_VERSION}..."
    curl -L -f -o /tmp/ollama.tgz "$OLLAMA_URL"
    
    echo "Extracting Ollama..."
    tar -xzf /tmp/ollama.tgz -C /app/
    
    # Make sure it's executable
    chmod +x /app/ollama
    rm -f /tmp/ollama.tgz
    
    echo "Ollama installed successfully to /app/ollama"
else
    echo "Ollama already available"
fi

# Ensure ollama is in PATH and use full path
export PATH="/app:$PATH"
OLLAMA_BIN="/app/ollama"

# Set port from Scalingo
export OLLAMA_PORT=${PORT:-8080}

# Create models directory
mkdir -p /app/.ollama

# Start Ollama server in background
echo "Starting Ollama server..."
$OLLAMA_BIN serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to start..."
for i in {1..60}; do
    if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
        echo "Ollama is ready!"
        break
    fi
    echo "Attempt $i/60 - waiting 2 seconds..."
    sleep 2
done

# Check if startup was successful
if ! curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
    echo "Failed to start Ollama service"
    echo "Checking if process is still running..."
    if ! kill -0 $OLLAMA_PID 2>/dev/null; then
        echo "Ollama process died. Checking logs..."
    fi
    exit 1
fi

# Download models in background
echo "Starting model download in background..."
chmod +x download-models.sh || true
./download-models.sh &

# Function to handle shutdown
shutdown_handler() {
    echo "Shutting down Ollama..."
    kill $OLLAMA_PID 2>/dev/null || true
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

echo "Ollama service is running on port ${OLLAMA_PORT}"
echo "API available at: http://localhost:${OLLAMA_PORT}/api"
echo "Health check: curl http://localhost:${OLLAMA_PORT}/api/tags"

# Keep the process running
wait $OLLAMA_PID