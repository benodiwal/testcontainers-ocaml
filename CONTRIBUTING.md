# Contributing to testcontainers-ocaml

Thank you for your interest in contributing to testcontainers-ocaml! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Adding a New Module](#adding-a-new-module)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)

## Getting Started

### Prerequisites

- OCaml >= 5.0
- opam (OCaml package manager)
- Docker
- dune (build system)

### Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/testcontainers-ocaml.git
cd testcontainers-ocaml

# Add upstream remote
git remote add upstream https://github.com/benodiwal/testcontainers-ocaml.git
```

## Development Setup

### Install Dependencies

```bash
# Create a local switch (recommended)
opam switch create . 5.2.0 --deps-only

# Or install in your current switch
opam install . --deps-only --with-test
```

### Build the Project

```bash
# Build everything
dune build

# Build and watch for changes
dune build --watch
```

### Run Tests

```bash
# Run all tests (requires Docker)
dune test

# Run tests with verbose output
dune test --force --display=short

# Skip integration tests (unit tests only)
SKIP_INTEGRATION_TESTS=1 dune test
```

### Run Examples

```bash
# Run a specific example
dune exec examples/basic_example.exe
dune exec examples/postgres_example.exe

# Run all examples
for f in examples/*.ml; do
  echo "Running $f..."
  dune exec "examples/$(basename $f .ml).exe"
done
```

### Format Code

```bash
# Check formatting
dune build @fmt

# Apply formatting
dune fmt
```

### Build Documentation

```bash
cd docs
mdbook serve  # Serves at http://localhost:3000
```

## Making Changes

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation changes
- `refactor/description` - Code refactoring

### Commit Messages

Follow conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
```
feat(kafka): add Kafka module with KRaft support
fix(docker_client): handle connection timeout properly
docs(readme): add examples section
test(postgres): add connection string test
```

## Adding a New Module

To add a new container module (e.g., for "newservice"):

### 1. Create Module Directory

```bash
mkdir -p modules/newservice
```

### 2. Create Module Files

**modules/newservice/newservice_container.ml:**
```ocaml
(** NewService container module *)

open Lwt.Syntax
open Testcontainers

let default_image = "newservice:latest"
let default_port = Port.tcp 1234

type t = {
  image : string;
  port : Port.exposed_port;
  (* add other config options *)
}

let create () = { image = default_image; port = default_port }
let with_image image t = { t with image }

let to_request t =
  Container_request.create t.image
  |> Container_request.with_exposed_port t.port
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_listening_port ~timeout:30.0 t.port)

let start t =
  let request = to_request t in
  Container.start request

let url t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  Lwt.return (Printf.sprintf "%s:%d" host port)

let host container = Container.host container
let port t container = Container.mapped_port container t.port

let with_newservice ?config f =
  let t = match config with Some cfg -> cfg (create ()) | None -> create () in
  let* container = start t in
  let* conn = url t container in
  Lwt.finalize
    (fun () -> f container conn)
    (fun () -> Container.terminate container)
```

**modules/newservice/newservice_container.mli:**
```ocaml
(** NewService container for testing. *)

type t

val create : unit -> t
val with_image : string -> t -> t
val start : t -> Testcontainers.Container.t Lwt.t
val url : t -> Testcontainers.Container.t -> string Lwt.t
val host : Testcontainers.Container.t -> string Lwt.t
val port : t -> Testcontainers.Container.t -> int Lwt.t

val with_newservice :
  ?config:(t -> t) ->
  (Testcontainers.Container.t -> string -> 'a Lwt.t) ->
  'a Lwt.t
```

**modules/newservice/dune:**
```scheme
(library
 (name testcontainers_newservice)
 (public_name testcontainers-newservice)
 (libraries testcontainers lwt lwt.unix))
```

### 3. Add to dune-project

Add a new package entry:

```scheme
(package
 (name testcontainers-newservice)
 (synopsis "NewService module for testcontainers")
 (description "NewService container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))
```

### 4. Add Tests

**test/test_newservice.ml:**
```ocaml
(** Tests for NewService container *)

open Lwt.Syntax
open Testcontainers_newservice

let test_config _switch () =
  let _config =
    Newservice_container.create ()
    |> Newservice_container.with_image "newservice:1.0"
  in
  Lwt.return_unit

let test_container _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    Newservice_container.with_newservice (fun container url ->
        Alcotest.(check bool) "url not empty" true (String.length url > 0);
        let* host = Newservice_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
```

### 5. Register Tests

Update **test/dune**:
```scheme
(modules ... test_newservice)
(libraries ... testcontainers-newservice)
```

Update **test/test_testcontainers.ml**:
```ocaml
("newservice", Test_newservice.suite);
```

### 6. Add Example

**examples/newservice_example.ml:**
```ocaml
open Testcontainers_newservice

let () =
  Lwt_main.run begin
    Printf.printf "Starting NewService container...\n%!";
    Newservice_container.with_newservice (fun _container url ->
      Printf.printf "NewService running at: %s\n%!" url;
      Lwt.return_unit)
  end
```

Update **examples/dune** to include the new example.

### 7. Add Documentation

Create **docs/src/modules/newservice.md** and update **docs/src/SUMMARY.md**.

### 8. Update Changelog

Add entry to **CHANGES.md**.

## Testing

### Test Categories

- **Unit tests** - Test individual functions (fast, no Docker)
- **Integration tests** - Test with real containers (slower, requires Docker)

### Running Specific Tests

```bash
# Run all tests
dune test

# Run with filter
dune exec test/test_testcontainers.exe -- test -e "postgres"

# Skip integration tests
SKIP_INTEGRATION_TESTS=1 dune test
```

### Writing Tests

```ocaml
let test_something _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    (* Your test code *)
    Lwt.return_unit
  end

let suite = [
  Alcotest_lwt.test_case "name" `Quick test_unit;      (* Unit test *)
  Alcotest_lwt.test_case "name" `Slow test_integration; (* Integration *)
]
```

## Code Style

### Formatting

We use ocamlformat. Configuration is in `.ocamlformat`:

```
version = 0.28.1
profile = default
```

Always run `dune fmt` before committing.

### Guidelines

- Use descriptive names
- Add type annotations for public functions
- Document public APIs with odoc comments
- Keep functions small and focused
- Use `let*` syntax for Lwt (not `>>=`)
- Handle errors gracefully

### Example Style

```ocaml
(** Brief description of the function.

    Longer description if needed.

    @param x Description of parameter
    @return Description of return value *)
let my_function ~(x : int) : string Lwt.t =
  let* result = some_async_operation x in
  Lwt.return (process result)
```

## Submitting Changes

### Before Submitting

1. Ensure all tests pass: `dune test`
2. Format code: `dune fmt`
3. Update documentation if needed
4. Add changelog entry for user-facing changes

### Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear commits
3. Push to your fork
4. Open a Pull Request against `main`
5. Fill out the PR template
6. Wait for review

### PR Checklist

- [ ] Tests pass locally
- [ ] Code is formatted
- [ ] Documentation updated (if applicable)
- [ ] CHANGES.md updated (if applicable)
- [ ] Commit messages follow convention

## Getting Help

- Open an issue for bugs or feature requests
- Start a discussion for questions
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 license.
