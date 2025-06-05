# Nginx TorBlocker

A simple Nginx module to block access from Tor exit nodes.

## Features

- Blocks requests from Tor exit nodes
- Regularly updates the list of Tor exit nodes
- Easy to configure and integrate with Nginx
- Per-location and per-server configuration

## Repository Structure

- `src/` — Nginx module source code
- `debian/` — Packaging files (for building .deb packages)
- `conf/` — Example configuration

## Quick Build Instructions

### Prerequisites

- Nginx source code matching your installed version
- Build tools: gcc, make, libpcre3-dev, zlib1g-dev, etc.

### Build the Module

1. Clone this repository:

   ```sh
   git clone https://github.com/RumenDamyanov/nginx-torblocker.git
   cd nginx-torblocker
   ```

2. Download and extract the Nginx source for your version (see `nginx-sources/` for examples).

3. Build the module:

   ```sh
   cd src
   make
   # or manually:
   # gcc -fPIC -shared -o ngx_http_torblocker_module.so ngx_http_torblocker_module.c ...
   ```

4. Copy the resulting `.so` file to your Nginx modules directory.

### Load the Module in Nginx

Add to the top of your `nginx.conf`:

```nginx
load_module modules/ngx_http_torblocker_module.so;
```

## Configuration Example

See `conf/test.conf` for a full example. Basic usage:

```nginx
http {
    torblock on;
}
```

### Advanced Configuration

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

### Combining Global, Server, and Location Settings

You can enable or disable the module at different levels for flexible access control. For example:

```nginx
http {
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

## Debian/Ubuntu PPA (Testing Only)

A PPA is available for convenience, but it is currently **unstable and for testing purposes only**. The recommended way to use the module is to build it yourself from source (see above).

## License

BSD License. See [LICENSE.md](LICENSE.md).
