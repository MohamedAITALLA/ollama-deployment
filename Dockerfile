FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama using the official method
RUN curl -fsSL https://ollama.com/install.sh | sh

# Set working directory
WORKDIR /app

# Copy files
COPY package.json start-ollama.sh ./
RUN chmod +x start-ollama.sh

EXPOSE 8080
CMD ["./start-ollama.sh"]