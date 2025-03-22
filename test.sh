#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Error handler
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    docker compose logs nginx-dev
    exit 1
}

# Test module compilation
echo "Testing module compilation..."
./build-with-docker.sh || handle_error "Module compilation failed"

# Test module loading
echo "Testing module loading..."
docker compose exec nginx-dev nginx -t || handle_error "Module loading failed"

# Test configuration syntax
echo "Testing basic configuration..."
cat > test.conf << EOF
load_module modules/ngx_http_torblocker_module.so;
events {}
http {
    server {
        listen 80;
        torblock on;
        torblock_update_interval 3600000;
    }
}
EOF

docker compose exec nginx-dev nginx -t -c /build/test.conf || handle_error "Configuration test failed"

echo -e "${GREEN}All tests passed successfully!${NC}"
