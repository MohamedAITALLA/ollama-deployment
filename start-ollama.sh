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

# Verify Ollama binary is available
if [ ! -f "/app/ollama" ]; then
    echo "Ollama binary not found, trying to locate it..."
    OLLAMA_PATH=$(which ollama 2>/dev/null || echo "")
    if [ -n "$OLLAMA_PATH" ] && [ -f "$OLLAMA_PATH" ]; then
        cp "$OLLAMA_PATH" /app/ollama
        chmod +x /app/ollama
        echo "Found and copied Ollama from $OLLAMA_PATH"
    else
        echo "ERROR: Ollama binary not found anywhere"
        exit 1
    fi
fi

# Test the binary
if ! /app/ollama version >/dev/null 2>&1; then
    echo "ERROR: Ollama binary test failed"
    exit 1
fi

echo "Ollama binary verified successfully"
/app/ollama version

# Start placeholder server for health checks
cat > /tmp/server.js << 'EOF'
const http = require('http');
let ollamaReady = false;

const server = http.createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    
    if (req.url === '/health') {
        if (ollamaReady) {
            res.writeHead(200);
            res.end(JSON.stringify({status: 'ready', message: 'Ollama is running'}));
        } else {
            res.writeHead(200);
            res.end(JSON.stringify({status: 'starting', message: 'Ollama is starting...'}));
        }
    } else if (req.url.startsWith('/api/')) {
        // Proxy to Ollama once it's ready
        if (ollamaReady) {
            const options = {
                hostname: 'localhost',
                port: 11434, // Ollama's default port
                path: req.url,
                method: req.method,
                headers: req.headers
            };
            
            const proxy = require('http').request(options, (ollamaRes) => {
                res.writeHead(ollamaRes.statusCode, ollamaRes.headers);
                ollamaRes.pipe(res);
            });
            
            proxy.on('error', (err) => {
                res.writeHead(503);
                res.end(JSON.stringify({error: 'Ollama not available'}));
            });
            
            req.pipe(proxy);
        } else {
            res.writeHead(503);
            res.end(JSON.stringify({error: 'Ollama starting up...'}));
        }
    } else {
        res.writeHead(404);
        res.end(JSON.stringify({error: 'Not found'}));
    }
});

// Check if Ollama is ready
function checkOllama() {
    const http = require('http');
    const req = http.request({
        hostname: 'localhost',
        port: 11434,
        path: '/api/tags',
        method: 'GET'
    }, (res) => {
        if (res.statusCode === 200) {
            ollamaReady = true;
            console.log('Ollama is ready!');
        }
    });
    
    req.on('error', () => {
        // Ollama not ready yet
    });
    
    req.end();
}

server.listen(process.env.OLLAMA_PORT || 8080, '0.0.0.0', () => {
    console.log(`Server running on port ${process.env.OLLAMA_PORT || 8080}`);
    
    // Check Ollama readiness every 2 seconds
    setInterval(checkOllama, 2000);
});
EOF

# Start the proxy server
node /tmp/server.js &
SERVER_PID=$!

# Start Ollama server
echo "Starting Ollama server..."
OLLAMA_HOST=0.0.0.0 OLLAMA_PORT=11434 /app/ollama serve &
OLLAMA_PID=$!

# Wait a bit for Ollama to start
sleep 10

# Download TinyLlama model in background
(
    sleep 20
    echo "Downloading TinyLlama model..."
    if /app/ollama pull tinyllama:latest; then
        echo "Model downloaded successfully"
    else
        echo "Model download failed, but server is still functional"
    fi
) &

# Handle shutdown
cleanup() {
    echo "Shutting down..."
    kill $SERVER_PID 2>/dev/null || true
    kill $OLLAMA_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

echo "Service started successfully!"
echo "Health endpoint: http://localhost:${OLLAMA_PORT}/health"
echo "API available at: http://localhost:${OLLAMA_PORT}/api/"

# Wait for Ollama to finish
wait $OLLAMA_PID