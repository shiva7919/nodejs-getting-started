# ---- Builder ----
FROM node:18-alpine AS builder

# Create app directory
WORKDIR /usr/src/app

# Copy package manifests first (caches npm install)
COPY package*.json ./

# Use npm ci if lockfile exists for reproducible installs
# Fallback to npm install if package-lock.json is not present
RUN if [ -f package-lock.json ]; then npm ci --only=production; else npm install --no-audit --no-fund; fi

# Copy application source
COPY . .

# ---- Runtime ----
FROM node:18-alpine

WORKDIR /usr/src/app

# Copy only what's needed from builder (node_modules + app)
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app ./

# Use production environment
ENV NODE_ENV=production
ENV PORT=5006

# Use non-root 'node' user provided by the base image
USER node

EXPOSE 5006

# Start the app
CMD ["npm", "start"]
