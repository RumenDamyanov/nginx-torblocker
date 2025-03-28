#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ensure GPG_KEY_ID is set (but don't require GPG_PASSPHRASE in the environment)
if [ -z "${GPG_KEY_ID:-}" ]; then
    echo -e "${RED}Error: GPG_KEY_ID is not set. Please export or hardcode your key ID.${NC}"
    exit 1
fi

# Ensure exactly one file argument is provided
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: $0 <file-to-sign> (.changes or .dsc)${NC}"
    exit 1
fi

FILE_TO_SIGN="$1"
if [ ! -f "${FILE_TO_SIGN}" ]; then
    echo -e "${RED}Error: File ${FILE_TO_SIGN} not found.${NC}"
    exit 1
fi

# Check allowed file extensions
if [[ ! "${FILE_TO_SIGN}" =~ \.(changes|dsc)$ ]]; then
    echo -e "${RED}Error: File extension must be .changes or .dsc${NC}"
    exit 1
fi

# Prompt the user for the passphrase
echo -e "${YELLOW}GPG_KEY_ID is ${GPG_KEY_ID}.${NC}"
echo -n -e "${YELLOW}Enter passphrase for GPG key ${GPG_KEY_ID}: ${NC}"
read -s GPG_PASSPHRASE
echo  # Move to a new line
if [ -z "${GPG_PASSPHRASE}" ]; then
    echo -e "${RED}No passphrase entered. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN}Signing ${FILE_TO_SIGN} with GPG key ${GPG_KEY_ID}...${NC}"

expect <<EOF
spawn debsign -p "gpg --batch --pinentry-mode=loopback" -k${GPG_KEY_ID} "${FILE_TO_SIGN}"
expect "Enter passphrase:"
send "${GPG_PASSPHRASE}\r"
expect eof
EOF

echo -e "${GREEN}Successfully signed ${FILE_TO_SIGN}.${NC}"
