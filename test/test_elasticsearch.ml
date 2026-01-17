(** Tests for Elasticsearch container *)

open Lwt.Syntax
open Testcontainers_elasticsearch

let test_config _switch () =
  let config = Elasticsearch_container.create () in
  let config = Elasticsearch_container.with_security_enabled false config in
  Alcotest.(check bool) "security disabled" false config.security_enabled;
  Lwt.return_unit

let test_container _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    Elasticsearch_container.with_elasticsearch (fun container url ->
        Alcotest.(check bool) "url not empty" true (String.length url > 0);
        Alcotest.(check bool)
          "url starts with http" true
          (String.sub url 0 4 = "http");
        let* host = Elasticsearch_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
