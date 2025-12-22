# Build stage
FROM golang:1.25.5-alpine AS builder

# Install dependencies
RUN apk add --no-cache git make

WORKDIR /app

# Copy go.mod (go.sum optional)
COPY go.mod ./

# Copy source code
COPY *.go ./

# Download dependencies (erstellt go.sum automatisch)
RUN go mod download && go mod tidy

# Build chaincode binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o chaincode .

# Final stage
FROM alpine:3.19

# Install ca-certificates and netcat for healthcheck
RUN apk --no-cache add ca-certificates netcat-openbsd

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/chaincode .

# Make binary executable
RUN chmod +x ./chaincode

# Expose chaincode port
EXPOSE 9999

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD nc -z localhost 9999 || exit 1

# Run chaincode
CMD ["./chaincode"]
