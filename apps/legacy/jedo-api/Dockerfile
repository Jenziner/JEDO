# Base image
FROM golang:1.21-alpine

# Set working directory in the container
WORKDIR /app

# Copy Go mod and sum files to install dependencies
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the rest of the application code
COPY . .

# Build the Go app
RUN go build -o /jedo-api

# Expose the port on which your API will run
EXPOSE 3000

# Command to run the app when the container starts
CMD ["/jedo-api"]
