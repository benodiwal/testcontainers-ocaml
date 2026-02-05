## 0.1.1 (2026-02-05)

### Fixed

- Corrected repository URLs in package metadata (testcontainers_ocaml → testcontainers-ocaml)
- Split tests per package to fix OPAM CI test failures (each module now has isolated tests)

## 0.1.0 (2026-01-17)

Initial release.

### Features

- Core container lifecycle management (start, stop, terminate)
- Builder pattern for container configuration
- Wait strategies: port, log, log regex, HTTP, exec, healthcheck
- Composite wait strategies (all, any)
- Docker network support
- File copy operations (to/from containers)
- Command execution in containers

### Modules

- `testcontainers` - Core library
- `testcontainers-postgres` - PostgreSQL
- `testcontainers-mysql` - MySQL
- `testcontainers-mongo` - MongoDB
- `testcontainers-redis` - Redis
- `testcontainers-rabbitmq` - RabbitMQ
- `testcontainers-kafka` - Apache Kafka
- `testcontainers-elasticsearch` - Elasticsearch
- `testcontainers-localstack` - LocalStack (AWS emulation)
- `testcontainers-memcached` - Memcached
- `testcontainers-mockserver` - MockServer (HTTP mocking)
