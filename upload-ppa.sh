#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
PPA_NAME="ppa:rumenx/nginx-torblocker"
GPG_KEY_ID="BDEEFD02F0A7C07B4354D2F0C079961F4FAA534E"
VERSION="1.0.0"

# Check GPG key
if ! gpg --list-secret-keys ${GPG_KEY_ID} > /dev/null 2>&1; then
    echo -e "${RED}Error: GPG key ${GPG_KEY_ID} not found${NC}"
    echo "To list your keys, run: gpg --list-secret-keys --keyid-format LONG"
    exit 1
fi

# Check required files
check_file() {
    if [ ! -f "../$1" ]; then
        echo -e "${RED}Error: Required file $1 not found${NC}"
        exit 1
    fi
}

# Build source package
echo "Building source package..."
debuild -S -sa -k${GPG_KEY_ID}

# Verify all required files exist
check_file "nginx-torblocker_${VERSION}.orig.tar.gz"
check_file "nginx-torblocker_${VERSION}-1.debian.tar.xz"
check_file "nginx-torblocker_${VERSION}-1.dsc"
check_file "nginx-torblocker_${VERSION}-1_source.changes"

# Upload to PPA
echo "Uploading to PPA..."
dput ${PPA_NAME} ../nginx-torblocker_${VERSION}-1_source.changes

echo -e "${GREEN}Package uploaded successfully!${NC}"
echo "Check build status at: https://launchpad.net/~rumenx/+archive/ubuntu/nginx-torblocker"
