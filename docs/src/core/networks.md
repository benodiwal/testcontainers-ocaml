# Networks

Docker networks enable containers to communicate with each other. This is essential for testing multi-service architectures.

## Creating Networks

### Basic Network

```ocaml
open Lwt.Syntax
open Testcontainers

let run_test () =
  let* network = Network.create "my-test-network" in
  Printf.printf "Network ID: %s\n" (Network.id network);
  Printf.printf "Network Name: %s\n" (Network.name network);

  (* Use the network... *)

  let* () = Network.remove network in
  Lwt.return_unit
```

### With Driver

```ocaml
let* network = Network.create ~driver:"bridge" "my-network" in
```

Available drivers:
- `bridge` (default) - Standard isolated network
- `host` - Use host's network stack
- `none` - No networking

### Automatic Cleanup

Use `with_network` for automatic cleanup:

```ocaml
let run_test () =
  Network.with_network "test-network" (fun network ->
    Printf.printf "Network created: %s\n" (Network.name network);
    (* Network automatically removed after this block *)
    Lwt.return_unit
  )
```

## Multi-Container Communication

### Architecture Example

```
┌─────────────────────────────────────────────┐
│              test-network                    │
│                                             │
│  ┌─────────────┐      ┌─────────────┐      │
│  │   webapp    │ ──── │  postgres   │      │
│  │  Port 8080  │      │  Port 5432  │      │
│  └─────────────┘      └─────────────┘      │
│                                             │
└─────────────────────────────────────────────┘
```

### Implementation

```ocaml
open Lwt.Syntax
open Testcontainers

let test_app_with_database () =
  Network.with_network "app-network" (fun network ->
    (* Start PostgreSQL *)
    let pg_request =
      Container_request.create "postgres:16-alpine"
      |> Container_request.with_exposed_port (Port.tcp 5432)
      |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
      |> Container_request.with_env "POSTGRES_DB" "appdb"
      |> Container_request.with_name "postgres"
      |> Container_request.with_wait_strategy
           (Wait_strategy.for_log "ready to accept connections")
    in

    Container.with_container pg_request (fun pg_container ->
      (* Start application container that connects to postgres *)
      let app_request =
        Container_request.create "my-app:latest"
        |> Container_request.with_exposed_port (Port.tcp 8080)
        |> Container_request.with_env "DATABASE_URL"
             "postgresql://postgres:secret@postgres:5432/appdb"
        |> Container_request.with_wait_strategy
             (Wait_strategy.for_http "/health")
      in

      Container.with_container app_request (fun app_container ->
        (* Test the application *)
        let* host = Container.host app_container in
        let* port = Container.mapped_port app_container (Port.tcp 8080) in
        Printf.printf "App available at http://%s:%d\n" host port;
        Lwt.return_unit
      )
    )
  )
```

## Container Names as Hostnames

Within a Docker network, containers can reach each other by name:

```ocaml
(* Container named "postgres" *)
Container_request.with_name "postgres"

(* Another container can connect using hostname "postgres" *)
Container_request.with_env "DB_HOST" "postgres"
```

> **Note**: Container names must be unique. Use unique names or let Docker generate them.

## Network Properties

```ocaml
let* network = Network.create "my-network" in

(* Network ID (Docker's internal ID) *)
let id = Network.id network in  (* e.g., "a1b2c3d4e5f6..." *)

(* Network name *)
let name = Network.name network in  (* "my-network" *)
```

## Use Cases

### Testing Microservices

```ocaml
let test_microservices () =
  Network.with_network "microservices" (fun _network ->
    (* Service A *)
    let* service_a = Container.start (
      Container_request.create "service-a:latest"
      |> Container_request.with_name "service-a"
      |> Container_request.with_exposed_port (Port.tcp 8080)
    ) in

    (* Service B connects to Service A *)
    let* service_b = Container.start (
      Container_request.create "service-b:latest"
      |> Container_request.with_name "service-b"
      |> Container_request.with_env "SERVICE_A_URL" "http://service-a:8080"
      |> Container_request.with_exposed_port (Port.tcp 8081)
    ) in

    (* Run tests against service-b which uses service-a *)
    let* host = Container.host service_b in
    let* port = Container.mapped_port service_b (Port.tcp 8081) in

    (* Test endpoints... *)

    let* () = Container.terminate service_b in
    let* () = Container.terminate service_a in
    Lwt.return_unit
  )
```

### Testing with Multiple Databases

```ocaml
let test_multi_db () =
  Network.with_network "multi-db" (fun _network ->
    (* PostgreSQL for users *)
    let* pg = Container.start (
      Container_request.create "postgres:16-alpine"
      |> Container_request.with_name "users-db"
      |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
    ) in

    (* Redis for cache *)
    let* redis = Container.start (
      Container_request.create "redis:7-alpine"
      |> Container_request.with_name "cache"
    ) in

    (* MongoDB for events *)
    let* mongo = Container.start (
      Container_request.create "mongo:7"
      |> Container_request.with_name "events-db"
    ) in

    (* Your application connects to:
       - users-db:5432
       - cache:6379
       - events-db:27017 *)

    (* Cleanup *)
    let* () = Container.terminate mongo in
    let* () = Container.terminate redis in
    let* () = Container.terminate pg in
    Lwt.return_unit
  )
```

## Best Practices

### Use Unique Network Names

```ocaml
let network_name = Printf.sprintf "test-%s" (Uuidm.to_string (Uuidm.v4_gen (Random.State.make_self_init ()) ()))
Network.with_network network_name (fun network -> ...)
```

### Always Clean Up

```ocaml
(* Good: automatic cleanup *)
Network.with_network "test-net" (fun network -> ...)

(* Manual: ensure cleanup happens *)
let* network = Network.create "test-net" in
Lwt.finalize
  (fun () -> run_tests network)
  (fun () -> Network.remove network)
```

### Use with_container Inside with_network

```ocaml
Network.with_network "net" (fun _network ->
  Container.with_container request1 (fun c1 ->
    Container.with_container request2 (fun c2 ->
      (* Both containers on same network, both cleaned up automatically *)
      run_tests c1 c2
    )
  )
)
```

## Limitations

Current limitations (may be addressed in future versions):

1. **No network aliases** - Containers are reachable by name only
2. **No custom subnets** - Uses Docker's default subnet allocation
3. **No IPv6** - IPv4 only
4. **Bridge driver only tested** - Other drivers may work but aren't tested
