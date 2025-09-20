#!/bin/bash
set -e

echo "Starting Ollama service..."
echo "Debugging container contents..."

# Check what's available
echo "Checking for ollama in common locations:"
ls -la /usr/local/bin/ollama 2>/dev/null && echo "Found at /usr/local/bin/ollama" || echo "Not at /usr/local/bin/ollama"
ls -la /usr/bin/ollama 2>/dev/null && echo "Found at /usr/bin/ollama" || echo "Not at /usr/bin/ollama"
ls -la /bin/ollama 2>/dev/null && echo "Found at /bin/ollama" || echo "Not at /bin/ollama"
ls -la /app/ollama 2>/dev/null && echo "Found at /app/ollama" || echo "Not at /app/ollama"

# Search for ollama anywhere
echo "Searching for ollama binary anywhere:"
find / -name "ollama" -type f -executable 2>/dev/null | head -10 || echo "Find command failed or no results"

# Check which command
which ollama 2>/dev/null && echo "which ollama: $(which ollama)" || echo "ollama not in PATH"

# Check if this is actually the ollama base image
echo "Container info:"
cat /etc/os-release 2>/dev/null | head -5 || echo "No OS release info"

exit 1  # Exit with error so we can see the debug output