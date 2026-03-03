# Show Dockerfile content for copy-paste.
$ cat "C:\Users\mosre\OneDrive\Documents\opencode web\temp_suna\hf-config\Dockerfile"
# ==============================================================================
# SUNA AI - Hugging Face Space Dockerfile
# ==============================================================================
# Multi-stage build optimized for HF Spaces (16GB RAM limit)
# Combines: Next.js Frontend + FastAPI Backend + Redis + Nginx
# ==============================================================================
# ==============================================================================
# STAGE 1: Frontend Builder (Node.js)
# ==============================================================================
FROM node:22-slim AS frontend-builder
WORKDIR /app
# Install system dependencies for native modules (canvas, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    build-essential \
    pkg-config \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    && rm -rf /var/lib/apt/lists/*
# Enable pnpm
RUN corepack enable pnpm
# Copy workspace configuration files
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json .npmrc* ./
COPY packages ./packages
# Install shared packages first
RUN pnpm install --filter "@agentpress/shared" --frozen-lockfile
# Copy frontend source
COPY apps/frontend ./apps/frontend
# Install frontend dependencies
RUN pnpm install --filter "./apps/frontend" --frozen-lockfile
# Build frontend with standalone output
WORKDIR /app/apps/frontend
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_OUTPUT=standalone
# Set placeholder values for NEXT_PUBLIC_ variables (will be replaced at runtime)
ARG NEXT_PUBLIC_BACKEND_URL=http://localhost:8000/v1
ARG NEXT_PUBLIC_URL=http://localhost:7860
ARG NEXT_PUBLIC_SUPABASE_URL=https://placeholder.supabase.co
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY=placeholder
ARG NEXT_PUBLIC_ENV_MODE=production
ENV NEXT_PUBLIC_BACKEND_URL=${NEXT_PUBLIC_BACKEND_URL}
ENV NEXT_PUBLIC_URL=${NEXT_PUBLIC_URL}
ENV NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
ENV NEXT_PUBLIC_ENV_MODE=${NEXT_PUBLIC_ENV_MODE}
RUN pnpm run build
# ==============================================================================
# STAGE 2: Backend Builder (Python)
# ==============================================================================
FROM python:3.11-slim AS backend-builder
WORKDIR /app/backend
# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
# Install uv for fast dependency management
RUN pip install uv
# Copy backend files
COPY backend/pyproject.toml backend/uv.lock ./
# Install Python dependencies
RUN uv sync --frozen
# Copy backend source code
COPY backend/ ./
# ==============================================================================
# STAGE 3: Final Runtime Image
# ==============================================================================
FROM python:3.11-slim AS runtime
# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    nginx \
    redis-server \
    supervisor \
    procps \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/nginx \
    && mkdir -p /var/log/nginx /var/lib/nginx /tmp \
    && chown -R 1000:1000 /var/log/nginx /var/lib/nginx /tmp
WORKDIR /app
# Create non-root user for HF Spaces
RUN useradd -m -u 1000 -s /bin/bash appuser
# Copy frontend standalone build from builder
# Next.js standalone structure: .next/standalone contains the server
COPY --from=frontend-builder --chown=1000:1000 /app/apps/frontend/.next/standalone ./standalone
COPY --from=frontend-builder --chown=1000:1000 /app/apps/frontend/.next/static ./standalone/apps/frontend/.next/static
COPY --from=frontend-builder --chown=1000:1000 /app/apps/frontend/public ./standalone/apps/frontend/public
# Copy backend from builder
COPY --from=backend-builder --chown=1000:1000 /app/backend/.venv ./backend/.venv
COPY --from=backend-builder --chown=1000:1000 /app/backend ./backend
# Copy HF configuration files
COPY hf-config/nginx.conf /app/hf-config/nginx.conf
COPY hf-config/supervisord.conf /app/hf-config/supervisord.conf
COPY hf-config/hf-startup.sh /app/hf-config/hf-startup.sh
# Make startup script executable
RUN chmod +x /app/hf-config/hf-startup.sh
# Set up environment
ENV ENV_MODE=production
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=7860
ENV HOSTNAME="0.0.0.0"
ENV PYTHONPATH=/app/backend
ENV PATH="/app/backend/.venv/bin:$PATH"
# Create necessary directories
RUN mkdir -p /tmp /var/log/supervisor /var/run \
    && chown -R 1000:1000 /app /tmp /var/log/supervisor /var/run
# Switch to non-root user
USER 1000
# Expose HF Spaces port
EXPOSE 7860
# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:7860/health || exit 1
# Start all services via supervisor
CMD ["/app/hf-config/hf-startup.sh"]
Click to collapse
