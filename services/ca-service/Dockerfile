# ========================================
# STAGE 1: Dependencies
# ========================================
FROM node:20-alpine AS dependencies

WORKDIR /build

# Copy package files
COPY package*.json ./

# Use npm install (monorepo-friendly, no lock file needed)
RUN npm install --only=production --ignore-scripts

# ========================================
# STAGE 2: Production Runtime
# ========================================
FROM node:20-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app directory with correct permissions
RUN mkdir -p /app && chown -R node:node /app

WORKDIR /app

# Switch to non-root user
USER node

# Copy dependencies from dependencies stage
COPY --from=dependencies --chown=node:node /build/node_modules ./node_modules

# Copy application source
COPY --chown=node:node . .

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["node", "server.js"]
