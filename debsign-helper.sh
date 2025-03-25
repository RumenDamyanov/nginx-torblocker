#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Check required environment variables
if [ -z "${GPG_KEY_ID:-}" ]; then
    echo -e "${RED}Error: GPG_KEY_ID is not set${NC}"
    exit 1
fi

if [ -z "${GPG_PASSPHRASE:-}" ]; then
    echo -e "${RED}Error: GPG_PASSPHRASE is not set${NC}"
    exit 1
fi

# Sign the .changes file
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <path-to-changes-file>${NC}"
    exit 1
fi

CHANGES_FILE="$1"

if [ ! -f "${CHANGES_FILE}" ]; then
    echo -e "${RED}Error: Changes file ${CHANGES_FILE} not found.${NC}"
    exit 1
fi

echo -e "${GREEN}Signing ${CHANGES_FILE} with GPG key ${GPG_KEY_ID}...${NC}"

expect <<EOF
spawn debsign -k${GPG_KEY_ID} "${CHANGES_FILE}"
expect "Enter passphrase:"
send "${GPG_PASSPHRASE}\r"
expect eof
EOF

echo -e "${GREEN}Successfully signed ${CHANGES_FILE}.${NC}"
