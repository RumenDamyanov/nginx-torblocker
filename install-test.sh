#!/bin/sh
set -e

# Test if module can be loaded by nginx
nginx -t -c /etc/nginx/nginx.conf

# Check if module can be loaded directly
cat > /etc/nginx/modules-available/torblocker.conf <<EOF
load_module /usr/lib/nginx/modules/ngx_http_torblocker_module.so;
EOF

ln -sf /etc/nginx/modules-available/torblocker.conf /etc/nginx/modules-enabled/

# Try to restart nginx
nginx -t && systemctl restart nginx
