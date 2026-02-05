(** Tests for Kafka container *)

open Lwt.Syntax
open Testcontainers_kafka

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let test_config _switch () =
  let config = Kafka_container.create () in
  let config = Kafka_container.with_kraft_mode true config in
  Alcotest.(check bool) "kraft mode" true config.kraft_mode;
  Lwt.return_unit

let test_container _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    Kafka_container.with_kafka (fun container servers ->
        Alcotest.(check bool)
          "servers not empty" true
          (String.length servers > 0);
        let* host = Kafka_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
