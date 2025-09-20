#!/bin/bash
set -e

echo "Model download process started..."

# Ensure ollama is available
OLLAMA_BIN="/app/ollama"
if [ ! -f "$OLLAMA_BIN" ]; then
    echo "Ollama binary not found at $OLLAMA_BIN"
    exit 1
fi

# Wait for Ollama to be fully ready
sleep 15

# Download TinyLlama (fastest, smallest model)
echo "Downloading TinyLlama model..."
if $OLLAMA_BIN pull tinyllama:latest; then
    echo "TinyLlama model downloaded successfully"
else
    echo "Failed to download TinyLlama model"
fi

# Optional: Download other models (uncomment as needed)
# echo "Downloading Phi-3 Mini model..."
# if $OLLAMA_BIN pull phi3:mini; then
#     echo "Phi-3 Mini model downloaded successfully"
# else
#     echo "Failed to download Phi-3 Mini model"
# fi

echo "Model download process completed"