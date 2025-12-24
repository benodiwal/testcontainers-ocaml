# testcontainers-ocaml

Docker containers for OCaml integration tests. Lightweight, throwaway instances of databases, message brokers, or any service that runs in a Docker container.

## Installation

```bash
opam install testcontainers              # Core library
opam install testcontainers-postgres     # PostgreSQL module
opam install testcontainers-redis        # Redis module
opam install testcontainers-rabbitmq     # RabbitMQ module
```

Or add to your `dune-project`:

```lisp
(depends
  (testcontainers (>= 0.1))
  (testcontainers-postgres (>= 0.1)))  ; if needed
```

## Quick Start

### Basic Container

```ocaml
open Lwt.Syntax
open Testcontainers

let () = Lwt_main.run begin
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_exposed_port (Port.tcp 80)
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_listening_port (Port.tcp 80))
  in
  Container.with_container request (fun container ->
    let* host = Container.host container in
    let* port = Container.mapped_port container (Port.tcp 80) in
    Printf.printf "Nginx running at http://%s:%d\n" host port;
    (* Your test code here *)
    Lwt.return_unit
  )
end
```

### PostgreSQL

```ocaml
open Lwt.Syntax
open Testcontainers_postgres

let test_with_postgres () =
  Postgres_container.with_postgres
    ~config:(fun c ->
      c
      |> Postgres_container.with_database "testdb"
      |> Postgres_container.with_username "user"
      |> Postgres_container.with_password "pass")
    (fun _container conn_str ->
      (* conn_str: postgresql://user:pass@127.0.0.1:XXXXX/testdb *)
      (* Use with pgx, postgresql-ocaml, or other client *)
      Lwt.return_unit)
```

### Redis

```ocaml
open Lwt.Syntax
open Testcontainers_redis

let test_with_redis () =
  Redis_container.with_redis (fun _container uri ->
    (* uri: redis://127.0.0.1:XXXXX *)
    Lwt.return_unit)

(* With password *)
let test_with_redis_auth () =
  Redis_container.with_redis
    ~config:(fun c -> Redis_container.with_password "secret" c)
    (fun _container uri ->
      (* uri: redis://:secret@127.0.0.1:XXXXX *)
      Lwt.return_unit)
```

### RabbitMQ

```ocaml
open Lwt.Syntax
open Testcontainers_rabbitmq

let test_with_rabbitmq () =
  Rabbitmq_container.with_rabbitmq (fun _container amqp_url ->
    (* amqp_url: amqp://guest:guest@127.0.0.1:XXXXX/ *)
    Lwt.return_unit)
```

## Using with Alcotest

```ocaml
(* test/test_integration.ml *)
open Lwt.Syntax
open Testcontainers_postgres

let test_database_operations _switch () =
  Postgres_container.with_postgres (fun _container conn_str ->
    (* Connect to PostgreSQL and run tests *)
    Printf.printf "Testing with: %s\n" conn_str;
    Lwt.return_unit)

let () =
  Lwt_main.run @@
  Alcotest_lwt.run "Integration Tests" [
    "database", [
      Alcotest_lwt.test_case "postgres operations" `Slow test_database_operations;
    ]
  ]
```

```lisp
; test/dune
(test
 (name test_integration)
 (libraries
  testcontainers
  testcontainers-postgres
  alcotest
  alcotest-lwt
  lwt
  lwt.unix)
 (preprocess (pps lwt_ppx)))
```

## API Reference

### Container Request (Builder Pattern)

```ocaml
Container_request.create "image:tag"
|> Container_request.with_exposed_port (Port.tcp 8080)
|> Container_request.with_exposed_ports [Port.tcp 80; Port.udp 53]
|> Container_request.with_env "KEY" "value"
|> Container_request.with_envs [("K1", "v1"); ("K2", "v2")]
|> Container_request.with_cmd ["arg1"; "arg2"]
|> Container_request.with_entrypoint ["/entrypoint.sh"]
|> Container_request.with_mount (Volume.bind ~host:"/local" ~container:"/data" ())
|> Container_request.with_label "key" "value"
|> Container_request.with_working_dir "/app"
|> Container_request.with_user "nobody"
|> Container_request.with_privileged true
|> Container_request.with_wait_strategy (Wait_strategy.for_listening_port port)
|> Container_request.with_startup_timeout 120.0
```

### Wait Strategies

```ocaml
(* Wait for TCP port *)
Wait_strategy.for_listening_port (Port.tcp 5432)

(* Wait for log message *)
Wait_strategy.for_log "Server started"
Wait_strategy.for_log ~occurrence:2 "ready"  (* Wait for message to appear twice *)

(* Wait for log regex *)
Wait_strategy.for_log_regex "Started.*in [0-9]+ ms"

(* Wait for HTTP endpoint *)
Wait_strategy.for_http ~port:(Port.tcp 8080) "/health"
Wait_strategy.for_http ~status_codes:[200; 204] "/ready"

(* Wait for command execution *)
Wait_strategy.for_exec ["pg_isready"; "-U"; "postgres"]

(* Combine strategies *)
Wait_strategy.all [port_wait; log_wait]  (* All must pass *)
Wait_strategy.any [http_wait; log_wait]  (* Any one passes *)

(* Configure timeout *)
Wait_strategy.for_listening_port port |> Wait_strategy.with_timeout 30.0
```

### Container Lifecycle

```ocaml
(* Automatic cleanup (recommended) *)
Container.with_container request (fun container ->
  (* Container automatically terminated after this block *)
  Lwt.return_unit)

(* Manual control *)
let* container = Container.start request in
let* port = Container.mapped_port container (Port.tcp 80) in
let* logs = Container.logs container in
let* (exit_code, output) = Container.exec container ["ls"; "-la"] in
let* () = Container.terminate container in
```

## Requirements

- OCaml >= 5.0
- Docker daemon running
- Unix socket access to `/var/run/docker.sock`

## Project Structure

```
testcontainers-ocaml/
├── lib/                    # Core library
│   ├── container.ml        # Container lifecycle management
│   ├── container_request.ml# Builder pattern for configuration
│   ├── wait_strategy.ml    # Wait strategies
│   ├── docker_client.ml    # Docker API client
│   └── ...
├── modules/               # Service-specific modules
│   ├── postgres/
│   ├── redis/
│   └── rabbitmq/
└── examples/              # Usage examples
```

## License

Apache-2.0
