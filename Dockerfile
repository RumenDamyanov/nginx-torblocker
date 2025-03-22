FROM ubuntu:24.04

# Install build dependencies and nginx
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libgeoip-dev \
    libperl-dev \
    git \
    wget \
    vim \
    curl \
    sudo \
    nano \
    nginx

# Get installed nginx version, clean it and store it
RUN NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2 | sed 's/ (Ubuntu)//') && \
    echo "$NGINX_VERSION" > /tmp/nginx_version && \
    echo "Detected nginx version: $NGINX_VERSION" && \
    wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
    tar -zxf "nginx-${NGINX_VERSION}.tar.gz" && \
    rm "nginx-${NGINX_VERSION}.tar.gz"

WORKDIR /build
