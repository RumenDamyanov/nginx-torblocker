# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to download Nginx sources
download_nginx_sources() {
    local nginx_version=$1
    local dest_dir=$2

    echo -e "${YELLOW}Downloading Nginx sources for version ${nginx_version}...${NC}"

    mkdir -p "${dest_dir}"
    local tarball="${dest_dir}/nginx-${nginx_version}.tar.gz"

    if [ ! -f "${tarball}" ]; then
        wget -q -O "${tarball}" "https://nginx.org/download/nginx-${nginx_version}.tar.gz"
    fi

    echo -e "${GREEN}Nginx sources downloaded successfully.${NC}"
}

# Function to extract Nginx headers
extract_nginx_headers() {
    local nginx_version=$1
    local dest_dir=$2

    echo -e "${YELLOW}Extracting Nginx headers for version ${nginx_version}...${NC}"

    mkdir -p "${dest_dir}/headers/nginx-${nginx_version}"
    tar -xzf "${dest_dir}/nginx-${nginx_version}.tar.gz" -C "${dest_dir}/headers/nginx-${nginx_version}" --strip-components=1

    echo -e "${GREEN}Nginx headers extracted successfully.${NC}"
}
