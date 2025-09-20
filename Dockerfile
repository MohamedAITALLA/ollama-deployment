FROM ollama/ollama:latest

RUN apt-get update && apt-get install -y \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_MODELS=/app/.ollama

WORKDIR /app

COPY package.json /app/
COPY start-ollama.sh /app/start-ollama.sh
RUN chmod +x /app/start-ollama.sh
RUN mkdir -p /app/.ollama

# Copy ollama binary from system location to /app/
RUN cp /usr/local/bin/ollama /app/ollama && chmod +x /app/ollama

EXPOSE 8080
CMD ["/app/start-ollama.sh"]