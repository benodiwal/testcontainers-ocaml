(** PostgreSQL example: Running PostgreSQL for integration tests *)

open Lwt.Syntax
open Testcontainers_postgres

let () =
  Lwt_main.run begin
    Printf.printf "Starting PostgreSQL container...\n%!";

    (* Method 1: Using with_postgres helper (recommended) *)
    Postgres_container.with_postgres
      ~config:(fun c ->
        c
        |> Postgres_container.with_database "myapp_test"
        |> Postgres_container.with_username "testuser"
        |> Postgres_container.with_password "testpass")
      (fun container conn_str ->
        Printf.printf "PostgreSQL is ready!\n%!";
        Printf.printf "Connection string: %s\n%!" conn_str;

        (* Get individual connection details *)
        let* host = Postgres_container.host container in
        let config = Postgres_container.create ()
          |> Postgres_container.with_database "myapp_test" in
        let* port = Postgres_container.port config container in

        Printf.printf "Host: %s\n%!" host;
        Printf.printf "Port: %d\n%!" port;
        Printf.printf "Database: %s\n%!" (Postgres_container.database config);
        Printf.printf "Username: %s\n%!" (Postgres_container.username config);

        (* Here you would use your PostgreSQL client library:
           - pgx: https://github.com/arenadotio/pgx
           - postgresql-ocaml: https://github.com/mmottl/postgresql-ocaml

           Example with pgx:
           let* conn = Pgx_lwt.connect ~conninfo:conn_str () in
           let* result = Pgx_lwt.execute conn "SELECT 1" in
           ...
        *)

        Printf.printf "Running database tests...\n%!";
        Lwt_unix.sleep 1.0
      )
  end;
  Printf.printf "PostgreSQL container cleaned up.\n"

(* Method 2: Manual lifecycle control *)
let _manual_example () =
  Lwt_main.run begin
    let config =
      Postgres_container.create ()
      |> Postgres_container.with_database "manual_test"
      |> Postgres_container.with_username "admin"
      |> Postgres_container.with_password "secret123"
    in

    let* container = Postgres_container.start config in
    let* conn_str = Postgres_container.connection_string config container in

    Printf.printf "Manual control - Connection: %s\n%!" conn_str;

    (* Do your tests... *)

    (* IMPORTANT: Always clean up manually when not using with_postgres *)
    Testcontainers.Container.terminate container
  end
