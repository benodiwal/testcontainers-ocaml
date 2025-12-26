# PostgreSQL

The PostgreSQL module provides a pre-configured container for integration testing with PostgreSQL databases.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_postgres

let test_postgres () =
  Postgres_container.with_postgres (fun container connection_string ->
    Printf.printf "PostgreSQL running at: %s\n" connection_string;
    (* Use connection_string with your database library *)
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-postgres
```

In your `dune` file:

```scheme
(libraries testcontainers-postgres)
```

## Configuration

### Basic Configuration

```ocaml
Postgres_container.with_postgres
  ~config:(fun c -> c
    |> Postgres_container.with_database "myapp"
    |> Postgres_container.with_username "appuser"
    |> Postgres_container.with_password "secret123")
  (fun container conn_str ->
    (* conn_str: postgresql://appuser:secret123@127.0.0.1:54321/myapp *)
    ...
  )
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `postgres:16-alpine` | Docker image |
| `with_database` | `test` | Database name |
| `with_username` | `test` | Username |
| `with_password` | `test` | Password |

### Custom Image

```ocaml
Postgres_container.with_postgres
  ~config:(fun c -> c
    |> Postgres_container.with_image "postgres:15"
    |> Postgres_container.with_database "legacy_db")
  (fun container conn_str -> ...)
```

## Connection Details

### Connection String

The module provides a ready-to-use connection string:

```
postgresql://username:password@host:port/database
```

### Individual Components

```ocaml
Postgres_container.with_postgres (fun container conn_str ->
  let* host = Postgres_container.host container in      (* "127.0.0.1" *)
  let* port = Postgres_container.port container in      (* 54321 *)
  let config = Postgres_container.create () in
  let database = Postgres_container.database config in  (* "test" *)
  let username = Postgres_container.username config in  (* "test" *)
  ...
)
```

### JDBC URL

For Java-compatible tools:

```ocaml
let* jdbc_url = Postgres_container.jdbc_url config container in
(* jdbc:postgresql://127.0.0.1:54321/test *)
```

## Manual Lifecycle

For more control, manage the container manually:

```ocaml
let run_tests () =
  let config =
    Postgres_container.create ()
    |> Postgres_container.with_database "testdb"
    |> Postgres_container.with_username "admin"
    |> Postgres_container.with_password "secret"
  in

  let* container = Postgres_container.start config in

  (* Get connection details *)
  let* conn_str = Postgres_container.connection_string config container in

  (* Run tests... *)

  (* Cleanup *)
  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Integration with Database Libraries

### With Caqti

```ocaml
open Lwt.Syntax
open Caqti_lwt

let test_with_caqti () =
  Postgres_container.with_postgres
    ~config:(fun c -> c
      |> Postgres_container.with_database "test"
      |> Postgres_container.with_username "test"
      |> Postgres_container.with_password "test")
    (fun _container conn_str ->
      (* Connect using Caqti *)
      let uri = Uri.of_string conn_str in
      let* connection = Caqti_lwt.connect uri in
      match connection with
      | Ok (module Db : Caqti_lwt.CONNECTION) ->
          (* Run queries *)
          let query = Caqti_request.exec Caqti_type.unit
            "CREATE TABLE test (id SERIAL PRIMARY KEY)" in
          let* result = Db.exec query () in
          (match result with
          | Ok () -> print_endline "Table created"
          | Error e -> print_endline (Caqti_error.show e));
          Lwt.return_unit
      | Error e ->
          Printf.printf "Connection failed: %s\n" (Caqti_error.show e);
          Lwt.return_unit
    )
```

### With PGX

```ocaml
open Lwt.Syntax

let test_with_pgx () =
  Postgres_container.with_postgres (fun container _conn_str ->
    let* host = Postgres_container.host container in
    let* port = Postgres_container.port container in

    let* connection = Pgx_lwt.connect
      ~host
      ~port
      ~user:"test"
      ~password:"test"
      ~database:"test"
      ()
    in

    let* result = Pgx_lwt.execute connection "SELECT 1 as value" in
    Printf.printf "Result: %s\n" (Pgx.Value.to_string (List.hd (List.hd result)));

    let* () = Pgx_lwt.close connection in
    Lwt.return_unit
  )
```

## Schema Setup

### Using Container Exec

```ocaml
let setup_schema container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "psql"; "-U"; "test"; "-d"; "test"; "-c";
    {|
      CREATE TABLE users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE posts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        title VARCHAR(255) NOT NULL,
        content TEXT,
        published_at TIMESTAMP
      );

      CREATE INDEX idx_posts_user_id ON posts(user_id);
    |}
  ] in
  if exit_code <> 0 then
    Printf.printf "Schema setup failed: %s\n" output;
  Lwt.return_unit
```

### Using File Copy

```ocaml
let setup_from_file container =
  let* () = Testcontainers.Container.copy_file_to container
    ~src:"./migrations/schema.sql"
    ~dest:"/tmp/"
  in
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "psql"; "-U"; "test"; "-d"; "test"; "-f"; "/tmp/schema.sql"
  ] in
  Lwt.return (exit_code = 0)
```

## Seeding Test Data

```ocaml
let seed_data container =
  let* (_, _) = Testcontainers.Container.exec container [
    "psql"; "-U"; "test"; "-d"; "test"; "-c";
    {|
      INSERT INTO users (email, name) VALUES
        ('alice@example.com', 'Alice'),
        ('bob@example.com', 'Bob'),
        ('charlie@example.com', 'Charlie');

      INSERT INTO posts (user_id, title, content) VALUES
        (1, 'First Post', 'Hello World'),
        (1, 'Second Post', 'More content'),
        (2, 'Bob''s Post', 'Bob writes');
    |}
  ] in
  Lwt.return_unit
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_postgres

module UserRepo = struct
  type t = string  (* connection string *)

  let create conn_str = conn_str

  let add_user t ~email ~name =
    (* In real code, use Caqti or similar *)
    ignore (t, email, name);
    Lwt.return 1

  let get_user t ~id =
    ignore (t, id);
    Lwt.return (Some ("test@example.com", "Test"))
end

let with_test_db f =
  Postgres_container.with_postgres
    ~config:(fun c -> c
      |> Postgres_container.with_database "testdb"
      |> Postgres_container.with_username "testuser"
      |> Postgres_container.with_password "testpass")
    (fun container conn_str ->
      (* Setup schema *)
      let* _ = Container.exec container [
        "psql"; "-U"; "testuser"; "-d"; "testdb"; "-c";
        "CREATE TABLE users (id SERIAL PRIMARY KEY, email TEXT, name TEXT)"
      ] in
      let repo = UserRepo.create conn_str in
      f repo
    )

let test_add_user _switch () =
  with_test_db (fun repo ->
    let* id = UserRepo.add_user repo ~email:"test@example.com" ~name:"Test" in
    Alcotest.(check bool) "id > 0" true (id > 0);
    Lwt.return_unit
  )

let test_get_user _switch () =
  with_test_db (fun repo ->
    let* _ = UserRepo.add_user repo ~email:"test@example.com" ~name:"Test" in
    let* user = UserRepo.get_user repo ~id:1 in
    Alcotest.(check bool) "user found" true (Option.is_some user);
    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "User Repository" [
      "users", [
        Alcotest_lwt.test_case "add user" `Slow test_add_user;
        Alcotest_lwt.test_case "get user" `Slow test_get_user;
      ];
    ]
  )
```

## Wait Strategy

The PostgreSQL module uses a log-based wait strategy by default:

```
database system is ready to accept connections
```

This ensures PostgreSQL is fully initialized before tests run.

## Troubleshooting

### Connection Refused

If you get connection errors immediately after container starts:

1. Ensure you're using `with_postgres` (handles waiting automatically)
2. Check the wait strategy completed successfully
3. Verify the port mapping: `Container.mapped_port container (Port.tcp 5432)`

### Authentication Failed

Check your configuration matches:

```ocaml
(* These must match *)
Postgres_container.with_username "myuser"
Postgres_container.with_password "mypass"
(* Connection: postgresql://myuser:mypass@... *)
```

### Slow Startup

PostgreSQL can take 5-15 seconds to start. If tests timeout:

```ocaml
Container_request.with_startup_timeout 60.0
```

### Database Does Not Exist

Ensure the database name in your connection matches:

```ocaml
Postgres_container.with_database "mydb"
(* Creates database "mydb" automatically *)
```
