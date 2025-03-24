#!/bin/bash

# Enable stricter error handling
set -euo pipefail

# Output function for better debugging
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $*" >&2
}

# Error handler
handle_error() {
    log "ERROR: Build failed at line $1 with exit code $2"
    exit 1
}

trap 'handle_error ${LINENO} $?' ERR

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
log "Script directory: ${SCRIPT_DIR}"

# Get nginx version from environment or use default
NGINX_VERSION="${NGINX_VERSION:-1.24.0}"
log "Building for Nginx version: ${NGINX_VERSION}"

# Check for nginx-dev
if ! dpkg -l nginx-dev > /dev/null 2>&1; then
    log "ERROR: nginx-dev package is not installed"
    exit 1
fi

# First, try to use nginx-dev if available
if dpkg -l nginx-dev > /dev/null 2>&1; then
    log "Using nginx-dev package"

    # Create output directories
    mkdir -p dist

    # Compile the module using nginx-dev
    log "Compiling module with nginx-dev"

    # Get the nginx includes path
    NGINX_INCLUDES=$(nginx -V 2>&1 | grep -o -- '--with-cc-opt=.*' | sed 's/--with-cc-opt=//' | cut -d' ' -f1)

    # Get the ld options
    NGINX_LD_OPTS=$(nginx -V 2>&1 | grep -o -- '--with-ld-opt=.*' | sed 's/--with-ld-opt=//' | cut -d' ' -f1)

    # Compile the module
    gcc -c -o dist/ngx_http_torblocker_module.o \
        -fPIC -O2 -fvisibility=hidden \
        ${NGINX_INCLUDES} \
        src/ngx_http_torblocker_module.c

    gcc -o dist/ngx_http_torblocker_module.so \
        -shared -fPIC ${NGINX_LD_OPTS} \
        dist/ngx_http_torblocker_module.o

    log "Module compiled successfully"
    exit 0
fi

# If we're here, we need to use the Nginx source
log "nginx-dev not found, looking for Nginx source"

# Use NGINX_SRC_PATH if provided, otherwise look in standard locations
if [ -n "${NGINX_SRC_PATH:-}" ]; then
    log "Using provided Nginx source path: $NGINX_SRC_PATH"
    if [ -d "$NGINX_SRC_PATH/nginx-${NGINX_VERSION}" ]; then
        NGINX_SRC_DIR="$NGINX_SRC_PATH/nginx-${NGINX_VERSION}"
    else
        NGINX_SRC_DIR="$NGINX_SRC_PATH"
    fi
else
    # Look in various standard locations
    for dir in /usr/src/nginx-* /usr/share/nginx/src/*; do
        if [ -d "$dir" ]; then
            log "Found Nginx source in $dir"
            NGINX_SRC_DIR="$dir"
            break
        fi
    done
fi

# Check if we found a source directory
if [ -z "${NGINX_SRC_DIR:-}" ] || [ ! -d "$NGINX_SRC_DIR" ]; then
    log "ERROR: Could not find Nginx source directory"
    exit 1
fi

log "Found Nginx source at $NGINX_SRC_DIR"

# Create output directories
mkdir -p dist/nginx-${NGINX_VERSION}

# Build module
cd "$NGINX_SRC_DIR"

# Configure if auto/configure exists (typical Nginx source structure)
if [ -f "auto/configure" ]; then
    log "Configuring Nginx"
    ./configure \
        --prefix=/usr \
        --add-dynamic-module=$(pwd)/../../ \
        --with-compat \
        --with-http_ssl_module

    # Compile module only
    log "Building module"
    make modules

    # Copy the built module to the output directory
    log "Copying module to output directory"
    cp objs/ngx_http_torblocker_module.so $(pwd)/../../dist/nginx-${NGINX_VERSION}/
else
    log "Non-standard Nginx source structure, trying alternative build method"

    # Try to find the module source in our own directory
    MODULE_SRC=$(pwd)/../../src/ngx_http_torblocker_module.c
    if [ ! -f "$MODULE_SRC" ]; then
        log "ERROR: Could not find module source at $MODULE_SRC"
        exit 1
    fi

    # Try to compile directly
    gcc -c -o $(pwd)/../../dist/nginx-${NGINX_VERSION}/ngx_http_torblocker_module.o \
        -fPIC -O2 -fvisibility=hidden \
        -I. -I./src/core -I./src/event -I./src/event/modules \
        -I./src/os/unix -I./src/http -I./src/http/modules \
        -I./src/http/modules/perl \
        $MODULE_SRC

    gcc -o $(pwd)/../../dist/nginx-${NGINX_VERSION}/ngx_http_torblocker_module.so \
        -shared -fPIC \
        $(pwd)/../../dist/nginx-${NGINX_VERSION}/ngx_http_torblocker_module.o
fi

log "Build complete"
