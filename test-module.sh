#!/bin/bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
NGINX_VERSION="1.27.4"  # Specify a single Nginx version for testing
BUILD_DIR="./build"
OUTPUT_DIR="./output"
MODULE_NAME="ngx_http_torblocker_module.so"

# Prepare build directory
echo -e "${YELLOW}Preparing build directory...${NC}"
mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}"/*

# Download and extract Nginx sources
echo -e "${YELLOW}Downloading and extracting Nginx sources for version ${NGINX_VERSION}...${NC}"
wget -q -O "${BUILD_DIR}/nginx-${NGINX_VERSION}.tar.gz" "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
mkdir -p "${BUILD_DIR}/nginx-${NGINX_VERSION}"
tar -xzf "${BUILD_DIR}/nginx-${NGINX_VERSION}.tar.gz" -C "${BUILD_DIR}/nginx-${NGINX_VERSION}" --strip-components=1
echo -e "${GREEN}Nginx sources downloaded and extracted successfully.${NC}"

# Build the module
echo -e "${YELLOW}Building the module...${NC}"
gcc -c -fPIC \
    -I"${BUILD_DIR}/nginx-${NGINX_VERSION}/src/core" \
    -I"${BUILD_DIR}/nginx-${NGINX_VERSION}/src/event" \
    -I"${BUILD_DIR}/nginx-${NGINX_VERSION}/src/event/modules" \
    -I"${BUILD_DIR}/nginx-${NGINX_VERSION}/src/os/unix" \
    -I"${BUILD_DIR}/nginx-${NGINX_VERSION}/objs" \
    -I"${BUILD_DIR}/nginx-${NGINX_VERSION}/src/http" \
    -I"${BUILD_DIR}/nginx-${NGINX_VERSION}/src/http/modules" \
    -o "${BUILD_DIR}/ngx_http_torblocker_module.o" src/ngx_http_torblocker_module.c

gcc -shared -o "${BUILD_DIR}/${MODULE_NAME}" "${BUILD_DIR}/ngx_http_torblocker_module.o"
echo -e "${GREEN}Module built successfully: ${BUILD_DIR}/${MODULE_NAME}${NC}"

# Test installation
echo -e "${YELLOW}Testing module installation...${NC}"
mkdir -p "${OUTPUT_DIR}/modules"
cp "${BUILD_DIR}/${MODULE_NAME}" "${OUTPUT_DIR}/modules/"
if [ -f "${OUTPUT_DIR}/modules/${MODULE_NAME}" ]; then
    echo -e "${GREEN}Module installed successfully to ${OUTPUT_DIR}/modules/${MODULE_NAME}${NC}"
else
    echo -e "${RED}Module installation failed.${NC}"
    exit 1
fi

echo -e "${GREEN}Test completed successfully.${NC}"
