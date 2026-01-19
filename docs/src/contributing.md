# Contributing

Thank you for your interest in contributing to Testcontainers OCaml! This guide will help you get started.

## Getting Started

### Prerequisites

- OCaml 5.0 or later
- opam 2.0 or later
- Docker
- dune build system

### Setup

```bash
# Clone the repository
git clone https://github.com/benodiwal/testcontainers-ocaml.git
cd testcontainers-ocaml

# Install dependencies
opam install . --deps-only --with-test --with-doc

# Build
dune build

# Run tests
dune runtest
```

## Project Structure

```
testcontainers-ocaml/
├── lib/                    # Core library
│   ├── container.ml        # Container lifecycle
│   ├── container_request.ml # Container configuration
│   ├── docker_client.ml    # Docker API client
│   ├── wait_strategy.ml    # Wait strategies
│   ├── network.ml          # Docker networks
│   ├── port.ml             # Port types
│   ├── volume.ml           # Volume/mount types
│   ├── error.ml            # Error types
│   └── testcontainers.ml   # Main module
├── modules/                # Service-specific modules
│   ├── postgres/
│   ├── mysql/
│   ├── mongo/
│   ├── redis/
│   ├── rabbitmq/
│   ├── kafka/
│   ├── elasticsearch/
│   ├── localstack/
│   ├── memcached/
│   └── mockserver/
├── test/                   # Test suite
├── examples/               # Example code
└── docs/                   # Documentation (mdbook)
```

## Development Workflow

### Building

```bash
# Build everything
dune build

# Build and watch for changes
dune build --watch
```

### Testing

```bash
# Run all tests
dune runtest

# Run specific test file
dune exec test/test_testcontainers.exe

# Run with verbose output
dune runtest --force

# Skip integration tests (unit tests only)
SKIP_INTEGRATION_TESTS=1 dune runtest
```

### Formatting

```bash
# Check formatting
dune build @fmt

# Auto-format
dune fmt
```

### Documentation

```bash
# Build API docs
dune build @doc

# Build mdbook documentation
cd docs && mdbook build

# Serve documentation locally
cd docs && mdbook serve
```

## Making Changes

### Creating a Branch

```bash
git checkout -b feature/my-feature
# or
git checkout -b fix/my-bugfix
```

### Commit Messages

Follow conventional commits:

```
feat: add Kafka container module
fix: handle empty port bindings
docs: update PostgreSQL examples
test: add network integration tests
refactor: simplify wait strategy logic
chore: update dependencies
```

### Pull Request Process

1. Create a branch from `main`
2. Make your changes
3. Add tests for new functionality
4. Ensure all tests pass
5. Update documentation if needed
6. Open a pull request

## Adding a New Module

### 1. Create Module Directory

```bash
mkdir -p modules/myservice
```

### 2. Create dune File

```scheme
; modules/myservice/dune
(library
 (name testcontainers_myservice)
 (public_name testcontainers-myservice)
 (libraries testcontainers lwt lwt.unix)
 (preprocess (pps lwt_ppx)))
```

### 3. Implement the Module

```ocaml
(* modules/myservice/myservice_container.ml *)

open Lwt.Syntax
open Testcontainers

let default_image = "myservice:latest"
let default_port = 8080

type config = {
  image : string;
  (* Add service-specific config *)
}

let create () = {
  image = default_image;
}

let with_image image config = { config with image }

let start config =
  let request =
    Container_request.create config.image
    |> Container_request.with_exposed_port (Port.tcp default_port)
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_listening_port (Port.tcp default_port))
  in
  Container.start request

let with_myservice ?(config = Fun.id) f =
  let cfg = config (create ()) in
  (* ... implementation *)
```

### 4. Add Interface File

```ocaml
(* modules/myservice/myservice_container.mli *)

type config

val create : unit -> config
val with_image : string -> config -> config

val start : config -> Testcontainers.Container.t Lwt.t

val with_myservice : ?config:(config -> config) ->
  (Testcontainers.Container.t -> string -> 'a Lwt.t) -> 'a Lwt.t
```

### 5. Update dune-project

```scheme
(package
 (name testcontainers-myservice)
 (depends
  (ocaml (>= 5.0))
  (testcontainers (>= 1.0))
  (lwt (>= 5.6))))
```

### 6. Add Tests

```ocaml
(* test/test_myservice.ml *)

let test_container _switch () =
  Myservice_container.with_myservice (fun container url ->
    (* Test implementation *)
    Lwt.return_unit
  )

let suite = [
  Alcotest_lwt.test_case "container" `Slow test_container;
]
```

### 7. Add Example

```ocaml
(* examples/myservice_example.ml *)

let () = Lwt_main.run (
  Myservice_container.with_myservice (fun container url ->
    Printf.printf "MyService running at: %s\n" url;
    Lwt.return_unit
  )
)
```

### 8. Add Documentation

Create `docs/src/modules/myservice.md` following the existing module documentation pattern.

## Code Style

### General Guidelines

- Use descriptive names
- Keep functions focused and small
- Add doc comments for public APIs
- Handle errors explicitly

### OCaml Conventions

```ocaml
(* Use labeled arguments for clarity *)
let copy_file_to container ~src ~dest = ...

(* Use optional arguments with defaults *)
let stop ?(timeout = 10.0) container = ...

(* Prefer Result/Option over exceptions for expected failures *)
let find_port ports key =
  List.assoc_opt key ports

(* Use Lwt.t for async operations *)
val start : config -> Container.t Lwt.t
```

### Documentation Comments

```ocaml
(** [with_postgres ?config f] starts a PostgreSQL container,
    runs [f] with the container and connection string,
    then terminates the container.

    @param config Optional configuration function
    @return Result of [f]

    Example:
    {[
      with_postgres (fun container conn_str ->
        (* use PostgreSQL *)
        Lwt.return_unit)
    ]}
*)
val with_postgres : ?config:(config -> config) ->
  (Container.t -> string -> 'a Lwt.t) -> 'a Lwt.t
```

## Testing Guidelines

### Unit Tests

- Test pure functions without Docker
- Fast execution
- No external dependencies

```ocaml
let test_port_parsing _switch () =
  let port = Port.of_string "8080/tcp" in
  Alcotest.(check int) "port" 8080 port.port;
  Lwt.return_unit
```

### Integration Tests

- Test actual Docker operations
- Mark as `Slow
- Clean up resources

```ocaml
let test_container_lifecycle _switch () =
  Container.with_container request (fun container ->
    let* running = Container.is_running container in
    Alcotest.(check bool) "running" true running;
    Lwt.return_unit
  )
```

## Getting Help

- Open an issue for bugs or feature requests
- Start a discussion for questions
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
