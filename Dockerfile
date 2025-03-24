FROM ubuntu:24.04

# Install basic tools and add the universe repository
RUN apt-get update && apt-get install -y \
    software-properties-common && \
    add-apt-repository universe && \
    apt-get update

# Add the official Nginx repository
RUN apt-get install -y curl gnupg2 ca-certificates && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list && \
    apt-get update

# Pin the Nginx version to 1.24.0
RUN apt-get update && apt-get install -y \
    nginx=1.24.0-1~$(lsb_release -cs) \
    nginx-dev=1.24.0-1~$(lsb_release -cs) \
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
    nano && \
    apt-mark hold nginx nginx-dev

# Verify nginx-dev installation
RUN dpkg -l | grep nginx-dev || { echo "Error: nginx-dev package is not installed"; exit 1; }

WORKDIR /build
