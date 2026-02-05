(** Tests for MongoDB module *)

open Lwt.Syntax

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let string_starts_with ~prefix s =
  let plen = String.length prefix in
  String.length s >= plen && String.sub s 0 plen = prefix

let test_config _switch () =
  let config =
    Testcontainers_mongo.Mongo_container.create ()
    |> Testcontainers_mongo.Mongo_container.with_username "admin"
    |> Testcontainers_mongo.Mongo_container.with_password "secret"
  in
  Alcotest.(check string)
    "username" "admin"
    (Testcontainers_mongo.Mongo_container.username config);
  Alcotest.(check string)
    "password" "secret"
    (Testcontainers_mongo.Mongo_container.password config);
  Lwt.return_unit

let test_container _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    Testcontainers_mongo.Mongo_container.with_mongo
      ~config:(fun c ->
        c
        |> Testcontainers_mongo.Mongo_container.with_username "admin"
        |> Testcontainers_mongo.Mongo_container.with_password "secret")
      (fun container conn_str ->
        Alcotest.(check bool)
          "connection string not empty" true
          (String.length conn_str > 0);
        Alcotest.(check bool)
          "connection string contains mongodb://" true
          (string_starts_with ~prefix:"mongodb://" conn_str);
        let* host = Testcontainers_mongo.Mongo_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
