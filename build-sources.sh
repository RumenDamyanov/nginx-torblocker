#!/bin/bash

set -euo pipefail

# Load config
source config.env
source common-functions.sh

# Variables
BUILD_DIR="./build"                       # Unified build directory
OUTPUT_DIR="${OUTPUT_DIR:-packages}"      # Directory to store completed builds
ARCHITECTURES="${ARCHITECTURES:-amd64 arm64}"
COMPATIBILITY_MATRIX="${COMPATIBILITY_MATRIX:-}"
DOCKER_IMAGE_BASE="nginx-torblocker-packaging"

# Prepare build directory
mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}"/*

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Iterate through architectures, Ubuntu versions, and Nginx versions
for ARCH in ${ARCHITECTURES}; do
    while IFS=: read -r UBUNTU_VERSION NGINX_VERSION; do
        if [[ -z "${UBUNTU_VERSION}" || -z "${NGINX_VERSION}" ]]; then
            continue  # Skip empty lines
        fi

        # Strip the final minor version if needed, e.g. 1.24.0 -> 1.24
        NGINX_VERSION_SHORT=$(echo "${NGINX_VERSION}" | awk -F. '{print $1 "." $2}')

        echo -e "${YELLOW}Building source files for Architecture: ${ARCH}, Ubuntu: ${UBUNTU_VERSION}, Nginx: ${NGINX_VERSION_SHORT}${NC}"

        # Set architecture-specific directory
        ARCH_DIR="obj-$(dpkg-architecture -a${ARCH} -qDEB_HOST_GNU_TYPE)"

        # Create Docker image name
        DOCKER_IMAGE="${DOCKER_IMAGE_BASE}-${ARCH}-${UBUNTU_VERSION}"

        # Prepare build directory for this combination
        mkdir -p "${BUILD_DIR}/${ARCH_DIR}"
        rm -rf "${BUILD_DIR}/${ARCH_DIR:?}"/*

        # Download and extract Nginx sources
        echo -e "${YELLOW}Downloading and extracting Nginx sources for version ${NGINX_VERSION}...${NC}"
        wget -q -O "${BUILD_DIR}/nginx-${NGINX_VERSION}.tar.gz" \
            "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"

        mkdir -p "${BUILD_DIR}/headers/nginx-${NGINX_VERSION}"
        tar -xzf "${BUILD_DIR}/nginx-${NGINX_VERSION}.tar.gz" \
            -C "${BUILD_DIR}/headers/nginx-${NGINX_VERSION}" --strip-components=1
        echo -e "${GREEN}Nginx sources downloaded and extracted successfully.${NC}"

        # Copy module source files
        cp -r src "${BUILD_DIR}/"
        cp -r debian "${BUILD_DIR}/"
        cp build-module.sh "${BUILD_DIR}/"

        # Build Docker image
        docker build -t "${DOCKER_IMAGE}" \
            --build-arg UBUNTU_VERSION="${UBUNTU_VERSION}" \
            --build-arg NGINX_VERSION="${NGINX_VERSION}" \
            -f Dockerfile.packaging .

        # Run build in Docker
        docker run --rm \
            -v "$(pwd)/${BUILD_DIR}:/project" \
            -v "$(pwd)/${OUTPUT_DIR}:/output" \
            "${DOCKER_IMAGE}" bash -c "
            set -e;
            echo 'Listing /project directory inside the container:';
            ls -l /project;

            # Reset debian/changelog
            if [ -f debian/changelog ]; then
                rm -f debian/changelog;
            fi

            echo 'Creating new changelog for Ubuntu ${UBUNTU_VERSION} and Nginx ${NGINX_VERSION_SHORT}...';
            dch --create \
                --package nginx-torblocker \
                --newversion '${VERSION}~${UBUNTU_VERSION}+nginx${NGINX_VERSION_SHORT}' \
                --distribution '${UBUNTU_VERSION}' \
                'Build for Ubuntu ${UBUNTU_VERSION} with Nginx ${NGINX_VERSION_SHORT}.';

            # Configure and build minimal Nginx to generate headers
            cd /project/headers/nginx-${NGINX_VERSION};
            ./configure --without-http_rewrite_module --without-http_gzip_module;
            make;

            # Copy auto headers if generated
            if [ -f objs/ngx_auto_headers.h ]; then
                cp objs/ngx_auto_headers.h /project/headers/nginx-${NGINX_VERSION}/src/core/;
            else
                echo 'Error: objs/ngx_auto_headers.h not found!';
                exit 1;
            fi

            # Create architecture-specific directory
            mkdir -p /project/${ARCH_DIR};

            # Build the source package only (no .deb)
            echo 'Building source package...';
            cd /project;
            dpkg-buildpackage -S -us -uc;

            echo 'Moving source package files to output directory...';
            mkdir -p /output/nginx-torblocker_${VERSION}~${UBUNTU_VERSION}+nginx${NGINX_VERSION_SHORT}_${ARCH}
            mv ../*.dsc /output/nginx-torblocker_${VERSION}~${UBUNTU_VERSION}+nginx${NGINX_VERSION_SHORT}_${ARCH}/ || echo 'No .dsc files to move.';
            mv ../*.changes /output/nginx-torblocker_${VERSION}~${UBUNTU_VERSION}+nginx${NGINX_VERSION_SHORT}_${ARCH}/ || echo 'No .changes files to move.';
            mv ../*.tar.* /output/nginx-torblocker_${VERSION}~${UBUNTU_VERSION}+nginx${NGINX_VERSION_SHORT}_${ARCH}/ || echo 'No .tar.* found.';
            mv ../*.buildinfo /output/nginx-torblocker_${VERSION}~${UBUNTU_VERSION}+nginx${NGINX_VERSION_SHORT}_${ARCH}/ || echo 'No .buildinfo found.';
        "

        echo -e "${GREEN}Source packages moved to ${OUTPUT_DIR}.${NC}"
    done <<< "${COMPATIBILITY_MATRIX}"
done
