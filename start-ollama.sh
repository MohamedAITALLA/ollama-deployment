#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Host: $OLLAMA_HOST"
echo "Port: ${PORT:-8080}"

# Install Ollama if not present
if [ ! -f "/app/ollama" ]; then
    echo "Installing Ollama..."
    
    # Use a lightweight version that we know works
    OLLAMA_VERSION="0.8.0"  # Known stable version with available assets
    OLLAMA_URL="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tgz"
    
    echo "Downloading Ollama v${OLLAMA_VERSION}..."
    cd /tmp
    
    if curl -L -f --connect-timeout 30 --max-time 600 -o ollama.tgz "$OLLAMA_URL"; then
        echo "Download successful. Extracting..."
        
        # Extract just the binary we need
        if tar -tzf ollama.tgz | grep -q '^ollama$'; then
            # Binary is at root of archive
            tar -xzf ollama.tgz ollama
            mv ollama /app/ollama
        elif tar -tzf ollama.tgz | grep -q '/ollama$'; then
            # Binary is in subdirectory
            tar -xzf ollama.tgz --strip-components=1
            mv ollama /app/ollama 2>/dev/null || find . -name "ollama" -type f -exec mv {} /app/ollama \;
        else
            echo "Extracting entire archive and finding binary..."
            tar -xzf ollama.tgz
            find . -name "ollama" -type f -executable -exec mv {} /app/ollama \;
        fi
        
        # Make sure it's executable
        chmod +x /app/ollama
        rm -f ollama.tgz
        
        echo "Ollama installed to /app/ollama"
    else
        echo "Failed to download Ollama. Trying alternative method..."
        
        # Fallback: use the official install script but extract manually
        curl -fsSL https://ollama.com/install.sh > install.sh
        
        # Modify the script to install to /app instead of system directories
        sed -i 's|/usr/local/bin|/app|g' install.sh
        sed -i 's|/usr/bin|/app|g' install.sh
        sed -i 's|sudo ||g' install.sh
        
        # Run the modified script
        bash install.sh || echo "Install script failed, continuing..."
        
        # Clean up
        rm -f install.sh
    fi
fi

# Verify installation
if [ ! -f "/app/ollama" ]; then
    echo "ERROR: Failed to install Ollama"
    exit 1
fi

# Test the binary
echo "Testing Ollama binary..."
if /app/ollama version 2>/dev/null; then
    echo "Ollama binary is working"
else
    echo "Warning: Ollama version check failed, but continuing..."
fi

# Set environment variables
export OLLAMA_PORT=${PORT:-8080}
export OLLAMA_HOST="0.0.0.0"
export OLLAMA_MODELS="/app/.ollama"

# Create models directory
mkdir -p /app/.ollama

# Start Ollama server
echo "Starting Ollama server on port ${OLLAMA_PORT}..."
/app/ollama serve &
OLLAMA_PID=$!

# Give it time to initialize
sleep 5

# Wait for Ollama to be ready
echo "Waiting for Ollama API to be ready..."
READY=false
for i in {1..30}; do
    if curl -s --connect-timeout 2 --max-time 5 "http://localhost:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
        echo "✅ Ollama API is ready!"
        READY=true
        break
    fi
    echo "Attempt $i/30 - waiting 3 seconds..."
    sleep 3
done

if [ "$READY" = false ]; then
    echo "❌ Failed to start Ollama API"
    echo "Checking process status..."
    if kill -0 $OLLAMA_PID 2>/dev/null; then
        echo "Process is running but API not responding"
    else
        echo "Process has died"
    fi
    exit 1
fi

# Success! API is working
echo "🎉 Ollama service is running successfully!"
echo "API endpoint: http://localhost:${OLLAMA_PORT}/api"
echo "Test with: curl http://localhost:${OLLAMA_PORT}/api/tags"

# Start model download in background (don't block the main service)
(
    sleep 30
    echo "Starting background model download..."
    if /app/ollama pull tinyllama:latest; then
        echo "✅ TinyLlama model downloaded successfully"
    else
        echo "⚠️  Model download failed (service still running)"
    fi
) &

# Handle shutdown gracefully
cleanup() {
    echo "Shutting down Ollama..."
    kill $OLLAMA_PID 2>/dev/null || true
    wait $OLLAMA_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep the service running
echo "Service is live. Press Ctrl+C to stop."
wait $OLLAMA_PID