(** Tests for PostgreSQL module *)

open Lwt.Syntax

let test_config _switch () =
  let config =
    Testcontainers_postgres.Postgres_container.create ()
    |> Testcontainers_postgres.Postgres_container.with_database "mydb"
    |> Testcontainers_postgres.Postgres_container.with_username "admin"
    |> Testcontainers_postgres.Postgres_container.with_password "secret"
  in
  Alcotest.(check string)
    "database" "mydb"
    (Testcontainers_postgres.Postgres_container.database config);
  Alcotest.(check string)
    "username" "admin"
    (Testcontainers_postgres.Postgres_container.username config);
  Lwt.return_unit

let test_container _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    Testcontainers_postgres.Postgres_container.with_postgres
      ~config:(fun c ->
        c
        |> Testcontainers_postgres.Postgres_container.with_database "testdb"
        |> Testcontainers_postgres.Postgres_container.with_username "testuser"
        |> Testcontainers_postgres.Postgres_container.with_password "testpass")
      (fun container conn_str ->
        Alcotest.(check bool)
          "connection string not empty" true
          (String.length conn_str > 0);
        Alcotest.(check bool)
          "connection string contains host" true
          (Test_helpers.string_starts_with ~prefix:"postgresql://" conn_str);
        let* host = Testcontainers_postgres.Postgres_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
