(** Tests for Memcached container *)

open Lwt.Syntax
open Testcontainers_memcached

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let test_config _switch () =
  let config = Memcached_container.create () in
  let config = Memcached_container.with_memory_mb 128 config in
  Alcotest.(check int) "memory" 128 config.memory_mb;
  Lwt.return_unit

let test_container _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    Memcached_container.with_memcached (fun container conn ->
        Alcotest.(check bool) "conn not empty" true (String.length conn > 0);
        let* host = Memcached_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
