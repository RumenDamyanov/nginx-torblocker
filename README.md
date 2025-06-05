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

## Debian/Ubuntu PPA (Testing Only)

A PPA is available for convenience, but it is currently **unstable and for testing purposes only**. The recommended way to use the module is to build it yourself from source (see above).

## License

BSD License. See [LICENSE.md](LICENSE.md).
