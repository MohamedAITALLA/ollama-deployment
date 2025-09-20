FROM ollama/ollama:latest

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_PORT=8080
ENV OLLAMA_MODELS=/app/.ollama
ENV OLLAMA_MAX_LOADED_MODELS=1
ENV OLLAMA_NUM_PARALLEL=1
ENV OLLAMA_KEEP_ALIVE=5m
ENV OLLAMA_DEBUG=false

# Create working directory
WORKDIR /app

# Copy startup scripts
COPY start-ollama.sh /app/start-ollama.sh
COPY download-models.sh /app/download-models.sh

# Make scripts executable
RUN chmod +x /app/start-ollama.sh /app/download-models.sh

# Create models directory
RUN mkdir -p /app/.ollama

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/api/tags || exit 1

# Expose port
EXPOSE 8080

# Start Ollama
CMD ["/app/start-ollama.sh"]