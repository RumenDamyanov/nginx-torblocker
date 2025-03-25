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

# Loop through the COMPATIBILITY_MATRIX
echo -e "${YELLOW}Processing compatibility matrix...${NC}"
while IFS=: read -r UBUNTU_VERSION NGINX_VERSION; do
    if [[ -z "$UBUNTU_VERSION" || -z "$NGINX_VERSION" ]]; then
        continue  # Skip empty lines
    fi

    echo -e "${YELLOW}Processing Ubuntu version: ${UBUNTU_VERSION}, Nginx version: ${NGINX_VERSION}${NC}"

    # Set environment variables for this combination
    export UBUNTU_VERSION
    export NGINX_VERSION

    # Existing working code starts here
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
    docker run --rm -v "$(pwd)/${BUILD_DIR}:/project" "${DOCKER_IMAGE_PACKAGING}" bash -c "
        set -e;
        cd /project;
        dpkg-buildpackage -S -us -uc --build=source || { echo 'dpkg-buildpackage failed'; exit 1; }
        echo 'Files in /project:';
        ls -l /project;

        # Move output files from parent directory if necessary
        if ls ../*.dsc 2>/dev/null; then
            mv ../*.dsc /project/
        fi
        if ls ../*.changes 2>/dev/null; then
            mv ../*.changes /project/
        fi
        if ls ../*.buildinfo 2>/dev/null; then
            mv ../*.buildinfo /project/
        fi
        if ls ../*.xz 2>/dev/null; then
            mv ../*.xz /project/
        fi

        echo 'Final files in /project:';
        ls -l /project;
    "

    # Debugging: List files in the build directory
    echo -e "${YELLOW}Listing files in ${BUILD_DIR}:${NC}"
    ls -l "${BUILD_DIR}"

    # Debugging: Check for .changes and .buildinfo files
    echo -e "${YELLOW}Checking for .changes and .buildinfo files:${NC}"
    find "${BUILD_DIR}" -maxdepth 1 -name "*.changes"
    find "${BUILD_DIR}" -maxdepth 1 -name "*.buildinfo"

    # Find the source changes file
    echo -e "${YELLOW}Looking for .changes file in ${BUILD_DIR}...${NC}"
    SOURCE_CHANGES_FILE=$(find "${BUILD_DIR}" -maxdepth 1 -name "*.changes" | head -n 1)
    if [ -z "${SOURCE_CHANGES_FILE}" ]; then
        echo -e "${RED}Error: Source changes file not found in ${BUILD_DIR}${NC}"
        exit 1
    fi

    CHANGES_FILE="${SOURCE_CHANGES_FILE}"

    # Ensure .buildinfo file is in the same directory as .changes
    BUILDINFO_FILE=$(find "${BUILD_DIR}" -maxdepth 1 -name "*.buildinfo" | head -n 1)
    if [ -z "${BUILDINFO_FILE}" ]; then
        echo -e "${RED}Error: .buildinfo file not found. This file is required for signing.${NC}"
        exit 1
    else
        echo -e "${GREEN}Found .buildinfo file: ${BUILDINFO_FILE}.${NC}"
    fi

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
        -v "$(pwd)/${BUILD_DIR}:/project/build" \
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
        -v "$(pwd)/${BUILD_DIR}:/project/build" \
        -v "$HOME/.gnupg:/root/.gnupg:rw" \
        "${DOCKER_IMAGE_SIGNING}" bash -c "
        gpg --list-keys;
        gpg --list-secret-keys;
    "

    # Sign the .changes file
    echo -e "${GREEN}Signing ${CHANGES_FILE} with GPG key ${GPG_KEY_ID}...${NC}"
    docker run --rm \
        -v "$(pwd)/${BUILD_DIR}:/project" \
        -v "$HOME/.gnupg:/root/.gnupg:rw" \
        -e "GPG_KEY_ID=${GPG_KEY_ID}" \
        -e "GPG_PASSPHRASE=${GPG_PASSPHRASE}" \
        "${DOCKER_IMAGE_SIGNING}" bash -c "
        debsign-helper /project/$(basename "${CHANGES_FILE}");
        echo 'Signed .changes file:';
        cat /project/$(basename "${CHANGES_FILE}");
    "
    echo -e "${GREEN}Successfully signed ${CHANGES_FILE}.${NC}"

    # Debug the .changes file
    echo -e "${YELLOW}Inspecting the .changes file...${NC}"
    cat "${CHANGES_FILE}"

    # Verify the signature on the .changes file
    echo -e "${YELLOW}Verifying signature on ${CHANGES_FILE} using dpkg-sig...${NC}"
    docker run --rm \
        -v "$(pwd)/${BUILD_DIR}:/project" \
        "${DOCKER_IMAGE_SIGNING}" bash -c "
        dpkg-sig --verify /project/$(basename "${CHANGES_FILE}");
    "

    # Upload to PPA
    echo -e "${YELLOW}Uploading source package to PPA...${NC}"
    docker run --rm \
        -v "$(pwd)/${BUILD_DIR}:/project" \
        -e "USER=$(whoami)" \
        "${DOCKER_IMAGE_SIGNING}" bash -c "
        dput --unchecked ${PPA_NAME} /project/$(basename "${SOURCE_CHANGES_FILE}");
    "
    echo -e "${GREEN}Source package uploaded successfully.${NC}"

done <<< "$COMPATIBILITY_MATRIX"

echo -e "${GREEN}All combinations processed successfully.${NC}"
