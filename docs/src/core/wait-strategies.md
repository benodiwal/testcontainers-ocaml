# Wait Strategies

Wait strategies ensure your container is fully ready before tests run. A container being "started" doesn't mean the service inside is accepting connections.

## The Problem

```ocaml
(* This might fail! *)
let* container = Container.start postgres_request in
let* result = Database.connect connection_string in  (* PostgreSQL not ready yet *)
```

PostgreSQL needs several seconds after container start to initialize and accept connections. Wait strategies solve this.

## Available Strategies

### Port Strategy

Wait until a port is accepting connections:

```ocaml
let strategy = Wait_strategy.for_listening_port (Port.tcp 5432)

let request =
  Container_request.create "postgres:16"
  |> Container_request.with_exposed_port (Port.tcp 5432)
  |> Container_request.with_wait_strategy strategy
```

This is the most common strategy. It attempts TCP connections until one succeeds.

### Log Strategy

Wait for a specific message in container logs:

```ocaml
(* Wait for exact string *)
let strategy = Wait_strategy.for_log "database system is ready to accept connections"

(* Wait for string to appear N times *)
let strategy = Wait_strategy.for_log ~occurrence:2 "ready for connections"
```

MySQL logs "ready for connections" twice—once for internal use, once when truly ready. The `occurrence` parameter handles this.

### Log Regex Strategy

Wait for a pattern in logs:

```ocaml
let strategy = Wait_strategy.for_log_regex "listening on.*port 5432"
```

### HTTP Strategy

Wait for an HTTP endpoint to respond:

```ocaml
(* Basic: wait for 200 OK on / *)
let strategy = Wait_strategy.for_http "/"

(* With options *)
let strategy = Wait_strategy.for_http
  ~port:(Port.tcp 8080)
  ~status_codes:[200; 201; 204]
  "/health"
```

Useful for web applications with health check endpoints.

### Exec Strategy

Wait until a command succeeds (exit code 0):

```ocaml
let strategy = Wait_strategy.for_exec ["pg_isready"; "-U"; "postgres"]

let strategy = Wait_strategy.for_exec [
  "sh"; "-c"; "curl -sf http://localhost:8080/health"
]
```

### Health Check Strategy

Wait for Docker's built-in HEALTHCHECK (if defined in image):

```ocaml
let strategy = Wait_strategy.for_health_check ()
```

### No Wait

Skip waiting entirely (use with caution):

```ocaml
let strategy = Wait_strategy.none
```

## Configuring Strategies

### Timeout

Maximum time to wait before failing:

```ocaml
let strategy =
  Wait_strategy.for_listening_port (Port.tcp 5432)
  |> Wait_strategy.with_timeout 120.0  (* 2 minutes *)
```

Default timeout is 60 seconds.

### Poll Interval

How often to check:

```ocaml
let strategy =
  Wait_strategy.for_listening_port (Port.tcp 5432)
  |> Wait_strategy.with_poll_interval 0.5  (* every 500ms *)
```

Default is 100ms.

## Combining Strategies

### All (AND)

Wait for all strategies to succeed:

```ocaml
let strategy = Wait_strategy.all [
  Wait_strategy.for_listening_port (Port.tcp 5432);
  Wait_strategy.for_log "ready to accept connections";
]
```

### Any (OR)

Wait for any strategy to succeed:

```ocaml
let strategy = Wait_strategy.any [
  Wait_strategy.for_http "/health";
  Wait_strategy.for_log "Application started";
]
```

## Strategy Selection Guide

| Service | Recommended Strategy |
|---------|---------------------|
| PostgreSQL | `for_log "ready to accept connections"` |
| MySQL | `for_log ~occurrence:2 "ready for connections"` |
| MongoDB | `for_log "Waiting for connections"` |
| Redis | `for_listening_port (Port.tcp 6379)` |
| RabbitMQ | `for_log "Started"` or HTTP to management port |
| Elasticsearch | `for_http "/_cluster/health"` |
| Nginx | `for_listening_port (Port.tcp 80)` |
| Custom App | `for_http "/health"` or `for_log "..."` |

## Examples

### PostgreSQL

```ocaml
let request =
  Container_request.create "postgres:16"
  |> Container_request.with_exposed_port (Port.tcp 5432)
  |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log "database system is ready to accept connections")
```

### MySQL

```ocaml
let request =
  Container_request.create "mysql:8"
  |> Container_request.with_exposed_port (Port.tcp 3306)
  |> Container_request.with_env "MYSQL_ROOT_PASSWORD" "secret"
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log ~occurrence:2 "ready for connections")
```

### Web Application with Health Check

```ocaml
let request =
  Container_request.create "my-app:latest"
  |> Container_request.with_exposed_port (Port.tcp 8080)
  |> Container_request.with_wait_strategy
       (Wait_strategy.all [
         Wait_strategy.for_listening_port (Port.tcp 8080);
         Wait_strategy.for_http ~port:(Port.tcp 8080) "/health";
       ])
```

### Service Depending on Database

```ocaml
(* First, ensure database is ready via exec *)
let request =
  Container_request.create "postgres:16"
  |> Container_request.with_exposed_port (Port.tcp 5432)
  |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_exec ["pg_isready"; "-U"; "postgres"])
```

## Debugging Wait Failures

When a wait strategy times out:

1. **Check container logs**:
   ```ocaml
   let* logs = Container.logs container in
   print_endline logs;
   ```

2. **Increase timeout**:
   ```ocaml
   Wait_strategy.with_timeout 180.0  (* 3 minutes *)
   ```

3. **Try a simpler strategy first**:
   ```ocaml
   Wait_strategy.for_listening_port (Port.tcp 5432)
   ```

4. **Check if the image works manually**:
   ```bash
   docker run -p 5432:5432 -e POSTGRES_PASSWORD=secret postgres:16
   ```

## Custom Wait Logic

For complex scenarios, implement custom waiting after container start:

```ocaml
let wait_for_custom_condition container =
  let rec loop attempts =
    if attempts <= 0 then
      Lwt.fail_with "Timeout waiting for condition"
    else
      let* (exit_code, _) = Container.exec container ["test"; "-f"; "/ready"] in
      if exit_code = 0 then
        Lwt.return_unit
      else begin
        let* () = Lwt_unix.sleep 0.5 in
        loop (attempts - 1)
      end
  in
  loop 60  (* 30 seconds *)

let run_test () =
  Container.with_container request (fun container ->
    let* () = wait_for_custom_condition container in
    (* Now run tests *)
    ...
  )
```
