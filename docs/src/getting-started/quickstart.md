# Quick Start

This guide walks you through creating your first integration test with Testcontainers OCaml in under 5 minutes.

## The Goal

We'll write a test that:
1. Starts a Redis container
2. Connects and sets a value
3. Retrieves and verifies the value
4. Automatically cleans up

## Step 1: Project Setup

Create a new directory and initialize:

```bash
mkdir my_integration_tests
cd my_integration_tests
```

Create `dune-project`:

```scheme
(lang dune 3.0)
(name my_integration_tests)
```

Create `dune`:

```scheme
(executable
 (name main)
 (libraries
  testcontainers
  testcontainers-redis
  lwt
  lwt.unix)
 (preprocess (pps lwt_ppx)))
```

## Step 2: Write the Test

Create `main.ml`:

```ocaml
open Lwt.Syntax
open Testcontainers

let () = Lwt_main.run (
  print_endline "Starting Redis container...";

  Testcontainers_redis.Redis_container.with_redis (fun container uri ->
    Printf.printf "Redis is running at: %s\n" uri;

    (* Get connection details *)
    let* host = Testcontainers_redis.Redis_container.host container in
    let* port = Testcontainers_redis.Redis_container.port container in
    Printf.printf "Host: %s, Port: %d\n" host port;

    (* In a real test, you would use a Redis client here *)
    (* For example with redis-lwt:
       let* client = Redis_lwt.connect ~host ~port () in
       let* () = Redis_lwt.set client "key" "value" in
       let* result = Redis_lwt.get client "key" in
       assert (result = Some "value");
    *)

    print_endline "Test completed successfully!";
    Lwt.return_unit
  )
)
```

## Step 3: Run It

```bash
dune exec ./main.exe
```

Output:

```
Starting Redis container...
Redis is running at: redis://127.0.0.1:55432
Host: 127.0.0.1, Port: 55432
Test completed successfully!
```

The container starts, your code runs, and then the container is automatically removed.

## Step 4: Using with Alcotest

For real test suites, integrate with Alcotest:

Create `test/dune`:

```scheme
(test
 (name test_main)
 (libraries
  testcontainers
  testcontainers-redis
  alcotest
  alcotest-lwt
  lwt
  lwt.unix)
 (preprocess (pps lwt_ppx)))
```

Create `test/test_main.ml`:

```ocaml
open Lwt.Syntax

let test_redis_connection _switch () =
  Testcontainers_redis.Redis_container.with_redis (fun _container uri ->
    Alcotest.(check bool) "uri starts with redis://" true
      (String.length uri > 8 && String.sub uri 0 8 = "redis://");
    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "My Integration Tests" [
      "redis", [
        Alcotest_lwt.test_case "connection" `Slow test_redis_connection;
      ];
    ]
  )
```

Run tests:

```bash
dune runtest
```

## What Just Happened?

1. **Container Request**: `with_redis` created a container configuration
2. **Image Pull**: Docker pulled `redis:7-alpine` (first run only)
3. **Container Start**: A new Redis container started
4. **Wait Strategy**: Library waited until Redis was ready to accept connections
5. **Port Mapping**: Docker assigned a random available port
6. **Your Code**: The callback received the container and connection URI
7. **Cleanup**: Container was stopped and removed after the callback completed

## Next Steps

- [Writing Your First Test](./first-test.md) - A more detailed walkthrough
- [Containers](../core/containers.md) - Understanding container lifecycle
- [PostgreSQL Module](../modules/postgres.md) - Using database containers
