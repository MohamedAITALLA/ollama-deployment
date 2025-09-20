#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Host: $OLLAMA_HOST"
echo "Port: ${PORT:-8080}"

# Install Ollama if not present
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | bash
    # Add to PATH
    export PATH="/usr/local/bin:$PATH"
    echo "Ollama installed successfully"
fi

# Set port from Scalingo
export OLLAMA_PORT=${PORT:-8080}

# Create models directory
mkdir -p /app/.ollama

# Start Ollama server in background
ollama serve &
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