# Custom Containers

While Testcontainers OCaml provides pre-built modules for common services, you'll often need to test against custom applications or services not included in the standard modules.

## Basic Custom Container

### Simple Example

```ocaml
open Lwt.Syntax
open Testcontainers

let test_custom_app () =
  let request =
    Container_request.create "my-app:latest"
    |> Container_request.with_exposed_port (Port.tcp 8080)
    |> Container_request.with_env "APP_ENV" "test"
    |> Container_request.with_env "LOG_LEVEL" "debug"
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_http "/health")
  in

  Container.with_container request (fun container ->
    let* host = Container.host container in
    let* port = Container.mapped_port container (Port.tcp 8080) in
    Printf.printf "App running at http://%s:%d\n" host port;
    (* Run tests against your app *)
    Lwt.return_unit
  )
```

## Creating a Reusable Module

For services you use frequently, create a dedicated module:

### Module Structure

```ocaml
(* my_app_container.ml *)

open Lwt.Syntax
open Testcontainers

let default_image = "my-company/my-app:latest"
let default_port = 8080

type config = {
  image : string;
  api_key : string;
  debug : bool;
}

let create () = {
  image = default_image;
  api_key = "test-key";
  debug = true;
}

let with_image image config = { config with image }
let with_api_key key config = { config with api_key = key }
let with_debug debug config = { config with debug }

let start config =
  let request =
    Container_request.create config.image
    |> Container_request.with_exposed_port (Port.tcp default_port)
    |> Container_request.with_env "API_KEY" config.api_key
    |> Container_request.with_env "DEBUG" (if config.debug then "true" else "false")
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_http ~port:(Port.tcp default_port) "/health")
  in
  Container.start request

let host container =
  Container.host container

let port container =
  Container.mapped_port container (Port.tcp default_port)

let base_url container =
  let* h = host container in
  let* p = port container in
  Lwt.return (Printf.sprintf "http://%s:%d" h p)

let with_my_app ?(config = Fun.id) f =
  let cfg = config (create ()) in
  let request =
    Container_request.create cfg.image
    |> Container_request.with_exposed_port (Port.tcp default_port)
    |> Container_request.with_env "API_KEY" cfg.api_key
    |> Container_request.with_env "DEBUG" (if cfg.debug then "true" else "false")
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_http ~port:(Port.tcp default_port) "/health")
  in
  Container.with_container request (fun container ->
    let* url = base_url container in
    f container url)
```

### Usage

```ocaml
let test_my_app () =
  My_app_container.with_my_app
    ~config:(fun c -> c
      |> My_app_container.with_api_key "secret"
      |> My_app_container.with_debug false)
    (fun container base_url ->
      Printf.printf "Testing app at %s\n" base_url;
      (* Your tests *)
      Lwt.return_unit
    )
```

## Common Patterns

### Web Application

```ocaml
let web_app_container () =
  Container_request.create "my-web-app:latest"
  |> Container_request.with_exposed_port (Port.tcp 3000)
  |> Container_request.with_env "NODE_ENV" "test"
  |> Container_request.with_env "DATABASE_URL" "postgres://..."
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_http "/api/health")
```

### gRPC Service

```ocaml
let grpc_service_container () =
  Container_request.create "my-grpc-service:latest"
  |> Container_request.with_exposed_port (Port.tcp 50051)
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_listening_port (Port.tcp 50051))
```

### Background Worker

```ocaml
let worker_container () =
  Container_request.create "my-worker:latest"
  |> Container_request.with_env "QUEUE_URL" "amqp://..."
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log "Worker started and listening")
```

### Sidecar Pattern

```ocaml
let run_with_sidecar () =
  Network.with_network "test-network" (fun _network ->
    (* Main service *)
    let main_request =
      Container_request.create "my-service:latest"
      |> Container_request.with_name "main-service"
      |> Container_request.with_exposed_port (Port.tcp 8080)
    in

    (* Sidecar (e.g., proxy, logging agent) *)
    let sidecar_request =
      Container_request.create "envoy:latest"
      |> Container_request.with_name "sidecar-proxy"
      |> Container_request.with_exposed_port (Port.tcp 9901)
      |> Container_request.with_env "SERVICE_HOST" "main-service"
    in

    Container.with_container main_request (fun main ->
      Container.with_container sidecar_request (fun sidecar ->
        (* Both containers running, can communicate via network *)
        Lwt.return_unit
      )
    )
  )
```

## Custom Wait Strategies

### Multiple Conditions

```ocaml
let complex_wait_strategy =
  Wait_strategy.all [
    (* Port must be open *)
    Wait_strategy.for_listening_port (Port.tcp 8080);
    (* AND health endpoint must return 200 *)
    Wait_strategy.for_http "/health";
    (* AND specific log message must appear *)
    Wait_strategy.for_log "Application initialized";
  ]
```

### Custom Exec-Based Wait

```ocaml
let wait_for_schema_ready =
  Wait_strategy.for_exec [
    "sh"; "-c";
    "psql -U postgres -c 'SELECT 1 FROM migrations LIMIT 1'"
  ]
```

### HTTP with Custom Validation

```ocaml
let wait_for_healthy_response =
  Wait_strategy.for_http
    ~port:(Port.tcp 8080)
    ~status_codes:[200]
    "/api/v1/health"
```

## Configuration from Environment

```ocaml
let create_config_from_env () =
  let image = match Sys.getenv_opt "TEST_IMAGE" with
    | Some img -> img
    | None -> "default:latest"
  in
  let debug = match Sys.getenv_opt "TEST_DEBUG" with
    | Some "true" -> true
    | _ -> false
  in
  Container_request.create image
  |> Container_request.with_env "DEBUG" (string_of_bool debug)
```

## Building Images for Tests

### Using Pre-built Test Images

```ocaml
(* In CI, build and tag test image first *)
(* docker build -t my-app:test . *)

let request =
  Container_request.create "my-app:test"
```

### Using Docker Compose Images

```ocaml
(* If you have docker-compose.yml with build context *)
(* docker-compose build test-service *)
(* docker tag project_test-service:latest my-test-image:latest *)

let request =
  Container_request.create "my-test-image:latest"
```

## Testing Database Migrations

```ocaml
let test_migrations () =
  Postgres_container.with_postgres (fun container conn_str ->
    (* Copy migration files *)
    let* () = Container.copy_file_to container
      ~src:"./migrations"
      ~dest:"/migrations/"
    in

    (* Run migrations *)
    let* (exit_code, output) = Container.exec container [
      "sh"; "-c";
      "for f in /migrations/*.sql; do psql -U postgres -f $f; done"
    ] in

    if exit_code <> 0 then
      Printf.printf "Migration failed: %s\n" output;

    (* Verify schema *)
    let* (_, output) = Container.exec container [
      "psql"; "-U"; "postgres"; "-c";
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
    ] in
    Printf.printf "Tables created:\n%s\n" output;

    Lwt.return_unit
  )
```

## Multi-Stage Test Setup

```ocaml
let integration_test_setup () =
  (* Phase 1: Infrastructure *)
  Network.with_network "integration-test" (fun _network ->
    Postgres_container.with_postgres (fun pg_container pg_conn ->
      Redis_container.with_redis (fun redis_container redis_uri ->

        (* Phase 2: Run migrations *)
        let* _ = Container.exec pg_container [
          "psql"; "-U"; "postgres"; "-f"; "/docker-entrypoint-initdb.d/schema.sql"
        ] in

        (* Phase 3: Start application *)
        let app_request =
          Container_request.create "my-app:test"
          |> Container_request.with_exposed_port (Port.tcp 8080)
          |> Container_request.with_env "DATABASE_URL" pg_conn
          |> Container_request.with_env "REDIS_URL" redis_uri
          |> Container_request.with_wait_strategy
               (Wait_strategy.for_http "/health")
        in

        Container.with_container app_request (fun app_container ->
          let* app_url = Container.host app_container in
          let* app_port = Container.mapped_port app_container (Port.tcp 8080) in

          (* Phase 4: Run tests *)
          Printf.printf "Running tests against http://%s:%d\n" app_url app_port;
          Lwt.return_unit
        )
      )
    )
  )
```
