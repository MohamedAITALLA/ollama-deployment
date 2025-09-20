#!/bin/bash
echo "Installing Ollama at runtime..."

# Install Ollama using official method
if [ ! -f "/app/ollama" ]; then
    echo "Downloading and installing Ollama..."
    curl -fsSL https://ollama.com/install.sh > /tmp/install.sh
    
    # Modify script for non-root installation
    sed -i 's/\/usr\/local\/bin/\/app/g' /tmp/install.sh
    sed -i 's/sudo //g' /tmp/install.sh
    sed -i '/systemctl/d' /tmp/install.sh
    sed -i '/service/d' /tmp/install.sh
    
    bash /tmp/install.sh || echo "Install script failed"
fi

if [ -f "/app/ollama" ]; then
    echo "Starting Ollama..."
    export OLLAMA_PORT=${PORT:-8080}
    /app/ollama serve
else
    echo "Installation failed"
    exit 1
fi