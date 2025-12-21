# ========================================
# STAGE 1: Dependencies
# ========================================
FROM node:20-alpine AS dependencies

WORKDIR /build

COPY package*.json ./

RUN npm install --only=production --ignore-scripts

# ========================================
# STAGE 2: Production Runtime
# ========================================
FROM node:20-alpine

# Install glibc for fabric-ca-client (binary is compiled for glibc, not musl)
ENV GLIBC_VERSION=2.34-r0

RUN apk add --no-cache \
    dumb-init \
    curl \
    wget \
    tar \
    ca-certificates && \
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk && \
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk && \
    apk add --no-cache --force-overwrite \
      glibc-${GLIBC_VERSION}.apk \
      glibc-bin-${GLIBC_VERSION}.apk && \
    rm -f glibc-${GLIBC_VERSION}.apk glibc-bin-${GLIBC_VERSION}.apk

# Download and install fabric-ca-client (v1.5.12)
ENV FABRIC_CA_VERSION=1.5.12

RUN cd /tmp && \
    wget https://github.com/hyperledger/fabric-ca/releases/download/v${FABRIC_CA_VERSION}/hyperledger-fabric-ca-linux-amd64-${FABRIC_CA_VERSION}.tar.gz && \
    tar -xzf hyperledger-fabric-ca-linux-amd64-${FABRIC_CA_VERSION}.tar.gz && \
    mv bin/fabric-ca-client /usr/local/bin/fabric-ca-client && \
    chmod +x /usr/local/bin/fabric-ca-client && \
    rm -rf /tmp/bin /tmp/config /tmp/hyperledger-fabric-ca-linux-amd64-${FABRIC_CA_VERSION}.tar.gz

# Create app directory
RUN mkdir -p /app /app/crypto /app/tls

WORKDIR /app

# Copy dependencies
COPY --from=dependencies /build/node_modules ./node_modules

# Copy application source
COPY . .

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD if [ "$TLS_ENABLED" = "true" ]; then \
        curl -k -f https://localhost:3001/health || exit 1; \
      else \
        node -e "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"; \
      fi

CMD ["node", "server.js"]
