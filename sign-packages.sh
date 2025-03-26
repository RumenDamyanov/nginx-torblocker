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
if [ -z "${GPG_KEY_ID:-}" ]; then
    echo -e "${RED}Error: GPG_KEY_ID is not set${NC}"
    exit 1
fi

if [ -z "${GPG_PASSPHRASE:-}" ]; then
    echo -e "${RED}Error: GPG_PASSPHRASE is not set${NC}"
    exit 1
fi

# Ensure the output directory exists
if [ ! -d "${OUTPUT_DIR}" ]; then
    echo -e "${RED}Error: Output directory ${OUTPUT_DIR} does not exist${NC}"
    exit 1
fi

echo -e "${YELLOW}Searching for .changes and .dsc files in ${OUTPUT_DIR}...${NC}"
# Collect all changes and dsc files
FILES_TO_SIGN=$(find "${OUTPUT_DIR}" -type f \( -name "*.changes" -o -name "*.dsc" \))

if [ -z "$FILES_TO_SIGN" ]; then
    echo -e "${RED}No .changes or .dsc files found in ${OUTPUT_DIR}.${NC}"
    exit 0   # Not an error, just nothing to sign
fi

# Sign each file
for FILE_TO_SIGN in $FILES_TO_SIGN; do
    # Check if the file is already signed
    if grep -q "BEGIN PGP SIGNATURE" "${FILE_TO_SIGN}"; then
        echo -e "${YELLOW}Skipping already signed file: ${FILE_TO_SIGN}${NC}"
        continue
    fi

    echo -e "${YELLOW}Signing ${FILE_TO_SIGN}...${NC}"

    FILEDIR=$(cd "$(dirname "${FILE_TO_SIGN}")" && pwd)
    FILENAME=$(basename "${FILE_TO_SIGN}")

    docker run --rm \
        -v "${FILEDIR}:/project" \
        -v "$HOME/.gnupg:/root/.gnupg:rw" \
        -e "GPG_KEY_ID=${GPG_KEY_ID}" \
        -e "GPG_PASSPHRASE=${GPG_PASSPHRASE}" \
        nginx-torblocker-signing bash -c "
        debsign-helper /project/${FILENAME};
        echo 'Signed file: /project/${FILENAME}';
    "

    echo -e "${GREEN}Successfully signed ${FILE_TO_SIGN}.${NC}"
done

echo -e "${GREEN}All files have been signed successfully.${NC}"
