(** Tests for Redis module *)

open Lwt.Syntax

let test_container _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    Testcontainers_redis.Redis_container.with_redis (fun container uri ->
        Alcotest.(check bool) "uri not empty" true (String.length uri > 0);
        Alcotest.(check bool)
          "uri contains redis://" true
          (Test_helpers.string_starts_with ~prefix:"redis://" uri);
        let* host = Testcontainers_redis.Redis_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite = [ Alcotest_lwt.test_case "container" `Slow test_container ]
