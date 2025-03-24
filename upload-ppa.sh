#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load configuration
CONFIG_FILE="config.env"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}Loading configuration from $CONFIG_FILE${NC}"
    source "$CONFIG_FILE"
else
    echo -e "${RED}Error: Configuration file $CONFIG_FILE not found${NC}"
    exit 1
fi

# Validate required configuration
if [ -z "${PPA_NAME:-}" ] || [ -z "${GPG_KEY_ID:-}" ] || [ -z "${VERSION:-}" ]; then
    echo -e "${RED}Error: Missing required configuration variables${NC}"
    echo "Please ensure PPA_NAME, GPG_KEY_ID, and VERSION are set in $CONFIG_FILE"
    exit 1
fi

# Check if GPG_PASSPHRASE is set
if [ -z "${GPG_PASSPHRASE:-}" ]; then
    echo -e "${RED}Error: GPG_PASSPHRASE is not set${NC}"
    echo "Please set GPG_PASSPHRASE in your environment or config.env file"
    exit 1
fi

# Set default values for optional settings
UBUNTU_VERSION="${UBUNTU_VERSION:-jammy}"
NGINX_VERSION="${NGINX_VERSION:-1.24.0}"
ARCH="${ARCH:-amd64}"
BUILD_DIR="./build-ppa"

# Prepare build directory
mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}"/*

# Download and extract Nginx sources
echo -e "${YELLOW}Downloading Nginx sources for version ${NGINX_VERSION}...${NC}"
wget -q -O "${BUILD_DIR}/nginx-${NGINX_VERSION}.tar.gz" "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
echo -e "${GREEN}Nginx sources downloaded successfully.${NC}"

# Extract headers
echo -e "${YELLOW}Extracting Nginx headers for version ${NGINX_VERSION}...${NC}"
tar -xzf "${BUILD_DIR}/nginx-${NGINX_VERSION}.tar.gz" -C "${BUILD_DIR}"
echo -e "${GREEN}Nginx headers extracted successfully.${NC}"

# Copy module source files
cp -r src "${BUILD_DIR}/"
cp -r debian "${BUILD_DIR}/"

# Copy build-module.sh into the build directory
cp build-module.sh "${BUILD_DIR}/"

# Build Docker image for packaging
DOCKER_IMAGE_PACKAGING="nginx-torblocker-packaging-${ARCH}-${UBUNTU_VERSION}"
echo -e "${YELLOW}Building Docker image for packaging: ${DOCKER_IMAGE_PACKAGING}...${NC}"
docker build -t "${DOCKER_IMAGE_PACKAGING}" -f Dockerfile.packaging .
echo -e "${GREEN}Docker image for packaging built successfully.${NC}"

# Run build in Docker
echo -e "${YELLOW}Running build inside Docker container...${NC}"
docker run --rm -v "$(pwd):/workspace" "${DOCKER_IMAGE_PACKAGING}" bash -c "
    set -e;
    cd /workspace;
    dpkg-buildpackage -S -us -uc --build=source;
    echo 'Files in /workspace:';
    ls -l /workspace;
"

# Find the source changes file
echo -e "${YELLOW}Looking for .changes file in $(dirname "${BUILD_DIR}")...${NC}"
SOURCE_CHANGES_FILE=$(find "$(dirname "${BUILD_DIR}")" -name "*.changes" | head -n 1)
if [ -z "${SOURCE_CHANGES_FILE}" ]; then
    echo -e "${RED}Error: Source changes file not found in $(dirname "${BUILD_DIR}")${NC}"
    exit 1
fi

# Ensure .buildinfo file is in the same directory as .changes
BUILDINFO_FILE=$(find "$(pwd)" -name "*.buildinfo" | head -n 1)
if [ -z "${BUILDINFO_FILE}" ]; then
    echo -e "${YELLOW}Warning: .buildinfo file not found. Proceeding without it.${NC}"
else
    cp "${BUILDINFO_FILE}" "$(dirname "${SOURCE_CHANGES_FILE}")/"
fi

# Build Docker image for signing
DOCKER_IMAGE_SIGNING="nginx-torblocker-signing"
echo -e "${YELLOW}Building Docker image for signing: ${DOCKER_IMAGE_SIGNING}...${NC}"
docker build -t "${DOCKER_IMAGE_SIGNING}" -f Dockerfile.signing .
echo -e "${GREEN}Docker image for signing built successfully.${NC}"

# Sign the .changes file
echo -e "${YELLOW}Signing the .changes file...${NC}"
docker run --rm \
    -v "$(pwd):/workspace" \
    -v "$HOME/.gnupg:/root/.gnupg:ro" \
    -e "GPG_KEY_ID=${GPG_KEY_ID}" \
    -e "GPG_TTY=/dev/console" \
    "${DOCKER_IMAGE_SIGNING}" bash -c "
    gpg --list-keys;
    debsign -k${GPG_KEY_ID} /workspace/${SOURCE_CHANGES_FILE};
"
echo -e "${GREEN}.changes file signed successfully.${NC}"

# Upload to PPA
echo -e "${YELLOW}Uploading source package to PPA...${NC}"
docker run --rm -v "$(pwd):/workspace" "${DOCKER_IMAGE_SIGNING}" bash -c "
    dput ${PPA_NAME} /workspace/${SOURCE_CHANGES_FILE};
"
echo -e "${GREEN}Source package uploaded successfully.${NC}"
