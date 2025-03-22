# Nginx TorBlocker

[![Build Status](https://github.com/RumenDamyanov/nginx-torblocker/actions/workflows/build.yml/badge.svg)](https://github.com/RumenDamyanov/nginx-torblocker/actions/workflows/build.yml)

A simple Nginx module to block access from Tor exit nodes.

## Features

- Automatically blocks requests from Tor exit nodes
- Regularly updates the list of Tor exit nodes
- Easy to configure and integrate with existing Nginx installations
- Supports per-location and per-server configuration
- Compatible with Nginx versions 1.18.0 and later

## Prerequisites

- Nginx installed on your system
- Build tools (build-essential, libpcre3-dev, etc.)
- Docker (optional, for development)

## Installation

### Option 1: Direct Installation

1. Check your Nginx version:
```bash
nginx -v
```

2. Clone the repository:
```bash
git clone https://github.com/RumenDamyanov/nginx-torblocker.git
cd nginx-torblocker
```

3. Build and install the module:
```bash
./build.sh
```

### Option 2: Docker-based Build

```bash
./build-with-docker.sh
```

## Configuration

### 1. Load the Module

Add this to the beginning of your nginx.conf:

```nginx
load_module modules/ngx_http_torblocker_module.so;
```

### 2. Basic Configuration

```nginx
http {
    # Enable globally with defaults
    torblock on;
}
```

### 3. Advanced Configuration

```nginx
http {
    # Configure custom settings
    torblock on;
    torblock_list_url "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$remote_addr";
    torblock_update_interval 600000; # 10 minutes

    # Per-server configuration
    server {
        torblock off; # Disable for specific server

        # Per-location configuration
        location /api {
            torblock on; # Re-enable for specific location
        }
    }
}
```

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `torblock` | Enable/disable the module | `off` |
| `torblock_list_url` | URL for Tor exit node list | Tor Project API |
| `torblock_update_interval` | Update interval in milliseconds | 3600000 (1 hour) |

## Examples

### Block Tor access except for specific IP
```nginx
http {
    torblock on;

    # Allow specific IP even if it's a Tor exit node
    geo $allow_tor {
        default 0;
        192.168.1.100 1;
    }

    server {
        if ($allow_tor) {
            set $torblock "off";
        }
    }
}
```

## Troubleshooting

### Common Issues

1. Module version mismatch:
```bash
nginx -v
# Ensure module is built against this exact version
```

2. Permission issues:
```bash
# Check module permissions
ls -l /usr/lib/nginx/modules/ngx_http_torblocker_module.so
```

## License

BSD License. See [LICENSE.md](LICENSE.md) for more details.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security Considerations

- The module performs network requests to update the Tor exit node list
- Ensure your server can access check.torproject.org
- Consider rate limiting and timeouts for list updates

## Support

- GitHub Issues: [Report a bug](https://github.com/RumenDamyanov/nginx-torblocker/issues)
- Pull Requests: [Submit a PR](https://github.com/RumenDamyanov/nginx-torblocker/pulls)
