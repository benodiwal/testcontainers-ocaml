# testcontainers-ocaml

Lightweight, throwaway instances of databases, message brokers, or any service that runs in a Docker container. Enables reliable integration testing with real services instead of mocks.

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

## Documentation

Full documentation: [https://benodiwal.github.io/testcontainers-ocaml](https://benodiwal.github.io/testcontainers-ocaml)

- [Getting Started](docs/src/getting-started/quickstart.md)
- [Core Concepts](docs/src/core/containers.md)
- [API Reference](docs/src/reference/api-overview.md)

## Requirements

- OCaml >= 4.14
- Docker

## License

Apache-2.0
