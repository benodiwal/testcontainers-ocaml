(** Tests for MongoDB module *)

open Lwt.Syntax

let test_config _switch () =
  let config =
    Testcontainers_mongo.Mongo_container.create ()
    |> Testcontainers_mongo.Mongo_container.with_username "admin"
    |> Testcontainers_mongo.Mongo_container.with_password "secret"
  in
  Alcotest.(check string) "username" "admin" (Testcontainers_mongo.Mongo_container.username config);
  Alcotest.(check string) "password" "secret" (Testcontainers_mongo.Mongo_container.password config);
  Lwt.return_unit

let test_container _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    Testcontainers_mongo.Mongo_container.with_mongo
      ~config:(fun c ->
        c
        |> Testcontainers_mongo.Mongo_container.with_username "admin"
        |> Testcontainers_mongo.Mongo_container.with_password "secret")
      (fun container conn_str ->
        Alcotest.(check bool) "connection string not empty" true (String.length conn_str > 0);
        Alcotest.(check bool) "connection string contains mongodb://" true (Test_helpers.string_starts_with ~prefix:"mongodb://" conn_str);
        let* host = Testcontainers_mongo.Mongo_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
