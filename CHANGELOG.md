# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.1] - 2026-10-28

### Security
- HTTPS fetches now verify the peer certificate against the system trust store and require the certificate hostname to match the URL
- The fetch client negotiates TLS 1.2 or TLS 1.3 only
- The outbound HTTP request buffer is sized from the URL

### Fixed
- OBS and vendored-header builds define `NGX_HTTP_SSL`, so the HTTPS client is included in the package
- HTTPS requests are written with `ngx_ssl_write`. The previous `ngx_ssl_send` call is not an nginx symbol, so the module would fail to load once that client is compiled in

## [2.1.0] - 2026-01-10

### Added
- **"torblock only" mode** - Allow ONLY Tor traffic, blocking clearnet requests
- Three operation modes: `off` (allow all), `on` (block Tor), `only` (Tor only)
- Useful for privacy-focused endpoints and anonymous submission portals

### Changed
- Updated documentation with new mode examples

## [2.0.0] - 2026-01-10

### Added
- Automatic URL-based Tor exit list fetching (no cron jobs needed!)
- HTTPS support for secure list fetching (requires nginx with SSL)
- Hash table for O(1) IP lookup performance
- Access phase handler for request blocking
- Automatic Tor exit node list updates
- Requires `resolver` directive in http block for DNS resolution

### Changed
- **BREAKING**: Major rewrite implementing actual Tor blocking functionality
- Updated all documentation to match implementation
- Fixed configuration inheritance model

## [1.1.0] - 2025-03-25

### Added
- Multi-distro and multi-nginx version support
- Enhanced build system for all Ubuntu releases
- Compatibility matrix for Ubuntu and Nginx versions

### Changed
- Improved compatibility with different Nginx versions

## [1.0.6] - 2025-03-25

### Changed
- Enhanced build system reliability
- Improved error reporting

### Fixed
- Temporary directory handling
- Updated packaging scripts

## [1.0.5] - 2025-03-23

### Changed
- Use system-provided nginx-dev
- Add dependencies from Nginx PPA when needed

### Fixed
- Permission issues in build script
- Error handling improvements

## [1.0.4] - 2025-03-22

### Changed
- Improved configuration validation
- Reduced memory footprint
- Updated documentation

## [1.0.3] - 2025-03-22

### Changed
- Enhanced memory management
- Optimized Tor exit node list updates

### Fixed
- Potential memory leak in configuration parsing

## [1.0.2] - 2025-03-22

### Changed
- Improved error handling
- Updated build system

### Added
- PPA release automation

## [1.0.1] - 2025-03-22

### Fixed
- Multi-architecture support
- Support for both amd64 and arm64 builds

## [1.0.0] - 2025-03-22

### Added
- Initial release
- Basic Tor blocking module for Nginx
- `torblock` directive for enabling/disabling Tor blocking

[Unreleased]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.0.6...v1.1.0
[1.0.6]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/RumenDamyanov/nginx-torblocker/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/RumenDamyanov/nginx-torblocker/releases/tag/v1.0.0
