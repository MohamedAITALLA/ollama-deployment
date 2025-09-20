#!/bin/bash
echo "Container debug info:"
echo "Base image: $(cat /.dockerenv 2>/dev/null || echo 'unknown')"
find / -name "ollama" -type f 2>/dev/null | head -5
ls -la /app/ollama 2>/dev/null || echo "No ollama at /app/ollama"

if [ -f "/app/ollama" ]; then
    echo "Found Ollama, starting service..."
    ./ollama serve
else
    echo "Ollama binary still not found - build problem"
    exit 1
fi