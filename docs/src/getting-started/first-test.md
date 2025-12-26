# Writing Your First Test

This tutorial walks through creating a realistic integration test for a user repository backed by PostgreSQL.

## Scenario

You have a `User_repository` module that stores users in PostgreSQL. You want to test:

1. Creating a user
2. Retrieving a user by ID
3. Listing all users

## Project Structure

```
my_app/
├── dune-project
├── lib/
│   ├── dune
│   └── user_repository.ml
└── test/
    ├── dune
    └── test_user_repository.ml
```

## The Repository Module

`lib/user_repository.ml`:

```ocaml
(* Simplified example - in practice you'd use Caqti or similar *)

type user = {
  id: int;
  name: string;
  email: string;
}

type t = {
  connection_string: string;
}

let create connection_string = { connection_string }

let add_user t ~name ~email =
  (* Execute: INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id *)
  ignore (t, name, email);
  Lwt.return { id = 1; name; email }

let get_user t ~id =
  (* Execute: SELECT id, name, email FROM users WHERE id = $1 *)
  ignore (t, id);
  Lwt.return_some { id; name = "Test"; email = "test@example.com" }

let list_users t =
  (* Execute: SELECT id, name, email FROM users *)
  ignore t;
  Lwt.return []
```

## The Test File

`test/test_user_repository.ml`:

```ocaml
open Lwt.Syntax
open Testcontainers

(* Test helper: create repository with containerized Postgres *)
let with_repository f =
  Testcontainers_postgres.Postgres_container.with_postgres
    ~config:(fun c -> c
      |> Testcontainers_postgres.Postgres_container.with_database "testdb"
      |> Testcontainers_postgres.Postgres_container.with_username "testuser"
      |> Testcontainers_postgres.Postgres_container.with_password "testpass")
    (fun container connection_string ->
      (* Run migrations or schema setup *)
      let* (_exit_code, _output) = Container.exec container [
        "psql"; "-U"; "testuser"; "-d"; "testdb"; "-c";
        "CREATE TABLE IF NOT EXISTS users (
           id SERIAL PRIMARY KEY,
           name VARCHAR(255) NOT NULL,
           email VARCHAR(255) UNIQUE NOT NULL
         );"
      ] in

      (* Create repository and run test *)
      let repo = User_repository.create connection_string in
      f repo)

(* Test: Adding a user *)
let test_add_user _switch () =
  with_repository (fun repo ->
    let* user = User_repository.add_user repo
      ~name:"Alice"
      ~email:"alice@example.com"
    in
    Alcotest.(check string) "name" "Alice" user.name;
    Alcotest.(check string) "email" "alice@example.com" user.email;
    Alcotest.(check bool) "has id" true (user.id > 0);
    Lwt.return_unit
  )

(* Test: Retrieving a user *)
let test_get_user _switch () =
  with_repository (fun repo ->
    let* created = User_repository.add_user repo
      ~name:"Bob"
      ~email:"bob@example.com"
    in
    let* retrieved = User_repository.get_user repo ~id:created.id in
    match retrieved with
    | None -> Alcotest.fail "User not found"
    | Some user ->
        Alcotest.(check int) "id matches" created.id user.id;
        Alcotest.(check string) "name matches" "Bob" user.name;
        Lwt.return_unit
  )

(* Test: Listing users *)
let test_list_users _switch () =
  with_repository (fun repo ->
    let* _ = User_repository.add_user repo ~name:"User1" ~email:"u1@test.com" in
    let* _ = User_repository.add_user repo ~name:"User2" ~email:"u2@test.com" in
    let* users = User_repository.list_users repo in
    Alcotest.(check int) "two users" 2 (List.length users);
    Lwt.return_unit
  )

(* Test runner *)
let () =
  Lwt_main.run (
    Alcotest_lwt.run "User Repository" [
      "users", [
        Alcotest_lwt.test_case "add user" `Slow test_add_user;
        Alcotest_lwt.test_case "get user" `Slow test_get_user;
        Alcotest_lwt.test_case "list users" `Slow test_list_users;
      ];
    ]
  )
```

## Test dune File

`test/dune`:

```scheme
(test
 (name test_user_repository)
 (libraries
  my_app
  testcontainers
  testcontainers-postgres
  alcotest
  alcotest-lwt
  lwt
  lwt.unix)
 (preprocess (pps lwt_ppx)))
```

## Running the Tests

```bash
dune runtest
```

Output:

```
Testing `User Repository'.
  [OK]          users          0   add user.
  [OK]          users          1   get user.
  [OK]          users          2   list users.

Test Successful in 12.5s. 3 tests run.
```

## Key Patterns

### 1. Wrapper Function

Create a `with_repository` helper that:
- Starts the container
- Runs migrations/setup
- Creates your module instance
- Passes it to the test

```ocaml
let with_repository f =
  Postgres_container.with_postgres ~config:... (fun container conn_str ->
    (* setup *)
    let repo = create conn_str in
    f repo)
```

### 2. Test Isolation

Each test gets a fresh container. No shared state between tests:

```ocaml
let test_a _switch () =
  with_repository (fun repo -> (* fresh database *))

let test_b _switch () =
  with_repository (fun repo -> (* another fresh database *))
```

### 3. Schema Setup via Exec

Use `Container.exec` to run setup commands:

```ocaml
let* (_code, _out) = Container.exec container [
  "psql"; "-U"; "user"; "-d"; "db"; "-c"; "CREATE TABLE..."
] in
```

### 4. Mark Tests as Slow

Integration tests take time. Mark them appropriately:

```ocaml
Alcotest_lwt.test_case "my test" `Slow test_function
```

## Optimizing Test Speed

### Share Container Within Test Suite

If tests don't interfere, share one container:

```ocaml
let container_ref = ref None

let get_container () =
  match !container_ref with
  | Some c -> Lwt.return c
  | None ->
      let* c = Postgres_container.start (Postgres_container.create ()) in
      container_ref := Some c;
      Lwt.return c
```

### Use Alpine Images

Alpine-based images are smaller and start faster:

```ocaml
Postgres_container.with_image "postgres:16-alpine"
```

### Pre-pull Images

Add to CI setup:

```bash
docker pull postgres:16-alpine
```

## Next Steps

- [Wait Strategies](../core/wait-strategies.md) - Customize readiness detection
- [File Operations](../core/file-operations.md) - Copy test fixtures into containers
- [Best Practices](../advanced/best-practices.md) - Production-ready patterns
