# Containers

The `Container` module is the heart of Testcontainers OCaml. It manages the complete lifecycle of Docker containers—from configuration through cleanup.

## Container Request

Before starting a container, you build a request describing what you want:

```ocaml
open Testcontainers

let request =
  Container_request.create "nginx:alpine"
  |> Container_request.with_exposed_port (Port.tcp 80)
  |> Container_request.with_env "NGINX_HOST" "localhost"
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_http ~port:(Port.tcp 80) "/")
```

### Available Configuration

| Function | Description |
|----------|-------------|
| `create image` | Create request with Docker image |
| `with_exposed_port port` | Expose a port |
| `with_exposed_ports ports` | Expose multiple ports |
| `with_env key value` | Set environment variable |
| `with_envs pairs` | Set multiple env vars |
| `with_cmd args` | Override CMD |
| `with_entrypoint args` | Override ENTRYPOINT |
| `with_working_dir dir` | Set working directory |
| `with_user user` | Run as specific user |
| `with_name name` | Set container name |
| `with_label key value` | Add label |
| `with_labels pairs` | Add multiple labels |
| `with_mount mount` | Add volume mount |
| `with_privileged bool` | Run in privileged mode |
| `with_wait_strategy strategy` | Set readiness check |
| `with_startup_timeout seconds` | Max wait time |
| `with_auto_remove bool` | Remove on stop |

## Starting Containers

### Manual Lifecycle

```ocaml
open Lwt.Syntax

let run_test () =
  let request = Container_request.create "redis:7-alpine"
    |> Container_request.with_exposed_port (Port.tcp 6379)
  in

  (* Start container *)
  let* container = Container.start request in

  (* Use container *)
  let* host = Container.host container in
  let* port = Container.mapped_port container (Port.tcp 6379) in
  Printf.printf "Redis at %s:%d\n" host port;

  (* Stop and remove *)
  let* () = Container.stop container in
  let* () = Container.terminate container in
  Lwt.return_unit
```

### Automatic Lifecycle (Recommended)

Use `with_container` for automatic cleanup:

```ocaml
let run_test () =
  let request = Container_request.create "redis:7-alpine"
    |> Container_request.with_exposed_port (Port.tcp 6379)
  in

  Container.with_container request (fun container ->
    let* host = Container.host container in
    let* port = Container.mapped_port container (Port.tcp 6379) in
    Printf.printf "Redis at %s:%d\n" host port;
    Lwt.return_unit
  )
  (* Container automatically stopped and removed here *)
```

## Container Operations

### Getting Connection Details

```ocaml
(* Host is always 127.0.0.1 for local Docker *)
let* host = Container.host container in

(* Get mapped port (Docker assigns random available port) *)
let* port = Container.mapped_port container (Port.tcp 5432) in

(* Get all mapped ports *)
let* ports = Container.mapped_ports container in
```

### Executing Commands

Run commands inside the container:

```ocaml
let* (exit_code, output) = Container.exec container ["echo"; "hello"] in
Printf.printf "Exit: %d, Output: %s\n" exit_code output;

(* Run shell commands *)
let* (exit_code, output) = Container.exec container [
  "sh"; "-c"; "echo $HOME && whoami"
] in
```

### Accessing Logs

```ocaml
(* Get all logs *)
let* logs = Container.logs container in
print_endline logs;

(* Logs are useful for debugging test failures *)
```

### Checking State

```ocaml
(* Is container running? *)
let* running = Container.is_running container in

(* Get detailed state *)
let* state = Container.state container in
match state with
| `Running -> print_endline "Running"
| `Exited -> print_endline "Exited"
| `Created -> print_endline "Created but not started"
| `Paused -> print_endline "Paused"
| _ -> print_endline "Other state"
```

### Container ID and Name

```ocaml
let id = Container.id container in    (* e.g., "a1b2c3d4e5f6" *)
let name = Container.name container in (* e.g., "/fervent_euler" *)
```

## Port Mapping

Docker maps container ports to random available host ports:

```
Container Port 5432/tcp  →  Host Port 54321
Container Port 80/tcp    →  Host Port 32768
```

### Port Types

```ocaml
(* TCP port (most common) *)
let pg_port = Port.tcp 5432

(* UDP port *)
let dns_port = Port.udp 53

(* Parse from string *)
let port = Port.of_string "8080/tcp"
```

### Exposing Ports

```ocaml
(* Single port *)
Container_request.with_exposed_port (Port.tcp 80) request

(* Multiple ports *)
Container_request.with_exposed_ports [
  Port.tcp 80;
  Port.tcp 443;
  Port.tcp 8080;
] request
```

## Environment Variables

```ocaml
let request =
  Container_request.create "postgres:16"
  |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
  |> Container_request.with_env "POSTGRES_USER" "admin"
  |> Container_request.with_env "POSTGRES_DB" "myapp"

(* Or use with_envs for multiple *)
  |> Container_request.with_envs [
       ("POSTGRES_PASSWORD", "secret");
       ("POSTGRES_USER", "admin");
       ("POSTGRES_DB", "myapp");
     ]
```

## Volume Mounts

### Bind Mounts

Mount host directory into container:

```ocaml
let mount = Volume.bind
  ~host:"/path/on/host"
  ~container:"/path/in/container"
  ()

let request =
  Container_request.create "nginx:alpine"
  |> Container_request.with_mount mount
```

### Read-Only Mounts

```ocaml
let mount = Volume.bind
  ~mode:Volume.ReadOnly
  ~host:"/configs"
  ~container:"/etc/nginx/conf.d"
  ()
```

### Named Volumes

```ocaml
let mount = Volume.volume
  ~name:"my-data"
  ~container:"/data"
  ()
```

### Tmpfs Mounts

In-memory filesystem:

```ocaml
let mount = Volume.tmpfs
  ~container:"/tmp"
  ~size:67108864  (* 64MB *)
  ()
```

## Command and Entrypoint

```ocaml
(* Override CMD *)
let request =
  Container_request.create "alpine:latest"
  |> Container_request.with_cmd ["sleep"; "3600"]

(* Override ENTRYPOINT *)
let request =
  Container_request.create "alpine:latest"
  |> Container_request.with_entrypoint ["/bin/sh"; "-c"]
  |> Container_request.with_cmd ["echo hello && sleep 3600"]
```

## Labels

Labels help identify and filter containers:

```ocaml
let request =
  Container_request.create "nginx:alpine"
  |> Container_request.with_label "project" "my-app"
  |> Container_request.with_label "environment" "test"
  |> Container_request.with_labels [
       ("version", "1.0");
       ("team", "backend");
     ]
```

## Best Practices

### Always Use with_container

```ocaml
(* Good: automatic cleanup *)
Container.with_container request (fun c -> ...)

(* Risky: manual cleanup might be skipped on error *)
let* c = Container.start request in
(* if error occurs here, container leaks *)
let* () = Container.terminate c in
```

### Use Specific Image Tags

```ocaml
(* Good: reproducible *)
Container_request.create "postgres:16.1-alpine"

(* Risky: may change unexpectedly *)
Container_request.create "postgres:latest"
```

### Set Reasonable Timeouts

```ocaml
Container_request.with_startup_timeout 120.0  (* 2 minutes *)
```

### Use Alpine Images When Possible

```ocaml
(* Faster to pull, smaller footprint *)
"postgres:16-alpine"
"redis:7-alpine"
"nginx:alpine"
```
