#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Host: $OLLAMA_HOST"
echo "Port: ${PORT:-8080}"

# Set port from Scalingo
export OLLAMA_PORT=${PORT:-8080}

# Start Ollama server in background
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to start..."
for i in {1..30}; do
    if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" > /dev/null 2>&1; then
        echo "Ollama is ready!"
        break
    fi
    echo "Attempt $i/30 - waiting 3 seconds..."
    sleep 3
done

# Download models in background
echo "Starting model download..."
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
wait $OLLAMA_PID