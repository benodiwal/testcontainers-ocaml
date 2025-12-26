# MongoDB

The MongoDB module provides a pre-configured container for integration testing with MongoDB.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_mongo

let test_mongo () =
  Mongo_container.with_mongo (fun container connection_string ->
    Printf.printf "MongoDB running at: %s\n" connection_string;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-mongo
```

In your `dune` file:

```scheme
(libraries testcontainers-mongo)
```

## Configuration

### Without Authentication (Default)

```ocaml
(* Simple setup - no auth required *)
Mongo_container.with_mongo (fun container conn_str ->
  (* conn_str: mongodb://127.0.0.1:27017 *)
  ...
)
```

### With Authentication

```ocaml
Mongo_container.with_mongo
  ~config:(fun c -> c
    |> Mongo_container.with_username "admin"
    |> Mongo_container.with_password "secret123")
  (fun container conn_str ->
    (* conn_str: mongodb://admin:secret123@127.0.0.1:27017 *)
    ...
  )
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `mongo:7` | Docker image |
| `with_username` | None | Admin username (optional) |
| `with_password` | None | Admin password (optional) |

### Custom Image

```ocaml
Mongo_container.with_mongo
  ~config:(fun c -> c
    |> Mongo_container.with_image "mongo:6")
  (fun container conn_str -> ...)
```

## Connection Details

### Connection String

Without auth:
```
mongodb://127.0.0.1:27017
```

With auth:
```
mongodb://username:password@127.0.0.1:27017
```

### Individual Components

```ocaml
Mongo_container.with_mongo (fun container conn_str ->
  let* host = Mongo_container.host container in
  let* port = Mongo_container.port config container in
  let username = Mongo_container.username config in
  let password = Mongo_container.password config in
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config =
    Mongo_container.create ()
    |> Mongo_container.with_username "admin"
    |> Mongo_container.with_password "secret"
  in

  let* container = Mongo_container.start config in
  let* conn_str = Mongo_container.connection_string config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Using with MongoDB Libraries

### With mongo (OCaml MongoDB driver)

```ocaml
open Lwt.Syntax

let test_with_mongo_driver () =
  Mongo_container.with_mongo (fun container conn_str ->
    (* Parse connection string or use components *)
    let* host = Mongo_container.host container in
    let* port = Mongo_container.port (Mongo_container.create ()) container in

    (* Connect using your MongoDB library *)
    (* Example with a hypothetical OCaml MongoDB client:
       let* client = Mongo.connect ~host ~port () in
       let db = Mongo.database client "testdb" in
       let collection = Mongo.collection db "users" in
       ...
    *)

    Printf.printf "Connected to MongoDB at %s:%d\n" host port;
    Lwt.return_unit
  )
```

## Data Setup Using mongosh

### Create Collections and Indexes

```ocaml
let setup_database container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "mongosh"; "--eval"; {|
      use testdb;

      db.createCollection("users");
      db.users.createIndex({ email: 1 }, { unique: true });

      db.createCollection("posts");
      db.posts.createIndex({ userId: 1 });
      db.posts.createIndex({ createdAt: -1 });
    |}
  ] in
  if exit_code <> 0 then
    Printf.printf "Setup failed: %s\n" output;
  Lwt.return_unit
```

### Insert Test Data

```ocaml
let seed_data container =
  let* (_, _) = Testcontainers.Container.exec container [
    "mongosh"; "--eval"; {|
      use testdb;

      db.users.insertMany([
        { email: "alice@example.com", name: "Alice", age: 30 },
        { email: "bob@example.com", name: "Bob", age: 25 },
        { email: "charlie@example.com", name: "Charlie", age: 35 }
      ]);

      db.posts.insertMany([
        { userId: "alice", title: "First Post", content: "Hello!" },
        { userId: "bob", title: "Bob's Post", content: "Hi there!" }
      ]);
    |}
  ] in
  Lwt.return_unit
```

### Verify Data

```ocaml
let verify_data container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "mongosh"; "--quiet"; "--eval"; {|
      use testdb;
      JSON.stringify(db.users.find().toArray());
    |}
  ] in
  Printf.printf "Users: %s\n" output;
  Lwt.return (exit_code = 0)
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_mongo

let with_test_mongo f =
  Mongo_container.with_mongo
    ~config:(fun c -> c
      |> Mongo_container.with_username "testadmin"
      |> Mongo_container.with_password "testpass")
    (fun container conn_str ->
      (* Setup initial data *)
      let* _ = Container.exec container [
        "mongosh"; "-u"; "testadmin"; "-p"; "testpass";
        "--authenticationDatabase"; "admin"; "--eval";
        {|
          use appdb;
          db.items.insertOne({ name: "Test Item", price: 9.99 });
        |}
      ] in
      f container conn_str
    )

let test_find_items _switch () =
  with_test_mongo (fun container _conn_str ->
    let* (exit_code, output) = Container.exec container [
      "mongosh"; "-u"; "testadmin"; "-p"; "testpass";
      "--authenticationDatabase"; "admin"; "--quiet"; "--eval";
      {| use appdb; db.items.countDocuments(); |}
    ] in
    Alcotest.(check int) "exit code" 0 exit_code;
    Alcotest.(check bool) "has output" true (String.length output > 0);
    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "MongoDB Tests" [
      "items", [
        Alcotest_lwt.test_case "find items" `Slow test_find_items;
      ];
    ]
  )
```

## Wait Strategy

The MongoDB module waits for:

```
Waiting for connections
```

This indicates MongoDB is ready to accept client connections.

## Replica Sets

For testing replica set features:

```ocaml
let setup_replica_set () =
  let request =
    Container_request.create "mongo:7"
    |> Container_request.with_cmd ["--replSet"; "rs0"]
    |> Container_request.with_exposed_port (Port.tcp 27017)
  in

  Container.with_container request (fun container ->
    (* Initialize replica set *)
    let* _ = Container.exec container [
      "mongosh"; "--eval"; "rs.initiate()"
    ] in
    (* Wait for replica set to be ready *)
    let* () = Lwt_unix.sleep 5.0 in
    (* Now use the replica set *)
    Lwt.return_unit
  )
```

## Troubleshooting

### Authentication Failed

When using authentication:

```ocaml
(* Both username and password must be set *)
Mongo_container.with_username "admin"
|> Mongo_container.with_password "secret"

(* Connection string must include credentials *)
(* mongodb://admin:secret@127.0.0.1:27017 *)
```

### Connection Refused

Ensure the container is fully started:

```ocaml
(* Use with_mongo which handles waiting *)
Mongo_container.with_mongo (fun container conn_str ->
  (* Safe to connect here *)
  ...
)
```

### mongosh Not Found

Older MongoDB images use `mongo` instead of `mongosh`:

```ocaml
(* For MongoDB < 6.0 *)
Container.exec container ["mongo"; "--eval"; "..."]

(* For MongoDB >= 6.0 *)
Container.exec container ["mongosh"; "--eval"; "..."]
```

### Slow Startup

MongoDB typically starts in 5-10 seconds, but can be slower:

```ocaml
Container_request.with_startup_timeout 60.0
```
