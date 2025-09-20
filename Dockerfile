FROM ollama/ollama:latest

# Install Node.js
RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy files
COPY package.json start-ollama.sh ./
RUN chmod +x start-ollama.sh

# Find and copy ollama binary (it should be somewhere in the base image)
RUN find / -name "ollama" -type f -executable 2>/dev/null | head -1 | xargs -I {} cp {} /app/ollama || echo "Ollama not found in base image"
RUN chmod +x /app/ollama 2>/dev/null || true

EXPOSE 8080
CMD ["./start-ollama.sh"]