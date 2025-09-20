#!/bin/bash
set -e

echo "Model download process started..."

# Wait for Ollama to be fully ready
sleep 15

# Download TinyLlama (fastest, smallest model)
echo "Downloading TinyLlama model..."
if ollama pull tinyllama:latest; then
    echo "TinyLlama model downloaded successfully"
else
    echo "Failed to download TinyLlama model"
fi

# Optional: Download other models (uncomment as needed)
# echo "Downloading Phi-3 Mini model..."
# if ollama pull phi3:mini; then
#     echo "Phi-3 Mini model downloaded successfully"
# else
#     echo "Failed to download Phi-3 Mini model"
# fi

# echo "Downloading Gemma 2B model..."
# if ollama pull gemma:2b; then
#     echo "Gemma 2B model downloaded successfully"
# else
#     echo "Failed to download Gemma 2B model"
# fi

echo "Model download process completed"