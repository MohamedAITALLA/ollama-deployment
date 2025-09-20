#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Host: $OLLAMA_HOST"
echo "Port: ${PORT:-8080}"

# Set environment variables
export OLLAMA_PORT=${PORT:-8080}
export OLLAMA_HOST="0.0.0.0"
export OLLAMA_MODELS="/app/.ollama"

# Create models directory
mkdir -p /app/.ollama

# Start a simple HTTP server immediately to keep Scalingo happy
echo "Starting placeholder server on port ${OLLAMA_PORT}..."
cat > /tmp/placeholder.js << 'EOF'
const http = require('http');
const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({status: 'installing', message: 'Ollama is being installed...'}));
    } else {
        res.writeHead(503, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({status: 'installing', message: 'Ollama service starting up...'}));
    }
});
server.listen(process.env.OLLAMA_PORT || 8080, '0.0.0.0', () => {
    console.log(`Placeholder server running on port ${process.env.OLLAMA_PORT || 8080}`);
});
EOF

# Start placeholder server in background
node /tmp/placeholder.js &
PLACEHOLDER_PID=$!

# Install Ollama in background
(
    echo "Installing Ollama in background..."
    
    if [ ! -f "/app/ollama" ]; then
        cd /tmp
        
        echo "Downloading Ollama v0.8.0 binary directly..."
        curl -L -f --connect-timeout 30 --max-time 300 -o /app/ollama \
            "https://github.com/ollama/ollama/releases/download/v0.8.0/ollama-linux-amd64"
        
        chmod +x /app/ollama
        echo "Ollama binary downloaded and installed successfully"
    fi
    
    # Test the binary
    if ! /app/ollama version >/dev/null 2>&1; then
        echo "Warning: Ollama binary test failed"
        /app/ollama version || true
    else
        echo "✅ Ollama binary working correctly"
    fi
    
    # Stop placeholder server
    kill $PLACEHOLDER_PID 2>/dev/null || true
    
    # Start real Ollama server
    echo "Starting real Ollama server..."
    /app/ollama serve &
    OLLAMA_PID=$!
    
    # Wait for Ollama to be ready
    echo "Waiting for Ollama API..."
    for i in {1..30}; do
        if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
            echo "✅ Ollama API is ready!"
            break
        fi
        echo "Attempt $i/30..."
        sleep 5
    done
    
    # Download models in background
    (
        sleep 10
        echo "Downloading TinyLlama model..."
        /app/ollama pull tinyllama:latest && echo "✅ Model downloaded" || echo "⚠️ Model download failed"
    ) &
    
    # Keep Ollama running
    wait $OLLAMA_PID
    
) &
INSTALL_PID=$!

# Handle shutdown
cleanup() {
    echo "Shutting down..."
    kill $PLACEHOLDER_PID 2>/dev/null || true
    kill $INSTALL_PID 2>/dev/null || true
    pkill -f ollama 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

echo "🚀 Service started! Installation running in background..."
echo "Health endpoint: http://localhost:${OLLAMA_PORT}/health"

# Wait for installation to complete
wait $INSTALL_PID