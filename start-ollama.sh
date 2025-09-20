#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Host: $OLLAMA_HOST"
echo "Port: ${PORT:-8080}"

# Install Ollama manually (without root privileges)
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    
    # Download Ollama binary directly
    OLLAMA_VERSION="0.3.12"
    OLLAMA_URL="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64"
    
    curl -L -o /app/ollama $OLLAMA_URL
    chmod +x /app/ollama
    
    # Add to PATH
    export PATH="/app:$PATH"
    
    echo "Ollama installed successfully"
else
    # Ensure ollama is in PATH
    export PATH="/app:$PATH"
fi

# Set port from Scalingo
export OLLAMA_PORT=${PORT:-8080}

# Create models directory
mkdir -p /app/.ollama

# Start Ollama server in background
/app/ollama serve &
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