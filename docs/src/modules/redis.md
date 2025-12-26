# Redis

The Redis module provides a pre-configured container for integration testing with Redis.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_redis

let test_redis () =
  Redis_container.with_redis (fun container uri ->
    Printf.printf "Redis running at: %s\n" uri;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-redis
```

In your `dune` file:

```scheme
(libraries testcontainers-redis)
```

## Configuration

### Basic Usage

```ocaml
Redis_container.with_redis (fun container uri ->
  (* uri: redis://127.0.0.1:6379 *)
  ...
)
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `redis:7-alpine` | Docker image |

### Custom Image

```ocaml
Redis_container.with_redis
  ~config:(fun c -> c
    |> Redis_container.with_image "redis:6-alpine")
  (fun container uri -> ...)
```

## Connection Details

### Redis URI

```
redis://127.0.0.1:6379
```

### Individual Components

```ocaml
Redis_container.with_redis (fun container uri ->
  let* host = Redis_container.host container in  (* "127.0.0.1" *)
  let* port = Redis_container.port container in  (* 6379 *)
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config = Redis_container.create () in
  let* container = Redis_container.start config in
  let* uri = Redis_container.uri config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Using with Redis Libraries

### With redis-lwt

```ocaml
open Lwt.Syntax

let test_with_redis_lwt () =
  Redis_container.with_redis (fun container _uri ->
    let* host = Redis_container.host container in
    let* port = Redis_container.port container in

    (* Connect using redis-lwt *)
    (* let* conn = Redis_lwt.connect ~host ~port () in *)

    (* Example operations:
       let* () = Redis_lwt.set conn "key" "value" in
       let* result = Redis_lwt.get conn "key" in
       assert (result = Some "value");
    *)

    Printf.printf "Connected to Redis at %s:%d\n" host port;
    Lwt.return_unit
  )
```

## Data Operations via CLI

### Set and Get Values

```ocaml
let test_basic_operations container =
  (* SET operation *)
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "redis-cli"; "SET"; "mykey"; "myvalue"
  ] in
  assert (exit_code = 0);

  (* GET operation *)
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "redis-cli"; "GET"; "mykey"
  ] in
  assert (exit_code = 0);
  Printf.printf "Value: %s\n" (String.trim output);
  Lwt.return_unit
```

### Working with Data Structures

```ocaml
let test_data_structures container =
  (* List operations *)
  let* _ = Testcontainers.Container.exec container [
    "redis-cli"; "RPUSH"; "mylist"; "a"; "b"; "c"
  ] in

  let* (_, output) = Testcontainers.Container.exec container [
    "redis-cli"; "LRANGE"; "mylist"; "0"; "-1"
  ] in
  Printf.printf "List: %s\n" output;

  (* Hash operations *)
  let* _ = Testcontainers.Container.exec container [
    "redis-cli"; "HSET"; "user:1"; "name"; "Alice"; "email"; "alice@example.com"
  ] in

  let* (_, output) = Testcontainers.Container.exec container [
    "redis-cli"; "HGETALL"; "user:1"
  ] in
  Printf.printf "Hash: %s\n" output;

  (* Set operations *)
  let* _ = Testcontainers.Container.exec container [
    "redis-cli"; "SADD"; "tags"; "ocaml"; "redis"; "testing"
  ] in

  let* (_, output) = Testcontainers.Container.exec container [
    "redis-cli"; "SMEMBERS"; "tags"
  ] in
  Printf.printf "Set: %s\n" output;

  Lwt.return_unit
```

### Running Lua Scripts

```ocaml
let test_lua_script container =
  let script = {|
    local key = KEYS[1]
    local increment = ARGV[1]
    local current = redis.call('GET', key) or 0
    local new_value = tonumber(current) + tonumber(increment)
    redis.call('SET', key, new_value)
    return new_value
  |} in

  let* (exit_code, output) = Testcontainers.Container.exec container [
    "redis-cli"; "EVAL"; script; "1"; "counter"; "5"
  ] in
  Printf.printf "New counter value: %s\n" (String.trim output);
  Lwt.return (exit_code = 0)
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_redis

let test_cache_operations _switch () =
  Redis_container.with_redis (fun container _uri ->
    (* Test SET/GET *)
    let* (code, _) = Container.exec container [
      "redis-cli"; "SET"; "session:123"; "user_data_here"
    ] in
    Alcotest.(check int) "SET succeeds" 0 code;

    let* (code, output) = Container.exec container [
      "redis-cli"; "GET"; "session:123"
    ] in
    Alcotest.(check int) "GET succeeds" 0 code;
    Alcotest.(check string) "value matches" "user_data_here" (String.trim output);

    (* Test TTL *)
    let* (code, _) = Container.exec container [
      "redis-cli"; "SETEX"; "temp:key"; "60"; "temporary"
    ] in
    Alcotest.(check int) "SETEX succeeds" 0 code;

    let* (code, output) = Container.exec container [
      "redis-cli"; "TTL"; "temp:key"
    ] in
    Alcotest.(check int) "TTL succeeds" 0 code;
    let ttl = int_of_string (String.trim output) in
    Alcotest.(check bool) "TTL > 0" true (ttl > 0);

    Lwt.return_unit
  )

let test_pub_sub _switch () =
  Redis_container.with_redis (fun container _uri ->
    (* Publish a message (subscriber would need separate connection) *)
    let* (code, output) = Container.exec container [
      "redis-cli"; "PUBLISH"; "notifications"; "Hello subscribers!"
    ] in
    Alcotest.(check int) "PUBLISH succeeds" 0 code;
    Printf.printf "Subscribers received: %s\n" (String.trim output);
    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "Redis Tests" [
      "cache", [
        Alcotest_lwt.test_case "operations" `Slow test_cache_operations;
      ];
      "pubsub", [
        Alcotest_lwt.test_case "publish" `Slow test_pub_sub;
      ];
    ]
  )
```

## Wait Strategy

Redis starts very quickly. The module uses a port-based wait strategy:

```ocaml
Wait_strategy.for_listening_port (Port.tcp 6379)
```

## Redis Configuration

### Custom Redis Configuration

```ocaml
let with_custom_config () =
  let request =
    Container_request.create "redis:7-alpine"
    |> Container_request.with_exposed_port (Port.tcp 6379)
    |> Container_request.with_cmd [
         "redis-server";
         "--maxmemory"; "100mb";
         "--maxmemory-policy"; "allkeys-lru"
       ]
  in

  Container.with_container request (fun container ->
    (* Redis with memory limits *)
    Lwt.return_unit
  )
```

### Persistence Disabled

For faster tests:

```ocaml
Container_request.with_cmd [
  "redis-server";
  "--save"; "";
  "--appendonly"; "no"
]
```

## Troubleshooting

### Connection Refused

Redis starts quickly, but ensure you're using `with_redis`:

```ocaml
(* Good *)
Redis_container.with_redis (fun container uri -> ...)

(* May fail if Redis isn't ready *)
let* container = Container.start request in
(* immediate connection attempt *)
```

### Memory Issues

For large datasets in tests:

```ocaml
Container_request.with_cmd [
  "redis-server";
  "--maxmemory"; "256mb"
]
```

### Slow Tests

Redis operations are fast. If tests are slow, check:
1. Network latency (shouldn't be an issue with local Docker)
2. Large data volumes
3. Expensive Lua scripts
