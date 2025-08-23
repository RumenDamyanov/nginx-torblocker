# Contributing to nginx-torblocker

Thanks for your interest in improving nginx-torblocker! This Nginx module helps protect web servers by blocking Tor exit nodes with granular control.

## Ways to Help

- **Report bugs**: Include reproduction steps, environment details (Nginx version, OS, module config)
- **Propose enhancements**: Outline use case and provide minimal configuration examples
- **Improve documentation**: Fix clarity, add examples, correct spelling/grammar
- **Add tests**: Edge cases, configuration validation, memory leak detection
- **Performance testing**: Benchmark impact on request processing

## Development Setup

### Prerequisites

- Nginx source code (1.24+ recommended)
- GCC compiler and build tools
- Development libraries: `libpcre3-dev`, `zlib1g-dev`
- Git for version control

### Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/RumenDamyanov/nginx-torblocker.git
   cd nginx-torblocker
   ```

2. **Download Nginx source** (match your target version):
   ```bash
   wget https://nginx.org/download/nginx-1.26.0.tar.gz
   tar xzf nginx-1.26.0.tar.gz
   ```

3. **Build the module**:
   ```bash
   cd nginx-1.26.0
   ./configure --add-dynamic-module=../src
   make modules
   ```

4. **Test the build**:
   ```bash
   # Check module exists
   ls objs/ngx_http_torblocker_module.so
   
   # Basic load test
   nginx -t -c ../conf/test.conf
   ```

### Testing Your Changes

- **Build test**: Ensure module compiles without warnings
- **Configuration test**: Validate directive parsing works correctly
- **Memory test**: Check for leaks with valgrind (if available)
- **Integration test**: Load module in running Nginx instance

## Coding Guidelines

### C Code Style
- Follow Nginx coding conventions
- Use Nginx memory pools (`ngx_palloc`, `ngx_pcalloc`)
- Implement proper cleanup handlers
- Handle all error conditions gracefully
- Add meaningful comments for complex logic

### Configuration
- Keep directives simple and intuitive
- Provide sensible defaults
- Support inheritance (http > server > location)
- Validate user input thoroughly

### Example Code Pattern
```c
// Good: Nginx-style error handling
conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_torblocker_conf_t));
if (conf == NULL) {
    return NULL;
}

// Good: Proper cleanup registration
cln = ngx_pool_cleanup_add(cf->pool, 0);
if (cln == NULL) {
    return NULL;
}
cln->handler = ngx_http_torblocker_cleanup;
```

## Commit Style

- **Format**: `type: brief description`
- **Types**: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`
- **Examples**:
  - `feat: add torblock_response_code directive`
  - `fix: prevent memory leak in cleanup handler`
  - `docs: update build instructions for macOS`

## Pull Requests

1. **Open issue first** (except for trivial fixes) describing the problem/enhancement
2. **Fork and branch**: Use descriptive branch names (`feature/custom-response-codes`)
3. **Add tests**: Include test cases or explain why testing isn't applicable
4. **Ensure CI passes**: All build matrix combinations must succeed
5. **Update documentation**: Modify README.md if adding features
6. **Submit PR**: Reference the issue number in PR description

### PR Checklist
- [ ] Code follows Nginx conventions
- [ ] No memory leaks introduced
- [ ] Configuration properly validates input
- [ ] Documentation updated (if needed)
- [ ] CI builds pass on all platforms

## Architecture Notes

- **Module Type**: HTTP dynamic module
- **Configuration**: Supports http/server/location contexts
- **Memory Management**: Uses Nginx pools exclusively
- **Error Handling**: Follows Nginx patterns (return codes)
- **Threading**: Must be thread-safe (Nginx may use worker processes)

## Code of Conduct

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Please be respectful and constructive in all interactions.

## License

By contributing, you agree that your contributions will be licensed under the BSD License (see [LICENSE.md](LICENSE.md)).
