# NanoClaw Orchestrator
# Main process that manages channels, scheduling, and container orchestration

FROM node:22-slim

# Install Docker CLI and build tools for native modules
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    python3 \
    make \
    g++ \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install all dependencies (ignore prepare/husky script, then rebuild native modules)
RUN npm ci --ignore-scripts && npm rebuild

# Copy source and build
COPY tsconfig.json ./
COPY src/ ./src/

# Build and prune dev dependencies
RUN npx tsc \
    && npm prune --omit=dev \
    && rm -rf src/

# Create data directories
RUN mkdir -p /app/store /app/groups /app/data

# Create non-root user
RUN useradd -m -s /bin/bash nanoclaw \
    && chown -R nanoclaw:nanoclaw /app

USER nanoclaw

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001', (r) => process.exit(r.statusCode === 502 ? 0 : 1))" || exit 1

CMD ["node", "dist/index.js"]
