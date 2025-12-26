# Introduction

**Testcontainers OCaml** is a library that provides lightweight, disposable containers for integration testing. It enables OCaml developers to write tests against real services—databases, message queues, and other infrastructure—without complex setup or shared test environments.

## Why Testcontainers?

Integration tests that rely on mocks or in-memory implementations often miss real-world bugs. Configuration mismatches, protocol differences, and edge cases in actual services go undetected until production.

Testcontainers solves this by:

- **Running real services** in Docker containers during tests
- **Isolating each test run** with fresh, disposable containers
- **Managing lifecycle automatically**—containers start before tests and terminate after
- **Providing consistent environments** across local development and CI/CD

## Why OCaml?

OCaml's type system and emphasis on correctness make it an excellent choice for building reliable systems. Testcontainers OCaml brings the same philosophy to testing:

- **Type-safe container configuration** using the builder pattern
- **Lwt-based async operations** that integrate naturally with OCaml's async ecosystem
- **Functional API design** with composable wait strategies and configuration

## Example

A complete integration test with PostgreSQL:

```ocaml
open Lwt.Syntax
open Testcontainers

let test_database () =
  Postgres_container.with_postgres
    ~config:(fun c -> c
      |> Postgres_container.with_database "myapp"
      |> Postgres_container.with_username "test"
      |> Postgres_container.with_password "secret")
    (fun container connection_string ->
      (* connection_string: postgresql://test:secret@127.0.0.1:54321/myapp *)
      let* result = My_db.query connection_string "SELECT 1" in
      assert (result = 1);
      Lwt.return_unit)
```

The container starts automatically, waits until PostgreSQL is ready to accept connections, runs your test, and cleans up—regardless of whether the test passes or fails.

## Features

| Feature | Description |
|---------|-------------|
| **Container Lifecycle** | Automatic start, stop, and cleanup |
| **Port Mapping** | Dynamic port allocation with easy access |
| **Wait Strategies** | Port, log, HTTP, exec, and health check waiting |
| **Networks** | Isolated Docker networks for multi-container tests |
| **File Operations** | Copy files to and from containers |
| **Pre-built Modules** | PostgreSQL, MySQL, MongoDB, Redis, RabbitMQ |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Your Test Code                    │
├─────────────────────────────────────────────────────┤
│              Testcontainers OCaml                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐    │
│  │  Container  │ │    Wait     │ │   Network   │    │
│  │   Request   │ │  Strategy   │ │   Module    │    │
│  └─────────────┘ └─────────────┘ └─────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │             Docker Client (Unix Socket)     │    │
│  └─────────────────────────────────────────────┘    │ 
├─────────────────────────────────────────────────────┤
│                   Docker Engine                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐             │
│  │ Postgres │ │  Redis   │ │  MySQL   │  ...        │
│  └──────────┘ └──────────┘ └──────────┘             │
└─────────────────────────────────────────────────────┘
```

## Prior Art

This library is inspired by:

- [testcontainers-java](https://github.com/testcontainers/testcontainers-java)
- [testcontainers-python](https://github.com/testcontainers/testcontainers-python)
- [testcontainers-go](https://github.com/testcontainers/testcontainers-go)
- [testcontainers-rust](https://github.com/testcontainers/testcontainers-rs)

## License

Testcontainers OCaml is released under the Apache License 2.0.
