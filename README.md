[![OBS Build Status](https://build.opensuse.org/projects/home:rumenx/packages/nginx-torblocker/badge.svg?type=default)](https://build.opensuse.org/package/show/home:rumenx/nginx-torblocker)
[![GitHub Release](https://img.shields.io/github/v/release/RumenDamyanov/nginx-torblocker?label=Release)](https://github.com/RumenDamyanov/nginx-torblocker/releases)
[![License](https://img.shields.io/github/license/RumenDamyanov/nginx-torblocker?label=License)](LICENSE.md)
[![Platform Support](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu%20%7C%20Fedora%20%7C%20openSUSE%20%7C%20RHEL-blue)](https://build.opensuse.org/package/show/home:rumenx/nginx-torblocker)

# Nginx TorBlocker

A simple Nginx module to block access from Tor exit nodes.

## Features

- Blocks requests from Tor exit nodes
- **Automatically fetches** the Tor exit node list from URL (no cron jobs needed!)
- **HTTPS support** for secure list fetching (requires nginx with SSL support)
- Configurable update interval for automatic list refresh
- Easy to configure and integrate with Nginx
- Per-location and per-server configuration

## Documentation & Support

📖 **[Complete Documentation](https://github.com/RumenDamyanov/nginx-torblocker/wiki)** - Comprehensive guides, tutorials, and reference materials

💬 **[Community Discussions](https://github.com/RumenDamyanov/nginx-torblocker/discussions)** - Ask questions, share experiences, and get help from the community

### Quick Links to Wiki Articles

- 🏠 **[Home](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Home)** - Overview and getting started
- 📦 **[Installation Guide](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Installation-Guide)** - Step-by-step installation instructions
- 🔨 **[Building from Source](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Building-from-Source)** - Compile the module yourself
- 📋 **[Configuration Reference](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Configuration-Reference)** - Complete directive documentation
- ⚙️ **[Basic Configuration](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Basic-Configuration)** - Simple setup examples
- 🚀 **[Advanced Configuration](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Advanced-Configuration)** - Complex policies and patterns
- 🔗 **[Context Hierarchy](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Context-Hierarchy)** - Understanding configuration inheritance
- 🎯 **[Site-Specific Blocking](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Site-Specific-Blocking)** - Per-site configuration
- 🛣️ **[Path-Based Blocking](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Path-Based-Blocking)** - URL-specific rules
- 🌐 **[Server-Wide Blocking](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Server-Wide-Blocking)** - Global configuration
- 🔀 **[Mixed Policies](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Mixed-Policies)** - Combining different approaches
- 📥 **[Module Loading](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Module-Loading)** - Loading and initializing the module
- 🧪 **[Testing Procedures](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Testing-Procedures)** - Validate functionality and performance
- 🔧 **[Troubleshooting Guide](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Troubleshooting-Guide)** - Solve common issues
- ⚡ **[Performance Tuning](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Performance-Tuning)** - Optimize for your environment
- 📊 **[Monitoring & Logging](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Monitoring-Logging)** - Observability and metrics
- 🛠️ **[Development Setup](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Development-Setup)** - Contributing and development environment

## Repository Structure

- `src/` — Nginx module source code
- `debian/` — Packaging files (for building .deb packages)
- `conf/` — Example configuration

## Installation

### Package Installation (Recommended)

Pre-built packages are available for multiple Linux distributions via the [openSUSE Build Service](https://build.opensuse.org/package/show/home:rumenx/nginx-torblocker).

#### Debian / Ubuntu

```bash
# Add the repository
echo "deb http://download.opensuse.org/repositories/home:/rumenx/xUbuntu_24.04/ /" | sudo tee /etc/apt/sources.list.d/nginx-torblocker.list

# Add the repository key
curl -fsSL https://download.opensuse.org/repositories/home:/rumenx/xUbuntu_24.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/nginx-torblocker.gpg > /dev/null

# Update and install
sudo apt update
sudo apt install nginx-torblocker
```

**Supported Versions:**

- Ubuntu 24.04 (Noble) - Use `xUbuntu_24.04`
- Ubuntu 22.04 (Jammy) - Use `xUbuntu_22.04`
- Debian 12 (Bookworm) - Use `Debian_12`
- Debian 13 (Trixie) - Use `Debian_13`

Replace `xUbuntu_24.04` in the commands above with your distribution version.

#### Fedora

```bash
# Add the repository
sudo dnf config-manager --add-repo https://download.opensuse.org/repositories/home:/rumenx/Fedora_41/home:rumenx.repo

# Install the package
sudo dnf install nginx-torblocker
```

**Supported Versions:**

- Fedora 42 - Use `Fedora_42`
- Fedora 41 - Use `Fedora_41`
- Fedora 40 - Use `Fedora_40`

#### openSUSE

```bash
# Add the repository
sudo zypper addrepo https://download.opensuse.org/repositories/home:/rumenx/openSUSE_Tumbleweed/home:rumenx.repo

# Refresh repositories
sudo zypper refresh

# Install the package
sudo zypper install nginx-torblocker
```

**Supported Versions:**

- openSUSE Tumbleweed - Use `openSUSE_Tumbleweed`
- openSUSE Leap 15.6 - Use `openSUSE_Leap_15.6`
- openSUSE Leap 16.0 - Use `openSUSE_Leap_16.0`

#### RHEL / CentOS / Rocky Linux / AlmaLinux

```bash
# Add the repository (RHEL 9 example)
sudo dnf config-manager --add-repo https://download.opensuse.org/repositories/home:/rumenx/RHEL_9/home:rumenx.repo

# Install the package
sudo dnf install nginx-torblocker
```

**Supported Versions:**

- RHEL/CentOS 9 - Use `RHEL_9`
- RHEL/CentOS 8 - Use `RHEL_8`
- RHEL/CentOS 7 - Use `RHEL_7`

### After Installation

After installing the package, the module will be installed to:

- **Debian/Ubuntu**: `/usr/lib/nginx/modules/ngx_http_torblocker_module.so`
- **Fedora/RHEL/openSUSE**: `/usr/lib64/nginx/modules/ngx_http_torblocker_module.so`

Load the module by adding to the top of your `/etc/nginx/nginx.conf`:

```nginx
load_module modules/ngx_http_torblocker_module.so;
```

Then restart nginx:

```bash
sudo systemctl restart nginx
```

## Quick Build Instructions

📖 **For detailed build instructions and installation guides, see the [Building from Source](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Building-from-Source) and [Installation Guide](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Installation-Guide) wiki pages.**

💾 **Pre-built packages are available on the [Releases page](https://github.com/RumenDamyanov/nginx-torblocker/releases) for Ubuntu 22.04/24.04/25.04 with various Nginx versions.**

### Prerequisites

- **Nginx installed** on your system
- **Nginx source code** matching your installed version
- **Build tools**: gcc, make, wget
- **Development libraries**: libpcre3-dev, zlib1g-dev

You can install the prerequisites on Ubuntu/Debian:

```sh
sudo apt-get update
sudo apt-get install build-essential gcc libpcre3-dev zlib1g-dev wget
```

On CentOS/RHEL:

```sh
sudo yum groupinstall "Development Tools"
sudo yum install pcre-devel zlib-devel wget
```

### Build the Module

1. Clone this repository:

   ```sh
   git clone https://github.com/RumenDamyanov/nginx-torblocker.git
   cd nginx-torblocker
   ```

2. Download and extract the Nginx source for your version:

   ```sh
   # Check your Nginx version first
   nginx -v
   
   # Download matching source (example for 1.26.0)
   wget https://nginx.org/download/nginx-1.26.0.tar.gz
   tar xzf nginx-1.26.0.tar.gz
   cd nginx-1.26.0
   ```

3. Configure and build the module:

   ```sh
   # Configure Nginx with the module
   ./configure --add-dynamic-module=../src
   
   # Build only the modules (not full Nginx)
   make modules
   ```

4. Install the module:

   ```sh
   # Copy to your Nginx modules directory
   sudo cp objs/ngx_http_torblocker_module.so /usr/lib/nginx/modules/
   
   # Or to a custom location
   sudo cp objs/ngx_http_torblocker_module.so /etc/nginx/modules/
   ```

### Load the Module in Nginx

Add to the top of your `nginx.conf`:

```nginx
load_module modules/ngx_http_torblocker_module.so;
```

## Configuration Example

See `conf/test.conf` for a full example. Basic usage:

```nginx
http {
    # Required: DNS resolver for fetching the Tor exit list
    resolver 1.1.1.1 9.9.9.9;
    
    # Enable Tor blocking (uses default URL and update interval)
    torblock on;
}
```

The module **automatically fetches** the Tor exit node list from the Tor Project - no cron jobs or external scripts needed!

## Configuration Reference

📋 **For complete configuration details, see the [Configuration Reference](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Configuration-Reference) wiki page.**

### Directives

| Directive | Context | Default | Description |
|-----------|---------|---------|-------------|
| `torblock` | http, server, location | `off` | Enable/disable Tor blocking |
| `torblock_list_url` | http | `https://check.torproject.org/torbulkexitlist` | URL for Tor exit node list |
| `torblock_update_interval` | http | `3600000` | Auto-update interval in ms (1 hour) |

**Notes:**

- The module requires a `resolver` directive in the http block for DNS resolution. You can also use a local resolver like `127.0.0.53` (systemd-resolved) or `127.0.0.1` (dnsmasq/unbound) for better privacy.
- **HTTPS Support**: The default URL uses HTTPS. If your nginx wasn't built with SSL support (`--with-http_ssl_module`), you can use an HTTP URL instead: `http://check.torproject.org/torbulkexitlist`

### Context Hierarchy

The module supports configuration at three levels with inheritance:

- **HTTP context**: Global default for all servers
- **Server context**: Per virtual host settings  
- **Location context**: Per URL path settings

Child contexts inherit from parent contexts, and more specific settings override general ones.

📖 **Learn more about [Context Hierarchy](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Context-Hierarchy) in the wiki.**

## Usage Examples

🚀 **For advanced configuration examples, see the [Advanced Configuration](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Advanced-Configuration) wiki page.**

### Basic Configuration

```nginx
http {
    resolver 1.1.1.1 9.9.9.9;  # Required for DNS resolution
    
    # Enable Tor blocking with automatic list updates
    torblock on;
}
```

### Advanced Configuration

```nginx
http {
    resolver 1.1.1.1 9.9.9.9 valid=300s;
    resolver_timeout 5s;
    
    # Optional: custom URL and update interval
    torblock_list_url "https://check.torproject.org/torbulkexitlist";
    torblock_update_interval 600000; # Update every 10 minutes

    # Per-server configuration
    server {
        torblock off; # Disable for this server

        location /api {
            torblock on; # Re-enable for specific location
        }
    }
    
    server {
        server_name secure.example.com;
        torblock on; # Enable for this server
        
        location /public {
            torblock off; # Allow Tor for public content
        }
    }
}
```

### Selective Blocking by Location

```nginx
http {
    resolver 1.1.1.1 9.9.9.9;
    torblock off;  # Default: allow Tor

    server {
        listen 80;
        server_name example.com;

        # Public content - Tor allowed
        location / {
            root /var/www/html;
        }

        # Admin area - block Tor
        location /admin {
            torblock on;
        }

        # API - block Tor
        location /api {
            torblock on;
        }
    }
}
```

### Combining Global, Server, and Location Settings

You can enable or disable the module at different levels for flexible access control. For example:

```nginx
http {
    resolver 1.1.1.1 9.9.9.9;
    torblock off; # Default: allow Tor everywhere

    # Enable Tor blocking only for a specific vhost
    server {
        server_name sensitive.example.com;
        torblock on; # Block Tor for this vhost

        # But allow Tor for a specific location (e.g., public API)
        location /public-api {
            torblock off;
        }
    }

    # Another vhost with default (Tor allowed)
    server {
        server_name open.example.com;
        # torblock remains off
    }
}
```

**Use case:**

- This setup is helpful if you want to block Tor for sensitive parts of your site (e.g., admin panels or private content) but allow Tor users to access public APIs or open resources. You can also have some vhosts open to Tor and others protected, all in the same Nginx instance.

## Troubleshooting

🔧 **For comprehensive troubleshooting guides, see:**

- **[Troubleshooting Guide](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Troubleshooting-Guide)** - Detailed diagnostic procedures and solutions
- **[Testing Procedures](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Testing-Procedures)** - Validate your configuration and performance
- **[Performance Tuning](https://github.com/RumenDamyanov/nginx-torblocker/wiki/Performance-Tuning)** - Optimize for your environment

💬 **Need help?** Visit our [Community Discussions](https://github.com/RumenDamyanov/nginx-torblocker/discussions) to ask questions and get support.

### Common Issues

#### Module fails to load

```
nginx: [emerg] dlopen() "/usr/lib/nginx/modules/ngx_http_torblocker_module.so" failed
```

**Solutions:**

- Ensure the module was built against the same Nginx version you're running
- Check file permissions: `chmod 644 /usr/lib/nginx/modules/ngx_http_torblocker_module.so`
- Verify the module path in your `load_module` directive

#### Configuration test fails

```
nginx: [emerg] unknown directive "torblock"
```

**Solutions:**

- Ensure `load_module` directive is at the top of `nginx.conf` (before any `http` block)
- Verify the module file exists and is readable
- Check Nginx error logs for detailed error messages

#### Module version mismatch

```
nginx: [emerg] module "/usr/lib/nginx/modules/ngx_http_torblocker_module.so" version 1024000 instead of 1026000
```

**Solutions:**

- Rebuild the module against your exact Nginx version
- Download the correct Nginx source version with `nginx -v`

### Performance Considerations

- **Memory usage**: The module maintains an in-memory list of Tor exit nodes
- **Update frequency**: Default 1-hour updates balance freshness with performance
- **Request overhead**: Minimal impact - simple IP lookup per request
- **Concurrent requests**: Module is thread-safe for multi-worker configurations

### Debugging

Enable debug logging in Nginx:

```nginx
error_log /var/log/nginx/debug.log debug;
```

Check for module-specific messages:

```bash
grep torblock /var/log/nginx/error.log
```

## Background & Inspiration

This module is inspired by a PHP script I developed over 20 years ago called [AntiTor](https://github.com/RumenDamyanov/antitor), which successfully blocked Tor access to web servers. The original script was effective but limited in scope.

The nginx-torblocker module brings this concept into the modern era with several key improvements:

- **Native performance**: Runs at the Nginx level instead of PHP application layer
- **Granular control**: Enable/disable blocking per virtual host or location
- **Selective access**: Allow Tor for public resources while blocking sensitive areas
- **Multi-site support**: Different policies for multiple sites on the same server
- **Automatic updates**: Keeps Tor exit node lists current without manual intervention

This refined approach allows for sophisticated access control policies that weren't possible with the original script, making it suitable for complex hosting environments where different sites may have different security requirements.

## Binary Packages & Distribution

### Official Distribution

The primary distribution channel for pre-built binaries is the [GitHub Releases page](https://github.com/RumenDamyanov/nginx-torblocker/releases), which provides:

- **Binary packages** for Ubuntu 22.04 LTS (jammy), 24.04 LTS (noble), and 25.04 (plucky)
- **Multiple architectures**: amd64 and arm64
- **Multiple nginx versions**: Compatible with nginx 1.26.x and 1.27.x series
- **Debian packages (.deb)** for native installation via `dpkg`

### PPA Status

The experimental Ubuntu PPA is **no longer supported** and has been discontinued. It was never an official distribution channel and proved unreliable for production use.

### Future Plans

A self-hosted apt repository is planned to provide signed, reproducible builds without third-party hosting constraints. This repository will host multiple packages from our projects and will target:

- Ubuntu 24.04 LTS (noble) and newer versions
- Ubuntu 25.04 (plucky) and newer versions

For now, please use the official GitHub Releases or build from source.

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for detailed information on:

- Setting up the development environment
- Coding guidelines and best practices
- Testing procedures
- Pull request process

Please also read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

🗣️ **Join the conversation**: Use our [Community Discussions](https://github.com/RumenDamyanov/nginx-torblocker/discussions) to:

- Propose new features or improvements
- Share your use cases and configurations
- Get help with development setup
- Connect with other contributors and users

## Security

Security is important to us. If you discover a security vulnerability, please see our [Security Policy](SECURITY.md) for information on how to report it responsibly.

## Funding

If you find this project useful, please consider supporting its development. See [FUNDING.md](FUNDING.md) for information about sponsorship and donations.

## License

BSD License. See [LICENSE.md](LICENSE.md).
