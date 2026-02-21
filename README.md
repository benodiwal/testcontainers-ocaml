# testcontainers-ocaml

Lightweight, throwaway instances of databases, message brokers, or any service that runs in a Docker container. Enables reliable integration testing with real services instead of mocks.

This project is incubating under the [Testcontainers](https://testcontainers.org/) org.


## Installation

```bash
opam install testcontainers
```

## Quick Example

```ocaml
open Lwt.Syntax
open Testcontainers_postgres

let () = Lwt_main.run (
  Postgres_container.with_postgres (fun _container conn_str ->
    Printf.printf "PostgreSQL: %s\n" conn_str;
    Lwt.return_unit
  )
)
```

## Running Examples

```bash
# Clone the repository
git clone https://github.com/benodiwal/testcontainers-ocaml.git
cd testcontainers-ocaml

# Install dependencies
opam install . --deps-only

# Run examples
dune exec examples/basic_example.exe
dune exec examples/postgres_example.exe
dune exec examples/redis_example.exe
dune exec examples/mysql_example.exe
dune exec examples/mongo_example.exe
dune exec examples/kafka_example.exe
dune exec examples/elasticsearch_example.exe
dune exec examples/localstack_example.exe
dune exec examples/memcached_example.exe
dune exec examples/mockserver_example.exe
```

## Available Modules

| Module | Package | Description |
|--------|---------|-------------|
| PostgreSQL | `testcontainers-postgres` | PostgreSQL database |
| MySQL | `testcontainers-mysql` | MySQL database |
| MongoDB | `testcontainers-mongo` | MongoDB database |
| Redis | `testcontainers-redis` | Redis cache |
| RabbitMQ | `testcontainers-rabbitmq` | RabbitMQ message broker |
| Kafka | `testcontainers-kafka` | Apache Kafka (KRaft) |
| Elasticsearch | `testcontainers-elasticsearch` | Elasticsearch |
| LocalStack | `testcontainers-localstack` | AWS services emulation |
| Memcached | `testcontainers-memcached` | Memcached cache |
| MockServer | `testcontainers-mockserver` | HTTP mocking |

## Documentation

Full documentation: [https://benodiwal.github.io/testcontainers-ocaml](https://benodiwal.github.io/testcontainers-ocaml)

- [Getting Started](docs/src/getting-started/quickstart.md)
- [Core Concepts](docs/src/core/containers.md)
- [API Reference](docs/src/reference/api-overview.md)

## Requirements

- OCaml >= 5.0
- Docker

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

Apache-2.0
