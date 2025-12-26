# MySQL

The MySQL module provides a pre-configured container for integration testing with MySQL databases.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_mysql

let test_mysql () =
  Mysql_container.with_mysql (fun container connection_string ->
    Printf.printf "MySQL running at: %s\n" connection_string;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-mysql
```

In your `dune` file:

```scheme
(libraries testcontainers-mysql)
```

## Configuration

### Basic Configuration

```ocaml
Mysql_container.with_mysql
  ~config:(fun c -> c
    |> Mysql_container.with_database "myapp"
    |> Mysql_container.with_username "appuser"
    |> Mysql_container.with_password "secret123"
    |> Mysql_container.with_root_password "rootsecret")
  (fun container conn_str ->
    (* conn_str: mysql://appuser:secret123@127.0.0.1:33061/myapp *)
    ...
  )
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `mysql:8` | Docker image |
| `with_database` | `test` | Database name |
| `with_username` | `test` | Username |
| `with_password` | `test` | Password |
| `with_root_password` | `root` | Root password |

### Custom Image

```ocaml
Mysql_container.with_mysql
  ~config:(fun c -> c
    |> Mysql_container.with_image "mysql:5.7"
    |> Mysql_container.with_database "legacy_db")
  (fun container conn_str -> ...)
```

## Connection Details

### Connection String

```
mysql://username:password@host:port/database
```

### JDBC URL

```ocaml
let* jdbc_url = Mysql_container.jdbc_url config container in
(* jdbc:mysql://127.0.0.1:33061/test *)
```

### Individual Components

```ocaml
Mysql_container.with_mysql (fun container conn_str ->
  let* host = Mysql_container.host container in
  let* port = Mysql_container.port config container in
  let database = Mysql_container.database config in
  let username = Mysql_container.username config in
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config =
    Mysql_container.create ()
    |> Mysql_container.with_database "testdb"
    |> Mysql_container.with_username "admin"
    |> Mysql_container.with_password "secret"
    |> Mysql_container.with_root_password "rootpass"
  in

  let* container = Mysql_container.start config in
  let* conn_str = Mysql_container.connection_string config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Schema Setup

### Using mysql Client

```ocaml
let setup_schema container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "mysql"; "-u"; "test"; "-ptest"; "test"; "-e";
    {|
      CREATE TABLE users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE orders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT,
        total DECIMAL(10,2),
        status ENUM('pending', 'completed', 'cancelled'),
        FOREIGN KEY (user_id) REFERENCES users(id)
      );
    |}
  ] in
  if exit_code <> 0 then
    Printf.printf "Schema setup failed: %s\n" output;
  Lwt.return_unit
```

### Using Root User

For administrative operations:

```ocaml
let create_additional_database container db_name =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "mysql"; "-u"; "root"; "-proot"; "-e";
    Printf.sprintf "CREATE DATABASE %s;" db_name
  ] in
  Lwt.return (exit_code = 0)
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_mysql

let with_test_db f =
  Mysql_container.with_mysql
    ~config:(fun c -> c
      |> Mysql_container.with_database "shop"
      |> Mysql_container.with_username "shopuser"
      |> Mysql_container.with_password "shoppass"
      |> Mysql_container.with_root_password "rootpass")
    (fun container conn_str ->
      (* Setup schema *)
      let* _ = Container.exec container [
        "mysql"; "-u"; "shopuser"; "-pshoppass"; "shop"; "-e";
        {|
          CREATE TABLE products (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            price DECIMAL(10,2) NOT NULL
          );
        |}
      ] in
      f conn_str
    )

let test_products _switch () =
  with_test_db (fun conn_str ->
    Printf.printf "Connected to: %s\n" conn_str;
    (* Your test logic here *)
    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "MySQL Tests" [
      "products", [
        Alcotest_lwt.test_case "basic" `Slow test_products;
      ];
    ]
  )
```

## Wait Strategy

MySQL logs "ready for connections" twice during startup:
1. First for the temporary server during initialization
2. Second when actually ready

The module waits for the second occurrence:

```ocaml
Wait_strategy.for_log ~occurrence:2 "ready for connections"
```

## MySQL vs MariaDB

For MariaDB, use the same module with a different image:

```ocaml
Mysql_container.with_mysql
  ~config:(fun c -> c
    |> Mysql_container.with_image "mariadb:11")
  (fun container conn_str -> ...)
```

## Troubleshooting

### Access Denied

Ensure password is set correctly:

```ocaml
Mysql_container.with_password "mypassword"
(* Connection must use same password *)
```

### Unknown Database

The database is created automatically. Ensure names match:

```ocaml
Mysql_container.with_database "mydb"
(* Use "mydb" in connection string *)
```

### Slow Startup

MySQL 8 can take 15-30 seconds to initialize:

```ocaml
Container_request.with_startup_timeout 90.0
```

### Character Set Issues

For UTF-8 support, configure the server:

```ocaml
let request =
  Container_request.create "mysql:8"
  |> Container_request.with_cmd [
       "--character-set-server=utf8mb4";
       "--collation-server=utf8mb4_unicode_ci"
     ]
```
