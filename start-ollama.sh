#!/bin/bash
set -e

echo "Starting Ollama service..."
export OLLAMA_PORT=${PORT:-8080}
export OLLAMA_HOST="0.0.0.0"
export OLLAMA_MODELS="/app/.ollama"

mkdir -p /app/.ollama

if [ ! -f "/app/ollama" ]; then
    echo "ERROR: Ollama binary not found"
    exit 1
fi

echo "Starting Ollama server..."
/app/ollama serve