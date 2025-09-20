# Use official Ollama image as base
FROM ollama/ollama:latest

# Install Node.js for your startup scripts
RUN apt-get update && apt-get install -y \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_MODELS=/app/.ollama
ENV OLLAMA_MAX_LOADED_MODELS=1
ENV OLLAMA_NUM_PARALLEL=1
ENV OLLAMA_KEEP_ALIVE=5m
ENV OLLAMA_DEBUG=false

# Create working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package.json /app/
RUN npm install

# Copy startup scripts
COPY simplified-start.sh /app/start-ollama.sh
RUN chmod +x /app/start-ollama.sh

# Create models directory
RUN mkdir -p /app/.ollama

# The ollama binary is already available from the base image
# Copy it to our expected location
RUN cp $(which ollama) /app/ollama && chmod +x /app/ollama

# Expose port (will be set by Scalingo)
EXPOSE 8080

# Start Ollama
CMD ["/app/start-ollama.sh"]