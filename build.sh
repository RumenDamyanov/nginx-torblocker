#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get nginx version and source directory
NGINX_VERSION="1.24.0"
NGINX_SOURCE_DIR="/usr/src/nginx-${NGINX_VERSION}"

# Create module directory
mkdir -p "${NGINX_SOURCE_DIR}/modules/torblocker"

# Copy module source to nginx directory
cp -r "${SCRIPT_DIR}/src/"* "${NGINX_SOURCE_DIR}/modules/torblocker/"

cd "${NGINX_SOURCE_DIR}"
echo "Configuring nginx..."

# Configure with only essential flags
./configure \
    --with-compat \
    --with-http_ssl_module \
    --add-dynamic-module=modules/torblocker

echo "Building nginx module..."
make modules

# Copy module to nginx modules directory
MODULE_NAME="ngx_http_torblocker_module.so"
MODULE_PATH="${NGINX_SOURCE_DIR}/objs/${MODULE_NAME}"

if [ -f "${MODULE_PATH}" ]; then
    echo "Module built successfully at: ${MODULE_PATH}"
    mkdir -p dist
    cp "${MODULE_PATH}" dist/
else
    echo "Error: Module build failed - ${MODULE_PATH} not found"
    exit 1
fi
