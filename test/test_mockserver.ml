(** Tests for MockServer container *)

open Lwt.Syntax
open Testcontainers_mockserver

let test_config _switch () =
  (* Just verify we can create and configure - type is abstract *)
  let _config =
    Mockserver_container.create ()
    |> Mockserver_container.with_log_level "DEBUG"
    |> Mockserver_container.with_max_expectations 100
    |> Mockserver_container.with_image "mockserver/mockserver:latest"
  in
  Lwt.return_unit

let test_container _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    Mockserver_container.with_mockserver (fun container url ->
        Alcotest.(check bool) "url not empty" true (String.length url > 0);
        Alcotest.(check bool)
          "url starts with http" true
          (String.sub url 0 4 = "http");
        let* host = Mockserver_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
