(** Example tests showing how to use testcontainers in your test suite.

    These are integration tests that require Docker to be running.
    Run with: dune runtest

    For CI, you can skip these with: dune runtest --force (when Docker unavailable)
*)

open Testcontainers

(* =============================================================================
   Unit tests (no Docker required)
   ============================================================================= *)

let test_port_creation _switch () =
  let port = Port.tcp 5432 in
  Alcotest.(check int) "port number" 5432 port.port;
  Alcotest.(check string) "port string" "5432/tcp" (Port.to_string port);
  Lwt.return_unit

let test_container_request_builder _switch () =
  let request =
    Container_request.create "postgres:16-alpine"
    |> Container_request.with_exposed_port (Port.tcp 5432)
    |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
    |> Container_request.with_label "app" "test"
  in
  Alcotest.(check string) "image" "postgres:16-alpine" (Container_request.image request);
  Alcotest.(check int) "exposed ports count" 1 (List.length (Container_request.exposed_ports request));
  Lwt.return_unit

let test_wait_strategy_creation _switch () =
  let port_wait = Wait_strategy.for_listening_port (Port.tcp 80) in
  let log_wait = Wait_strategy.for_log "ready" in
  let combined = Wait_strategy.all [port_wait; log_wait] in
  Alcotest.(check bool) "strategies created" true (Wait_strategy.name combined <> "");
  Lwt.return_unit

(* =============================================================================
   Integration tests (Docker required)

   These tests actually start containers. They are marked as `Slow to give
   users the option to skip them in quick test runs.

   To run only quick tests: dune runtest --force
   To run all tests including slow: dune runtest
   ============================================================================= *)

(* Uncomment these tests when you want to run integration tests with Docker *)

(*
let test_nginx_container _switch () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_exposed_port (Port.tcp 80)
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_listening_port (Port.tcp 80))
  in
  Container.with_container request (fun container ->
    let* host = Container.host container in
    let* port = Container.mapped_port container (Port.tcp 80) in
    Alcotest.(check string) "host" "127.0.0.1" host;
    Alcotest.(check bool) "port mapped" true (port > 0);
    Printf.printf "Nginx running at http://%s:%d\n" host port;
    Lwt.return_unit
  )

let test_postgres_container _switch () =
  Testcontainers_postgres.Postgres_container.with_postgres
    ~config:(fun c ->
      c
      |> Testcontainers_postgres.Postgres_container.with_database "testdb"
      |> Testcontainers_postgres.Postgres_container.with_username "testuser"
      |> Testcontainers_postgres.Postgres_container.with_password "testpass")
    (fun _container conn_str ->
      Printf.printf "PostgreSQL connection: %s\n" conn_str;
      Alcotest.(check bool) "connection string not empty" true (String.length conn_str > 0);
      (* Here you would connect with your PostgreSQL client library like pgx *)
      Lwt.return_unit)

let test_redis_container _switch () =
  Testcontainers_redis.Redis_container.with_redis (fun _container uri ->
    Printf.printf "Redis URI: %s\n" uri;
    Alcotest.(check bool) "uri not empty" true (String.length uri > 0);
    (* Here you would connect with your Redis client library *)
    Lwt.return_unit)
*)

(* =============================================================================
   Test runner
   ============================================================================= *)

let () =
  Lwt_main.run
    (Alcotest_lwt.run "Testcontainers"
       [
         ( "unit",
           [
             Alcotest_lwt.test_case "port creation" `Quick test_port_creation;
             Alcotest_lwt.test_case "container request builder" `Quick test_container_request_builder;
             Alcotest_lwt.test_case "wait strategy creation" `Quick test_wait_strategy_creation;
           ] );
         (* Uncomment to run integration tests:
         ( "integration",
           [
             Alcotest_lwt.test_case "nginx container" `Slow test_nginx_container;
             Alcotest_lwt.test_case "postgres container" `Slow test_postgres_container;
             Alcotest_lwt.test_case "redis container" `Slow test_redis_container;
           ] );
         *)
       ])
