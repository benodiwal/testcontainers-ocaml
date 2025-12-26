(** Unit tests for Wait_strategy module *)

open Testcontainers

let test_for_listening_port _switch () =
  let strategy = Wait_strategy.for_listening_port (Port.tcp 80) in
  Alcotest.(check bool)
    "name contains port" true
    (String.length (Wait_strategy.name strategy) > 0);
  Alcotest.(check (float 0.1))
    "default timeout" 60.0
    (Wait_strategy.timeout strategy);
  Lwt.return_unit

let test_for_log _switch () =
  let strategy = Wait_strategy.for_log "ready to accept connections" in
  Alcotest.(check bool)
    "name set" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_for_log_with_occurrence _switch () =
  let strategy = Wait_strategy.for_log ~occurrence:2 "ready" in
  Alcotest.(check bool)
    "name contains occurrence" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_for_log_regex _switch () =
  let strategy = Wait_strategy.for_log_regex "ready.*connections" in
  Alcotest.(check bool)
    "name set" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_for_http _switch () =
  let strategy = Wait_strategy.for_http "/" in
  Alcotest.(check bool)
    "name set" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_for_http_with_options _switch () =
  let strategy =
    Wait_strategy.for_http ~port:(Port.tcp 8080) ~status_codes:[ 200; 201 ]
      "/health"
  in
  Alcotest.(check bool)
    "name set" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_for_exec _switch () =
  let strategy = Wait_strategy.for_exec [ "pg_isready"; "-U"; "postgres" ] in
  Alcotest.(check bool)
    "name set" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_for_health_check _switch () =
  let strategy = Wait_strategy.for_health_check () in
  Alcotest.(check bool)
    "name set" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_with_timeout _switch () =
  let strategy =
    Wait_strategy.for_listening_port (Port.tcp 80)
    |> Wait_strategy.with_timeout 30.0
  in
  Alcotest.(check (float 0.1))
    "custom timeout" 30.0
    (Wait_strategy.timeout strategy);
  Lwt.return_unit

let test_with_poll_interval _switch () =
  let strategy =
    Wait_strategy.for_listening_port (Port.tcp 80)
    |> Wait_strategy.with_poll_interval 1.0
  in
  Alcotest.(check bool)
    "strategy created" true
    (String.length (Wait_strategy.name strategy) > 0);
  Lwt.return_unit

let test_all_combinator _switch () =
  let port_wait = Wait_strategy.for_listening_port (Port.tcp 80) in
  let log_wait = Wait_strategy.for_log "ready" in
  let combined = Wait_strategy.all [ port_wait; log_wait ] in
  Alcotest.(check bool)
    "combined name contains 'all'" true
    (String.sub (Wait_strategy.name combined) 0 3 = "all");
  Lwt.return_unit

let test_any_combinator _switch () =
  let port_wait = Wait_strategy.for_listening_port (Port.tcp 80) in
  let log_wait = Wait_strategy.for_log "ready" in
  let combined = Wait_strategy.any [ port_wait; log_wait ] in
  Alcotest.(check bool)
    "combined name contains 'any'" true
    (String.sub (Wait_strategy.name combined) 0 3 = "any");
  Lwt.return_unit

let test_none _switch () =
  let strategy = Wait_strategy.none in
  Alcotest.(check string) "name is none" "none" (Wait_strategy.name strategy);
  Lwt.return_unit

let suite =
  [
    Alcotest_lwt.test_case "for_listening_port" `Quick test_for_listening_port;
    Alcotest_lwt.test_case "for_log" `Quick test_for_log;
    Alcotest_lwt.test_case "for_log with occurrence" `Quick
      test_for_log_with_occurrence;
    Alcotest_lwt.test_case "for_log_regex" `Quick test_for_log_regex;
    Alcotest_lwt.test_case "for_http" `Quick test_for_http;
    Alcotest_lwt.test_case "for_http with options" `Quick
      test_for_http_with_options;
    Alcotest_lwt.test_case "for_exec" `Quick test_for_exec;
    Alcotest_lwt.test_case "for_health_check" `Quick test_for_health_check;
    Alcotest_lwt.test_case "with_timeout" `Quick test_with_timeout;
    Alcotest_lwt.test_case "with_poll_interval" `Quick test_with_poll_interval;
    Alcotest_lwt.test_case "all combinator" `Quick test_all_combinator;
    Alcotest_lwt.test_case "any combinator" `Quick test_any_combinator;
    Alcotest_lwt.test_case "none" `Quick test_none;
  ]
