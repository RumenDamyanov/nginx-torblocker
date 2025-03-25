#!/bin/bash

# Load config
source config.env
source common-functions.sh

# Variables
UBUNTU_VERSION="${UBUNTU_VERSION:-noble}"
NGINX_VERSION="${NGINX_VERSION:-1.24.0}"
ARCH="${ARCH:-amd64}"
BUILD_DIR="./build"  # Unified build directory

# Create consistent Docker image name to use throughout script
DOCKER_IMAGE="nginx-torblocker-packaging-${ARCH}-${UBUNTU_VERSION}"

# Prepare build directory
mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}"/*

# Download and extract Nginx sources
download_nginx_sources "${NGINX_VERSION}" "${BUILD_DIR}"
extract_nginx_headers "${NGINX_VERSION}" "${BUILD_DIR}"

# Debugging: List the extracted headers
echo -e "${YELLOW}Listing extracted Nginx headers:${NC}"
ls -l "${BUILD_DIR}/headers/nginx-${NGINX_VERSION}/src/core"

# Copy module source files
cp -r src "${BUILD_DIR}/"
cp -r debian "${BUILD_DIR}/"

# Copy build-module.sh into the build directory
cp build-module.sh "${BUILD_DIR}/"

# Build Docker image
docker build -t nginx-torblocker-test -f Dockerfile.packaging .

# Run build in Docker
docker run --rm -v "$(pwd)/${BUILD_DIR}:/project" nginx-torblocker-test bash -c "
    echo 'Listing /project directory inside the container:';
    ls -l /project;
    echo 'Listing /project/headers/nginx-${NGINX_VERSION}/src/core inside the container:';
    ls -l /project/headers/nginx-${NGINX_VERSION}/src/core;
    cd /project/headers/nginx-${NGINX_VERSION};
    ./configure --without-http_rewrite_module --without-http_gzip_module;
    mkdir -p /project/build;
    cd /project;
    cp objs/ngx_auto_headers.h /project/headers/nginx-${NGINX_VERSION}/src/core/;
    NGINX_VERSION=${NGINX_VERSION} dpkg-buildpackage -us -uc;
    echo 'Listing /project/obj-aarch64-linux-gnu directory:';
    ls -l /project/obj-aarch64-linux-gnu;
"
