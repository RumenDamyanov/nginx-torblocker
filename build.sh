#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get nginx version from container and clean it
NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2 | sed 's/ (Ubuntu)//')
echo "Container nginx version: ${NGINX_VERSION}"

# Get essential paths from current nginx installation
NGINX_PREFIX=$(nginx -V 2>&1 | grep -o 'prefix=[^ ]*' | cut -d'=' -f2)
NGINX_MODULES_PATH=$(nginx -V 2>&1 | grep -o 'modules-path=[^ ]*' | cut -d'=' -f2)

# Check if config file exists
if [ ! -f "${SCRIPT_DIR}/src/config" ]; then
    echo "Error: Module config file not found at ${SCRIPT_DIR}/src/config"
    exit 1
fi

# Use nginx source directory with cleaned version
NGINX_SOURCE_DIR="/nginx-${NGINX_VERSION}"

# Verify directory exists
if [ ! -d "${NGINX_SOURCE_DIR}" ]; then
    echo "Error: Nginx source directory not found at ${NGINX_SOURCE_DIR}"
    exit 1
fi

cd "${NGINX_SOURCE_DIR}"
echo "Configuring nginx..."

# Configure with only essential flags
./configure \
    --prefix=${NGINX_PREFIX} \
    --modules-path=${NGINX_MODULES_PATH} \
    --with-compat \
    --with-http_ssl_module \
    --add-dynamic-module="${SCRIPT_DIR}/src"

echo "Building nginx module..."
make modules

echo "Module built successfully!"

echo "Building nginx module..."
make modules

# Copy module to nginx modules directory
MODULE_NAME="ngx_http_torblocker_module.so"
MODULE_PATH="${NGINX_SOURCE_DIR}/objs/${MODULE_NAME}"

if [ -f "${MODULE_PATH}" ]; then
    echo "Module built at: ${MODULE_PATH}"

    # Create modules directory if it doesn't exist
    if [ ! -d "${NGINX_MODULES_PATH}" ]; then
        echo "Creating nginx modules directory at ${NGINX_MODULES_PATH}..."
        mkdir -p "${NGINX_MODULES_PATH}" || {
            echo "Error: Failed to create modules directory at ${NGINX_MODULES_PATH}"
            echo "Please manually create the directory and copy ${MODULE_PATH} there"
            exit 1
        }
        chmod 755 "${NGINX_MODULES_PATH}"
    fi

    # Copy module with proper permissions
    cp "${MODULE_PATH}" "${NGINX_MODULES_PATH}/" && \
    chmod 644 "${NGINX_MODULES_PATH}/${MODULE_NAME}" || {
        echo "Error: Failed to copy or set permissions for module"
        exit 1
    }

    echo "Module installed successfully at ${NGINX_MODULES_PATH}/${MODULE_NAME}"
else
    echo "Error: Module build failed - ${MODULE_PATH} not found"
    exit 1
fi

echo "Module built successfully!"
