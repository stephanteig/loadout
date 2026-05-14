# =============================================================
# Loadout — Frontend Dockerfile
# Multi-stage build: build React app → serve with Nginx
#
# Usage:
#   Build:  docker build --build-arg VITE_SUPABASE_URL=https://api.yourdomain.com \
#                        --build-arg VITE_SUPABASE_ANON_KEY=your-anon-key \
#                        -t loadout-frontend .
#   Run:    docker run -p 80:80 loadout-frontend
#
# In Azure Container Registry / Container Apps, pass build args
# as pipeline variables — never hardcode secrets in the image.
# =============================================================

# ----- Stage 1: Build ----------------------------------------
FROM node:22-alpine AS builder

WORKDIR /app

# Copy package files first so Docker cache layer is reused
# on npm install when only source files change
COPY package.json package-lock.json ./
RUN npm ci --frozen-lockfile

# Build args are injected at build time — Vite bakes them into
# the static bundle. They are NOT available at runtime.
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY

ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY

COPY . .
RUN npm run build


# ----- Stage 2: Serve ----------------------------------------
FROM nginx:1.27-alpine AS runner

# Remove default Nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom Nginx config for SPA routing
COPY nginx.conf /etc/nginx/conf.d/app.conf

# Copy built static files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
