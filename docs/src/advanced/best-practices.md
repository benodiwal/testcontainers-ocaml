# Best Practices

This guide covers recommended patterns and practices for effective integration testing with Testcontainers OCaml.

## Test Organization

### Use Helper Functions

Create wrapper functions for common setups:

```ocaml
(* test_helpers.ml *)

let with_postgres_db f =
  Postgres_container.with_postgres
    ~config:(fun c -> c
      |> Postgres_container.with_database "testdb"
      |> Postgres_container.with_username "test"
      |> Postgres_container.with_password "test")
    (fun container conn_str ->
      (* Run migrations *)
      let* _ = setup_schema container in
      f conn_str)

let with_redis_cache f =
  Redis_container.with_redis (fun container uri ->
    f uri)

let with_full_stack f =
  with_postgres_db (fun db_url ->
    with_redis_cache (fun cache_url ->
      f ~db_url ~cache_url))
```

### Test Isolation

Each test should be independent:

```ocaml
(* Good: Each test gets fresh state *)
let test_create_user _switch () =
  with_postgres_db (fun conn_str ->
    (* Fresh database for this test *)
    Lwt.return_unit)

let test_delete_user _switch () =
  with_postgres_db (fun conn_str ->
    (* Another fresh database *)
    Lwt.return_unit)
```

### Group Related Tests

```ocaml
let user_tests = [
  Alcotest_lwt.test_case "create" `Slow test_create_user;
  Alcotest_lwt.test_case "update" `Slow test_update_user;
  Alcotest_lwt.test_case "delete" `Slow test_delete_user;
]

let order_tests = [
  Alcotest_lwt.test_case "place order" `Slow test_place_order;
  Alcotest_lwt.test_case "cancel order" `Slow test_cancel_order;
]

let () =
  Lwt_main.run (
    Alcotest_lwt.run "Integration Tests" [
      ("users", user_tests);
      ("orders", order_tests);
    ]
  )
```

## Resource Management

### Always Use `with_container`

```ocaml
(* Good: Automatic cleanup *)
Container.with_container request (fun container ->
  may_fail container)
(* Container cleaned up even if may_fail raises *)

(* Risky: Manual cleanup might be skipped *)
let* container = Container.start request in
let* () = may_fail container in  (* If this fails... *)
Container.terminate container     (* ...this never runs *)
```

### Nest Contexts Properly

```ocaml
(* Cleanup happens in reverse order *)
Network.with_network "test" (fun network ->
  Container.with_container db_request (fun db ->
    Container.with_container app_request (fun app ->
      (* Use app and db *)
      Lwt.return_unit
    )
    (* app cleaned up first *)
  )
  (* db cleaned up second *)
)
(* network cleaned up last *)
```

## Performance Optimization

### Use Specific Image Tags

```ocaml
(* Good: Specific, reproducible *)
Container_request.create "postgres:16.1-alpine"

(* Avoid: Can change unexpectedly *)
Container_request.create "postgres:latest"
```

### Use Alpine Images

```ocaml
(* Smaller, faster to pull *)
"postgres:16-alpine"    (* ~80MB *)
"redis:7-alpine"        (* ~30MB *)
"mongo:7"               (* ~700MB - no alpine available *)
```

### Pre-pull Images in CI

```yaml
# .github/workflows/test.yml
- name: Pull Docker images
  run: |
    docker pull postgres:16-alpine
    docker pull redis:7-alpine
```

### Parallel Test Execution

```ocaml
(* Run independent tests in parallel *)
let test_a () = with_postgres_db (fun _ -> ...)
let test_b () = with_redis_cache (fun _ -> ...)

(* These can run simultaneously *)
let* () = Lwt.join [test_a (); test_b ()] in
```

### Share Containers When Safe

For read-only tests against the same data:

```ocaml
let shared_container = ref None

let get_or_create_container () =
  match !shared_container with
  | Some c -> Lwt.return c
  | None ->
      let* c = Postgres_container.start (Postgres_container.create ()) in
      let* _ = seed_test_data c in
      shared_container := Some c;
      Lwt.return c

(* Cleanup at end of test suite *)
let cleanup () =
  match !shared_container with
  | Some c -> Container.terminate c
  | None -> Lwt.return_unit
```

## Configuration

### Use Environment Variables for CI

```ocaml
let skip_slow_tests () =
  Sys.getenv_opt "CI" = Some "true" &&
  Sys.getenv_opt "RUN_SLOW_TESTS" <> Some "true"

let test_slow_operation _switch () =
  if skip_slow_tests () then
    Lwt.return_unit
  else
    (* actual test *)
```

### Configurable Timeouts

```ocaml
let startup_timeout =
  match Sys.getenv_opt "CONTAINER_TIMEOUT" with
  | Some t -> float_of_string t
  | None -> 60.0

let request =
  Container_request.create "slow-starting-app:latest"
  |> Container_request.with_startup_timeout startup_timeout
```

## Debugging

### Capture Logs on Failure

```ocaml
let test_with_debug _switch () =
  Container.with_container request (fun container ->
    Lwt.catch
      (fun () -> run_test container)
      (fun exn ->
        (* Capture logs before re-raising *)
        let* logs = Container.logs container in
        Printf.printf "=== Container Logs ===\n%s\n" logs;
        Lwt.fail exn))
```

### Print Connection Details

```ocaml
let test_with_info _switch () =
  Postgres_container.with_postgres (fun container conn_str ->
    Printf.printf "Connection: %s\n" conn_str;
    Printf.printf "Container ID: %s\n" (Container.id container);
    run_test conn_str)
```

### Keep Failed Containers

```ocaml
let keep_on_failure = Sys.getenv_opt "KEEP_FAILED_CONTAINERS" = Some "true"

let test_with_inspection _switch () =
  let* container = Container.start request in
  Lwt.catch
    (fun () ->
      let* () = run_test container in
      Container.terminate container)
    (fun exn ->
      if keep_on_failure then begin
        Printf.printf "Container %s kept for inspection\n" (Container.id container);
        Lwt.fail exn
      end else begin
        let* () = Container.terminate container in
        Lwt.fail exn
      end)
```

## Test Data

### Use Factories

```ocaml
module UserFactory = struct
  let counter = ref 0

  let create ?(name = "Test User") ?(email = None) () =
    incr counter;
    let email = match email with
      | Some e -> e
      | None -> Printf.sprintf "user%d@test.com" !counter
    in
    { name; email }
end

let test_user_creation _switch () =
  with_postgres_db (fun conn_str ->
    let user = UserFactory.create ~name:"Alice" () in
    (* user.email is "user1@test.com" - unique *)
    Lwt.return_unit)
```

### Seed Data Functions

```ocaml
let seed_users container =
  Container.exec container [
    "psql"; "-U"; "postgres"; "-c";
    {|
      INSERT INTO users (email, name) VALUES
      ('alice@test.com', 'Alice'),
      ('bob@test.com', 'Bob');
    |}
  ]

let seed_products container =
  Container.exec container [
    "psql"; "-U"; "postgres"; "-c";
    {|
      INSERT INTO products (name, price) VALUES
      ('Widget', 9.99),
      ('Gadget', 19.99);
    |}
  ]

let seed_all container =
  let* _ = seed_users container in
  let* _ = seed_products container in
  Lwt.return_unit
```

## Error Handling

### Graceful Degradation

```ocaml
let test_requires_docker _switch () =
  Lwt.catch
    (fun () ->
      let* available = Docker_client.ping () in
      if not available then begin
        Printf.printf "Docker not available, skipping test\n";
        Lwt.return_unit
      end else
        run_actual_test ())
    (fun _ ->
      Printf.printf "Docker connection failed, skipping test\n";
      Lwt.return_unit)
```

### Retry Logic

```ocaml
let with_retry ~attempts ~delay f =
  let rec loop n =
    Lwt.catch f (fun exn ->
      if n <= 1 then Lwt.fail exn
      else begin
        Printf.printf "Attempt failed, retrying in %.1fs...\n" delay;
        let* () = Lwt_unix.sleep delay in
        loop (n - 1)
      end)
  in
  loop attempts

let test_flaky_service _switch () =
  with_retry ~attempts:3 ~delay:1.0 (fun () ->
    Container.with_container request (fun container ->
      call_flaky_endpoint container))
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup OCaml
        uses: ocaml/setup-ocaml@v2
        with:
          ocaml-compiler: 5.1

      - name: Install dependencies
        run: opam install . --deps-only --with-test

      - name: Pull Docker images
        run: |
          docker pull postgres:16-alpine
          docker pull redis:7-alpine

      - name: Run tests
        run: opam exec -- dune runtest
        env:
          CONTAINER_TIMEOUT: "120"
```

### Skip Integration Tests

```ocaml
let skip_integration =
  Sys.getenv_opt "SKIP_INTEGRATION_TESTS" = Some "true"

let integration_test name f =
  if skip_integration then
    Alcotest_lwt.test_case name `Quick (fun _ () -> Lwt.return_unit)
  else
    Alcotest_lwt.test_case name `Slow f
```
