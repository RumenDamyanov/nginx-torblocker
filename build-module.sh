#!/bin/bash
set -e

# Define variables
NGINX_VERSION="${NGINX_VERSION:-1.24.0}"  # Default to 1.24.0 if not set
NGINX_SOURCE_URL="https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"  # Get the absolute path of the script's directory
WORK_DIR="$PROJECT_ROOT/work_dir"
DEB_HOST_MULTIARCH="${DEB_HOST_MULTIARCH:-$(dpkg-architecture -qDEB_HOST_MULTIARCH)}"
BUILD_DIR="./build"
NGINX_BUILD_DIR="/tmp/nginx-build"
SRCFILE="$PROJECT_ROOT/src/ngx_http_torblocker_module.c"
SRC_DIR="$PROJECT_ROOT/src"
NGINX_HEADERS_DIR="$NGINX_BUILD_DIR/nginx-${NGINX_VERSION}/src"

# Create build directory
mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}"/*

# Check if the source file exists
if [ -f "$SRCFILE" ]; then
  echo "Found source file at $SRCFILE"
else
  echo "ERROR: Source file '$SRCFILE' not found in the expected location!"
  echo "Please ensure the file exists in the 'src' directory."
  exit 1
fi

# Download and build Nginx source
if [ ! -d "$NGINX_BUILD_DIR/nginx-${NGINX_VERSION}" ]; then
  echo "Downloading and extracting Nginx source..."
  mkdir -p "$NGINX_BUILD_DIR"
  wget -q -O "$NGINX_BUILD_DIR/nginx-${NGINX_VERSION}.tar.gz" "$NGINX_SOURCE_URL"
  tar -xzf "$NGINX_BUILD_DIR/nginx-${NGINX_VERSION}.tar.gz" -C "$NGINX_BUILD_DIR"
fi

echo "Configuring and building Nginx source to generate required headers..."
cd "$NGINX_BUILD_DIR/nginx-${NGINX_VERSION}"
./configure --without-http_rewrite_module --without-http_gzip_module
make -j$(nproc)

# Verify that the required headers are generated
if [ ! -f "objs/ngx_auto_headers.h" ]; then
  echo "ERROR: ngx_auto_headers.h was not generated. Please check the Nginx build process."
  exit 1
fi

# Compile the module
echo "Compiling $SRCFILE..."
gcc -c -fPIC \
  -I"$NGINX_HEADERS_DIR/core" \
  -I"$NGINX_HEADERS_DIR/event" \
  -I"$NGINX_HEADERS_DIR/event/modules" \
  -I"$NGINX_HEADERS_DIR/os/unix" \
  -I"$NGINX_HEADERS_DIR/http" \
  -I"$NGINX_HEADERS_DIR/http/modules" \
  -I"$NGINX_BUILD_DIR/nginx-${NGINX_VERSION}/objs" \
  -o "$BUILD_DIR/ngx_http_torblocker_module.o" "$SRCFILE"

# Link the module
echo "Creating shared object..."
gcc -shared -o "$BUILD_DIR/ngx_http_torblocker_module.so" \
  "$BUILD_DIR/ngx_http_torblocker_module.o"

echo "Build successful! Output files:"
ls -la "$BUILD_DIR/"
