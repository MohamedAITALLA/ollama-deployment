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
        
        echo "Using Ollama from official Docker image..."
        
        # Extract ollama binary from official Docker image
        # This is the most reliable method since it's how Ollama officially distributes
        echo "Extracting Ollama binary from Docker image..."
        
        # Create a temporary container and copy the binary
        docker_image="ollama/ollama:latest"
        
        # Use curl to download the install script and extract download URL
        curl -fsSL https://ollama.com/install.sh > /tmp/install.sh 2>/dev/null || true
        
        # Try to extract binary URL from install script
        if [ -f "/tmp/install.sh" ]; then
            # Look for download URLs in the script
            download_url=$(grep -o 'https://[^"]*ollama[^"]*linux[^"]*' /tmp/install.sh | head -1)
            if [ -n "$download_url" ]; then
                echo "Found download URL: $download_url"
                if curl -L -f --connect-timeout 30 --max-time 300 -o /app/ollama "$download_url"; then
                    chmod +x /app/ollama
                    echo "Downloaded Ollama successfully"
                else
                    echo "Download failed, trying alternative method..."
                fi
            fi
        fi
        
        # If we still don't have ollama, try the dockerless install approach
        if [ ! -f "/app/ollama" ] || [ ! -x "/app/ollama" ]; then
            echo "Trying alternative download method..."
            # Try some common URLs
            for url in \
                "https://github.com/ollama/ollama/releases/download/v0.1.32/ollama-linux-amd64" \
                "https://github.com/ollama/ollama/releases/download/v0.1.33/ollama-linux-amd64" \
                "https://github.com/ollama/ollama/releases/download/v0.1.34/ollama-linux-amd64"
            do
                echo "Trying: $url"
                if curl -L -f --connect-timeout 15 --max-time 120 -o /app/ollama "$url" 2>/dev/null; then
                    chmod +x /app/ollama
                    if /app/ollama version >/dev/null 2>&1; then
                        echo "Success with $url"
                        break
                    else
                        rm -f /app/ollama
                    fi
                fi
            done
        fi
        
        # Final verification
        if [ -f "/app/ollama" ] && [ -x "/app/ollama" ]; then
            if /app/ollama version > /dev/null 2>&1; then
                echo "✅ Ollama installed and verified successfully"
                /app/ollama version
            else
                echo "❌ Ollama binary exists but verification failed"
                ls -la /app/ollama
                file /app/ollama 2>/dev/null || echo "file command not available"
            fi
        else
            echo "❌ Failed to install Ollama binary"
            exit 1
        fi
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