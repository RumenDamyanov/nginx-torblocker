#!/bin/bash

# Load config
source config.env
source common-functions.sh

# Variables
UBUNTU_VERSION="${UBUNTU_VERSION:-noble}"
NGINX_VERSION="${NGINX_VERSION:-1.24.0}"
ARCH="${ARCH:-amd64}"
BUILD_DIR="./build-test"

# Create consistent Docker image name to use throughout script
DOCKER_IMAGE="nginx-torblocker-packaging-${ARCH}-${UBUNTU_VERSION}"

# Prepare build directory
mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}"/*

# Download and extract Nginx sources
download_nginx_sources "${NGINX_VERSION}" "${BUILD_DIR}"
extract_nginx_headers "${NGINX_VERSION}" "${BUILD_DIR}"

# Copy module source files
cp -r src "${BUILD_DIR}/"
cp -r debian "${BUILD_DIR}/"

# Copy build-module.sh into the build directory
cp build-module.sh "${BUILD_DIR}/"

# Build Docker image
docker build -t nginx-torblocker-test -f Dockerfile.packaging .

# Run build in Docker
docker run --rm -v "$(pwd)/${BUILD_DIR}:/build" nginx-torblocker-test bash -c "
    cd /build
    dpkg-buildpackage -us -uc
"
