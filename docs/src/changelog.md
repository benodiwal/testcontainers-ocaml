# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial release of Testcontainers OCaml
- Core container lifecycle management
  - `Container.start`, `Container.stop`, `Container.terminate`
  - `Container.with_container` for automatic cleanup
  - Container exec, logs, and state inspection
- Container request builder with fluent API
  - Port exposure and mapping
  - Environment variables
  - Volume mounts (bind, named, tmpfs)
  - Commands and entrypoints
  - Labels and names
- Wait strategies
  - `for_listening_port` - Wait for TCP port
  - `for_log` - Wait for log message
  - `for_log_regex` - Wait for log pattern
  - `for_http` - Wait for HTTP endpoint
  - `for_exec` - Wait for command success
  - `for_health_check` - Wait for Docker health check
  - `all` and `any` combinators
  - Configurable timeouts and poll intervals
- Docker network support
  - `Network.create` and `Network.remove`
  - `Network.with_network` for automatic cleanup
- File operations
  - `Container.copy_file_to` - Copy file to container
  - `Container.copy_file_from` - Copy file from container
  - `Container.copy_content_to` - Copy string content to container
- Pre-built modules
  - `testcontainers-postgres` - PostgreSQL
  - `testcontainers-mysql` - MySQL
  - `testcontainers-mongo` - MongoDB
  - `testcontainers-redis` - Redis
  - `testcontainers-rabbitmq` - RabbitMQ
- Comprehensive test suite (69 tests)
- Documentation with mdbook

### Technical Details

- Pure OCaml implementation using Unix sockets
- Lwt-based async operations
- Direct Docker Engine API communication (no CLI dependency)
- Supports Docker API v1.43

## Version History

### v1.0.0 (Planned)

First stable release with:
- All core features
- Five database/service modules
- Complete documentation
- CI/CD integration examples

---

## Migration Guides

### Upgrading to 1.0.0

This is the first release, no migration needed.

---

## Compatibility

| OCaml Version | Status |
|---------------|--------|
| 5.2.x | Supported |
| 5.1.x | Supported |
| 5.0.x | Supported |
| < 5.0 | Not supported |

| Docker Version | Status |
|----------------|--------|
| 24.x | Tested |
| 23.x | Should work |
| 20.x+ | Should work |

| Platform | Status |
|----------|--------|
| Linux | Fully supported |
| macOS (Docker Desktop) | Fully supported |
| Windows (WSL2) | Should work |
| Windows (native) | Not tested |
