#!/bin/bash
set -e

# Enable debug output
set -x

# Store script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running"
    exit 1
fi

# Ensure build.sh exists
if [ ! -f "build.sh" ]; then
    echo "Error: build.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

# Make build.sh executable
chmod +x build.sh

# Stop any existing containers
echo "Stopping existing containers..."
docker compose down

# Build and start container
echo "Building development environment..."
docker compose build --no-cache || {
    echo "Error: Docker build failed"
    exit 1
}

# Start container
echo "Starting container..."
docker compose up -d || {
    echo "Error: Failed to start container"
    exit 1
}

# Wait for container to be ready
echo "Waiting for container to be ready..."
sleep 5

# Check if container is running
if ! docker compose ps | grep -q "nginx-dev.*Up"; then
    echo "Error: Container failed to start"
    docker compose logs nginx-dev
    exit 1
fi

# Build module inside container
echo "Building module..."
docker compose exec nginx-dev bash -c "cd /build && ./build.sh" || {
    echo "Error: Module build failed"
    docker compose logs nginx-dev
    exit 1
}

echo "Build completed successfully!"
