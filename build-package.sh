#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0m'
NC='\033[0m'

VERSION="1.0.0"

# Check debian directory structure
if [ ! -d "debian" ] || \
   [ ! -f "debian/changelog" ] || \
   [ ! -f "debian/control" ] || \
   [ ! -f "debian/copyright" ] || \
   [ ! -f "debian/rules" ]; then
    echo -e "${RED}Error: Missing required debian packaging files${NC}"
    echo "Please ensure the following structure exists:"
    echo "debian/"
    echo "├── changelog"
    echo "├── control"
    echo "├── copyright"
    echo "└── rules"
    exit 1
fi

# Build packaging Docker image
echo "Building packaging Docker image..."
docker build -t nginx-torblocker-packaging -f Dockerfile.packaging .

# Run packaging in container
echo "Building Debian package..."
docker run --rm \
    -v "$(pwd):/build" \
    nginx-torblocker-packaging bash -c '
    cd /build && \
    # Create source tarball inside container
    tar --exclude=".git" \
        --exclude="debian" \
        --exclude="dist" \
        -czf "../nginx-torblocker_'${VERSION}'.orig.tar.gz" . && \
    # Build package
    debuild -us -uc && \
    # Move package to dist directory
    mkdir -p dist && \
    mv ../nginx-torblocker_*.deb dist/ && \
    echo -e "'${GREEN}'Package built successfully!'${NC}'"
'
