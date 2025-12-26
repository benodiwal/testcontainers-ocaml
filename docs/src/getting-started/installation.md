# Installation

## Prerequisites

Before installing Testcontainers OCaml, ensure you have:

1. **OCaml 5.0+** and **opam 2.0+**
2. **Docker** installed and running
3. **dune** build system

Verify Docker is running:

```bash
docker info
```

## Installing via opam

```bash
# Core library
opam install testcontainers

# Module-specific packages (install as needed)
opam install testcontainers-postgres
opam install testcontainers-mysql
opam install testcontainers-mongodb
opam install testcontainers-redis
opam install testcontainers-rabbitmq
```

## Adding to Your Project

### dune-project

```scheme
(lang dune 3.0)
(name my_project)

(package
 (name my_project)
 (depends
  (ocaml (>= 5.0))
  (testcontainers (>= 1.0))
  (testcontainers-postgres (>= 1.0))  ; if using PostgreSQL
  (alcotest :with-test)
  (alcotest-lwt :with-test)))
```

### dune (test directory)

```scheme
(test
 (name my_tests)
 (libraries
  my_project
  testcontainers
  testcontainers-postgres
  alcotest
  alcotest-lwt
  lwt
  lwt.unix)
 (preprocess (pps lwt_ppx)))
```

## Manual Installation (from source)

```bash
git clone https://github.com/benodiwal/testcontainers-ocaml.git
cd testcontainers-ocaml
opam install . --deps-only
dune build
dune install
```

## Verifying Installation

Create a simple test to verify everything works:

```ocaml
(* test_install.ml *)
open Lwt.Syntax

let () = Lwt_main.run (
  let* result = Testcontainers.Docker_client.ping () in
  if result then
    print_endline "Testcontainers OCaml is working!"
  else
    print_endline "Could not connect to Docker";
  Lwt.return_unit
)
```

Run it:

```bash
dune exec ./test_install.exe
```

## Docker Configuration

### Unix Socket (Default)

Testcontainers connects to Docker via the Unix socket at `/var/run/docker.sock`. This is the default on Linux and macOS.

### Docker Desktop (macOS/Windows)

Docker Desktop exposes the socket automatically. No additional configuration needed.

### Rootless Docker

If using rootless Docker, the socket is typically at:

```
$XDG_RUNTIME_DIR/docker.sock
```

Set the `DOCKER_HOST` environment variable:

```bash
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
```

### Remote Docker Host

For remote Docker daemons (not yet supported—coming soon):

```bash
export DOCKER_HOST=tcp://remote-host:2375
```

## Troubleshooting

### "Cannot connect to Docker daemon"

1. Ensure Docker is running: `docker ps`
2. Check socket permissions: `ls -la /var/run/docker.sock`
3. Add your user to the docker group: `sudo usermod -aG docker $USER`

### "Image pull timeout"

First test run may be slow due to image downloads. Pre-pull images:

```bash
docker pull postgres:16-alpine
docker pull redis:7-alpine
docker pull mysql:8
docker pull mongo:7
docker pull rabbitmq:3-management-alpine
```

### "Port already in use"

Testcontainers uses dynamic port allocation. If you see port conflicts, ensure no containers from previous failed test runs are still active:

```bash
docker ps -a | grep testcontainers
docker rm -f $(docker ps -aq --filter "label=testcontainers")
```
