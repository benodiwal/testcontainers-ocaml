# Configuration

This page documents all configuration options for Testcontainers OCaml.

## Environment Variables

### Docker Connection

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_HOST` | `unix:///var/run/docker.sock` | Docker daemon socket |
| `DOCKER_TLS_VERIFY` | - | Enable TLS verification |
| `DOCKER_CERT_PATH` | - | Path to TLS certificates |

### Test Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SKIP_INTEGRATION_TESTS` | `false` | Skip all integration tests |
| `CONTAINER_TIMEOUT` | `60` | Default startup timeout (seconds) |
| `TESTCONTAINERS_RYUK_DISABLED` | `false` | Disable resource cleanup (not yet implemented) |

### CI Detection

| Variable | Description |
|----------|-------------|
| `CI` | Set to `true` in most CI environments |
| `GITHUB_ACTIONS` | Set in GitHub Actions |
| `GITLAB_CI` | Set in GitLab CI |
| `CIRCLECI` | Set in CircleCI |

## Default Values

### Container Request Defaults

```ocaml
(* Default values when creating a container request *)
let defaults = {
  exposed_ports = [];
  environment = [];
  labels = [];
  command = None;
  entrypoint = None;
  working_dir = None;
  user = None;
  privileged = false;
  mounts = [];
  wait_strategy = None;
  startup_timeout = 60.0;
  auto_remove = false;
  name = None;
}
```

### Wait Strategy Defaults

```ocaml
(* Default timeout for wait strategies *)
let default_timeout = 60.0  (* seconds *)

(* Default poll interval *)
let default_poll_interval = 0.1  (* seconds, 100ms *)
```

### Module Defaults

#### PostgreSQL

```ocaml
let defaults = {
  image = "postgres:16-alpine";
  database = "test";
  username = "test";
  password = "test";
  port = 5432;
}
```

#### MySQL

```ocaml
let defaults = {
  image = "mysql:8";
  database = "test";
  username = "test";
  password = "test";
  root_password = "root";
  port = 3306;
}
```

#### MongoDB

```ocaml
let defaults = {
  image = "mongo:7";
  username = None;  (* No auth by default *)
  password = None;
  port = 27017;
}
```

#### Redis

```ocaml
let defaults = {
  image = "redis:7-alpine";
  port = 6379;
}
```

#### RabbitMQ

```ocaml
let defaults = {
  image = "rabbitmq:3-management-alpine";
  username = "guest";
  password = "guest";
  vhost = "/";
  amqp_port = 5672;
  management_port = 15672;
}
```

## Timeouts

### Startup Timeout

Maximum time to wait for a container to be ready:

```ocaml
Container_request.with_startup_timeout 120.0  (* 2 minutes *)
```

### Wait Strategy Timeout

Maximum time for a wait strategy to succeed:

```ocaml
Wait_strategy.with_timeout 30.0  (* 30 seconds *)
```

### Poll Interval

How often to check wait conditions:

```ocaml
Wait_strategy.with_poll_interval 0.5  (* 500ms *)
```

### Stop Timeout

How long to wait for graceful shutdown:

```ocaml
Container.stop ~timeout:10.0 container  (* 10 seconds *)
```

## Docker API

### API Version

```ocaml
let api_version = "v1.43"
```

### Socket Path

```ocaml
let docker_socket = "/var/run/docker.sock"
```

## Programmatic Configuration

### Reading Environment

```ocaml
let get_timeout () =
  match Sys.getenv_opt "CONTAINER_TIMEOUT" with
  | Some t -> (try float_of_string t with _ -> 60.0)
  | None -> 60.0

let skip_integration () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let is_ci () =
  Sys.getenv_opt "CI" = Some "true"
```

### Dynamic Configuration

```ocaml
let create_request () =
  let timeout = get_timeout () in
  let image =
    match Sys.getenv_opt "POSTGRES_IMAGE" with
    | Some img -> img
    | None -> "postgres:16-alpine"
  in
  Container_request.create image
  |> Container_request.with_startup_timeout timeout
```

## Common Configuration Patterns

### Development vs CI

```ocaml
let config =
  if is_ci () then
    (* CI: longer timeouts, specific images *)
    Container_request.create "postgres:16-alpine"
    |> Container_request.with_startup_timeout 120.0
  else
    (* Dev: faster startup, latest images okay *)
    Container_request.create "postgres:16"
    |> Container_request.with_startup_timeout 60.0
```

### Configurable Test Suites

```ocaml
let integration_tests =
  if skip_integration () then [] else [
    test_database;
    test_cache;
    test_queue;
  ]
```

### Image Override

```ocaml
let postgres_image =
  Sys.getenv_opt "TEST_POSTGRES_IMAGE"
  |> Option.value ~default:"postgres:16-alpine"

let config =
  Postgres_container.create ()
  |> Postgres_container.with_image postgres_image
```

## Docker Desktop Settings

### macOS / Windows

Docker Desktop exposes the socket at the default location. No configuration needed.

### Resource Limits

Configure in Docker Desktop preferences:
- Memory: Recommend at least 4GB for integration tests
- CPUs: 2+ recommended
- Disk: Ensure adequate space for images

### WSL2 (Windows)

```bash
# In WSL2, Docker socket is available at default location
export DOCKER_HOST=unix:///var/run/docker.sock
```

## Troubleshooting Configuration

### Verify Docker Connection

```ocaml
let check_docker () =
  Lwt_main.run (
    let* ok = Docker_client.ping () in
    if ok then
      print_endline "Docker connection OK"
    else
      print_endline "Docker connection failed";
    Lwt.return_unit
  )
```

### Check Environment

```ocaml
let print_config () =
  Printf.printf "DOCKER_HOST: %s\n"
    (Sys.getenv_opt "DOCKER_HOST" |> Option.value ~default:"(default)");
  Printf.printf "CI: %s\n"
    (Sys.getenv_opt "CI" |> Option.value ~default:"false");
  Printf.printf "Skip integration: %b\n" (skip_integration ())
```

### Debug Mode

```ocaml
let debug = Sys.getenv_opt "DEBUG" = Some "true"

let log msg =
  if debug then Printf.printf "[DEBUG] %s\n" msg

let start_with_debug request =
  log "Starting container...";
  let* container = Container.start request in
  log (Printf.sprintf "Container started: %s" (Container.id container));
  Lwt.return container
```
