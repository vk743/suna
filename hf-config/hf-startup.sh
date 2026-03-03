# Show hf-startup.sh content for copy-paste.
$ cat "C:\Users\mosre\OneDrive\Documents\opencode web\temp_suna\hf-config\hf-startup.sh"
#!/bin/bash
# Hugging Face Space Startup Script
# This script runs on container startup to inject runtime environment variables
# and start all services via supervisord
set -e
echo "=== Suna AI Hugging Face Space Startup ==="
echo "Starting at: $(date)"
# ==========================================
# Environment Variable Validation
# ==========================================
echo "Validating environment variables..."
# Required variables
REQUIRED_VARS=(
    "SUPABASE_URL"
    "SUPABASE_ANON_KEY"
    "SUPABASE_SERVICE_ROLE_KEY"
    "SUPABASE_JWT_SECRET"
    "DAYTONA_API_KEY"
    "OPENROUTER_API_KEY"
    "TAVILY_API_KEY"
)
MISSING_VARS=()
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        MISSING_VARS+=("$VAR")
    fi
done
if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "ERROR: Missing required environment variables:"
    for VAR in "${MISSING_VARS[@]}"; do
        echo "  - $VAR"
    done
    echo ""
    echo "Please set these in your Hugging Face Space secrets."
    echo "See: https://huggingface.co/docs/hub/spaces-settings#secrets"
    exit 1
fi
echo "All required environment variables are set."
# ==========================================
# Runtime Environment Variable Injection
# ==========================================
# Next.js requires NEXT_PUBLIC_ variables at build time, but HF secrets are only
# available at runtime. We create a production env file for the standalone server.
echo "Creating environment for Next.js standalone server..."
# Set defaults for NEXT_PUBLIC_ variables if not provided
NEXT_PUBLIC_BACKEND_URL="${NEXT_PUBLIC_BACKEND_URL:-http://localhost:8000/v1}"
NEXT_PUBLIC_URL="${NEXT_PUBLIC_URL:-http://localhost:7860}"
NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-$SUPABASE_URL}"
NEXT_PUBLIC_SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-$SUPABASE_ANON_KEY}"
# Create a production .env file for Next.js in the standalone directory
# Next.js standalone reads from process.env, so these will be available
export NEXT_PUBLIC_BACKEND_URL
export NEXT_PUBLIC_URL
export NEXT_PUBLIC_SUPABASE_URL
export NEXT_PUBLIC_SUPABASE_ANON_KEY
export NEXT_PUBLIC_ENV_MODE=production
echo "Environment variables prepared for Next.js"
# ==========================================
# Create Backend .env file
# ==========================================
echo "Creating backend .env file..."
cat > /app/backend/.env << EOF
# Environment
ENV_MODE=production
# Supabase
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
SUPABASE_JWT_SECRET=${SUPABASE_JWT_SECRET}
# Daytona (Sandbox)
DAYTONA_API_KEY=${DAYTONA_API_KEY}
DAYTONA_SERVER_URL=${DAYTONA_SERVER_URL:-https://app.daytona.io/api}
DAYTONA_TARGET=${DAYTONA_TARGET:-us}
# LLM Configuration
MAIN_LLM=${MAIN_LLM:-openai}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
OPENROUTER_API_BASE=${OPENROUTER_API_BASE:-https://openrouter.ai/api/v1}
OR_SITE_URL=${OR_SITE_URL:-https://huggingface.co}
OR_APP_NAME=${OR_APP_NAME:-Suna-HF-Space}
# Web Search
TAVILY_API_KEY=${TAVILY_API_KEY}
# Optional: Firecrawl (skipped per user request)
# FIRECRAWL_API_KEY=${FIRECRAWL_API_KEY}
# Redis (local)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_SSL=False
# Frontend URL
FRONTEND_URL_ENV=${NEXT_PUBLIC_URL}
# Kortix Admin (auto-generated if not set)
KORTIX_ADMIN_API_KEY=${KORTIX_ADMIN_API_KEY}
# Disable presence tracking (saves resources)
DISABLE_PRESENCE=true
# Stripe (optional - for billing)
STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
STRIPE_WEBHOOK_SECRET=${STRIPE_WEBHOOK_SECRET}
# Composio (optional - for integrations)
COMPOSIO_API_KEY=${COMPOSIO_API_KEY}
COMPOSIO_WEBHOOK_SECRET=${COMPOSIO_WEBHOOK_SECRET}
# Webhook secrets
WEBHOOK_BASE_URL=${NEXT_PUBLIC_URL}
TRIGGER_WEBHOOK_SECRET=${TRIGGER_WEBHOOK_SECRET}
EOF
echo "Created backend .env file"
# ==========================================
# Wait for Redis to be Ready
# ==========================================
echo "Waiting for Redis to be ready..."
for i in {1..30}; do
    if redis-cli ping > /dev/null 2>&1; then
        echo "Redis is ready!"
        break
    fi
    echo "Waiting for Redis... ($i/30)"
    sleep 1
done
# ==========================================
# Start Supervisord
# ==========================================
echo "Starting supervisord..."
echo "Services to be managed:"
echo "  - redis (port 6379)"
echo "  - backend (port 8000)"
echo "  - frontend (port 3000)"
echo "  - nginx (port 7860)"
exec supervisord -c /app/hf-config/supervisord.conf
Click to collapse
