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
BUILD_DIR="./build"  # Unified build directory

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
    cd /workspace/build;
    dpkg-buildpackage -S -us -uc --build=source --output-dir=/workspace/build;
    echo 'Files in /workspace/build after build:';
    ls -l /workspace/build;
"

# Find the source changes file
echo -e "${YELLOW}Looking for .changes file in build/ directory...${NC}"
SOURCE_CHANGES_FILE=$(find "${BUILD_DIR}" -name "*.changes" | head -n 1)
if [ -z "${SOURCE_CHANGES_FILE}" ]; then
    echo -e "${RED}Error: Source changes file not found in build/ directory${NC}"
    exit 1
fi

CHANGES_FILE="${SOURCE_CHANGES_FILE}"

# Ensure .buildinfo file is present
BUILDINFO_FILE=$(find "${BUILD_DIR}" -name "*.buildinfo" | head -n 1)
if [ -z "${BUILDINFO_FILE}" ]; then
    echo -e "${RED}Error: .buildinfo file not found in build/ directory. This file is required for signing.${NC}"
    echo -e "${YELLOW}Listing all files in build/ directory for debugging:${NC}"
    ls -l "${BUILD_DIR}"
    exit 1
else
    echo -e "${GREEN}Found .buildinfo file: ${BUILDINFO_FILE}.${NC}"
fi

# Debugging: List all files in the build/ directory
echo -e "${YELLOW}Listing all files in the build/ directory for debugging...${NC}"
ls -l "${BUILD_DIR}"

# Ensure required files are present
REQUIRED_FILES=("${CHANGES_FILE}" "${BUILDINFO_FILE}")
for FILE in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${FILE}" ]; then
        echo -e "${RED}Error: Required file ${FILE} not found.${NC}"
        exit 1
    fi
done

# Build Docker image for signing
DOCKER_IMAGE_SIGNING="nginx-torblocker-signing"
echo -e "${YELLOW}Building Docker image for signing: ${DOCKER_IMAGE_SIGNING}...${NC}"
docker build -t "${DOCKER_IMAGE_SIGNING}" -f Dockerfile.signing .
echo -e "${GREEN}Docker image for signing built successfully.${NC}"

# Verify GPG configuration inside the Docker container
echo -e "${YELLOW}Verifying GPG configuration inside the Docker container...${NC}"
docker run --rm \
    -v "$(pwd):/workspace" \
    -v "$HOME/.gnupg:/root/.gnupg:rw" \
    "${DOCKER_IMAGE_SIGNING}" bash -c "
    gpg --no-auto-check-trustdb --list-keys;
    gpg --no-auto-check-trustdb --list-secret-keys;
    gpgconf --list-dirs;
    gpg-connect-agent /bye;
"

# Debug GPG configuration
echo -e "${YELLOW}Checking GPG configuration inside the Docker container...${NC}"
docker run --rm \
    -v "$(pwd):/workspace" \
    -v "$HOME/.gnupg:/root/.gnupg:rw" \
    "${DOCKER_IMAGE_SIGNING}" bash -c "
    gpg --list-keys;
    gpg --list-secret-keys;
"

# Sign the .changes file
echo -e "${GREEN}Signing ${CHANGES_FILE} with GPG key ${GPG_KEY_ID}...${NC}"
docker run --rm \
    -v "$(pwd):/workspace" \
    -v "$HOME/.gnupg:/root/.gnupg:rw" \
    -e "GPG_KEY_ID=${GPG_KEY_ID}" \
    -e "GPG_PASSPHRASE=${GPG_PASSPHRASE}" \
    "${DOCKER_IMAGE_SIGNING}" bash -c "
    debsign-helper /workspace/${CHANGES_FILE};
    echo 'Signed .changes file:';
    cat /workspace/${CHANGES_FILE};
"
echo -e "${GREEN}Successfully signed ${CHANGES_FILE}.${NC}"

# Debug the .changes file
echo -e "${YELLOW}Inspecting the .changes file...${NC}"
cat "${CHANGES_FILE}"

# Verify the signature on the .changes file
echo -e "${YELLOW}Verifying signature on ${CHANGES_FILE} using dpkg-sig...${NC}"
docker run --rm \
    -v "$(pwd):/workspace" \
    "${DOCKER_IMAGE_SIGNING}" bash -c "
    dpkg-sig --verify /workspace/${CHANGES_FILE};
"

# Upload to PPA
echo -e "${YELLOW}Uploading source package to PPA...${NC}"
docker run --rm \
    -v "$(pwd):/workspace" \
    -e "USER=$(whoami)" \
    "${DOCKER_IMAGE_SIGNING}" bash -c "
    dput --unchecked ${PPA_NAME} /workspace/${SOURCE_CHANGES_FILE};
"
echo -e "${GREEN}Source package uploaded successfully.${NC}"
