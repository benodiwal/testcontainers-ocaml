# Memcached

The Memcached module provides a pre-configured Memcached container for integration testing with distributed caching.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_memcached

let test_memcached () =
  Memcached_container.with_memcached (fun container connection_string ->
    Printf.printf "Memcached running at: %s\n" connection_string;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-memcached
```

In your `dune` file:

```scheme
(libraries testcontainers-memcached)
```

## Configuration

### Basic Usage

```ocaml
Memcached_container.with_memcached (fun container connection_string ->
  (* connection_string: "127.0.0.1:11211" *)
  ...
)
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `memcached:1.6-alpine` | Docker image |
| `with_memory_mb` | `64` | Memory limit in MB |

### Custom Memory Limit

```ocaml
Memcached_container.with_memcached
  ~config:(fun c -> c
    |> Memcached_container.with_memory_mb 128)
  (fun container conn -> ...)
```

### Custom Image

```ocaml
Memcached_container.with_memcached
  ~config:(fun c -> c
    |> Memcached_container.with_image "memcached:1.5-alpine")
  (fun container conn -> ...)
```

## Connection Details

### Connection String

```
127.0.0.1:11211
```

### Individual Components

```ocaml
Memcached_container.with_memcached (fun container conn ->
  let* host = Memcached_container.host container in  (* "127.0.0.1" *)
  let* port = Memcached_container.port config container in  (* 11211 *)
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config =
    Memcached_container.create ()
    |> Memcached_container.with_memory_mb 256
  in
  let* container = Memcached_container.start config in
  let* conn = Memcached_container.connection_string config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Basic Operations

### Set and Get Values

Using the container's built-in tools:

```ocaml
let test_basic_operations container =
  (* SET operation using printf/nc *)
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "sh"; "-c";
    "printf 'set mykey 0 0 5\\r\\nhello\\r\\n' | nc localhost 11211"
  ] in
  assert (exit_code = 0);

  (* GET operation *)
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "sh"; "-c";
    "printf 'get mykey\\r\\n' | nc localhost 11211"
  ] in
  Printf.printf "Value: %s\n" output;

  Lwt.return_unit
```

### Delete Values

```ocaml
let delete_key container key =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "sh"; "-c";
    Printf.sprintf "printf 'delete %s\\r\\n' | nc localhost 11211" key
  ] in
  Lwt.return (exit_code = 0)
```

### Flush All Data

```ocaml
let flush_all container =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "sh"; "-c";
    "printf 'flush_all\\r\\n' | nc localhost 11211"
  ] in
  Lwt.return (exit_code = 0)
```

## Statistics

### Get Server Stats

```ocaml
let get_stats container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "sh"; "-c";
    "printf 'stats\\r\\n' | nc localhost 11211"
  ] in
  Printf.printf "Stats:\n%s\n" output;
  Lwt.return output
```

### Get Slab Stats

```ocaml
let get_slab_stats container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "sh"; "-c";
    "printf 'stats slabs\\r\\n' | nc localhost 11211"
  ] in
  Printf.printf "Slab stats:\n%s\n" output;
  Lwt.return output
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_memcached

let test_cache_operations _switch () =
  Memcached_container.with_memcached (fun container _conn ->
    (* Set a value *)
    let* (code, output) = Container.exec container [
      "sh"; "-c";
      "printf 'set session:123 0 60 9\\r\\nuser_data\\r\\n' | nc localhost 11211"
    ] in
    Alcotest.(check int) "set succeeds" 0 code;
    Alcotest.(check bool) "stored" true (String.length output > 0);

    (* Get the value *)
    let* (code, output) = Container.exec container [
      "sh"; "-c";
      "printf 'get session:123\\r\\n' | nc localhost 11211"
    ] in
    Alcotest.(check int) "get succeeds" 0 code;
    Alcotest.(check bool) "has data" true
      (String.length output > 0);

    (* Delete the value *)
    let* (code, _) = Container.exec container [
      "sh"; "-c";
      "printf 'delete session:123\\r\\n' | nc localhost 11211"
    ] in
    Alcotest.(check int) "delete succeeds" 0 code;

    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "Memcached Tests" [
      "cache", [
        Alcotest_lwt.test_case "operations" `Slow test_cache_operations;
      ];
    ]
  )
```

## Wait Strategy

Memcached uses a port-based wait strategy:

```ocaml
Wait_strategy.for_listening_port ~timeout:30.0 (Port.tcp 11211)
```

## Memcached Protocol

### Command Format

```
<command> <key> <flags> <exptime> <bytes>\r\n
<data>\r\n
```

### Common Commands

| Command | Description |
|---------|-------------|
| `set` | Store a value |
| `get` | Retrieve a value |
| `delete` | Remove a value |
| `incr` | Increment numeric value |
| `decr` | Decrement numeric value |
| `flush_all` | Clear all data |
| `stats` | Get server statistics |

## Performance Tips

### Memory Configuration

For tests with large data:

```ocaml
Memcached_container.with_memory_mb 512
```

### Connection Pooling

When using a Memcached client library, configure connection pooling appropriately for test performance.

## Troubleshooting

### Connection Refused

Memcached starts quickly, but always use `with_memcached`:

```ocaml
(* Good *)
Memcached_container.with_memcached (fun container conn -> ...)

(* May fail *)
let* container = Container.start request in
(* immediate connection *)
```

### Data Not Found

Remember that Memcached is ephemeral - data is lost when the container stops. Each test starts with a fresh instance.

### Memory Limits

If you're storing large values and getting evictions:

```ocaml
Memcached_container.with_memory_mb 256
```
