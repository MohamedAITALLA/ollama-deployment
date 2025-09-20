#!/bin/bash
set -e

echo "Model download process started..."

# Ensure ollama is in PATH
export PATH="/app:$PATH"

# Wait for Ollama to be fully ready
sleep 15

# Download TinyLlama (fastest, smallest model)
echo "Downloading TinyLlama model..."
if /app/ollama pull tinyllama:latest; then
    echo "TinyLlama model downloaded successfully"
else
    echo "Failed to download TinyLlama model"
fi

# Optional: Download other models (uncomment as needed)
# echo "Downloading Phi-3 Mini model..."
# if /app/ollama pull phi3:mini; then
#     echo "Phi-3 Mini model downloaded successfully"
# else
#     echo "Failed to download Phi-3 Mini model"
# fi

echo "Model download process completed"