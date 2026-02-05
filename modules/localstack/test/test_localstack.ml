(** Tests for LocalStack container *)

open Lwt.Syntax
open Testcontainers_localstack

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let test_config _switch () =
  let config = Localstack_container.create () in
  let config =
    Localstack_container.with_services [ "s3"; "sqs"; "dynamodb" ] config
  in
  let config = Localstack_container.with_region "eu-west-1" config in
  Alcotest.(check string)
    "region" "eu-west-1"
    (Localstack_container.region config);
  Lwt.return_unit

let test_container _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    Localstack_container.with_localstack
      ~config:(fun c -> Localstack_container.with_services [ "s3" ] c)
      (fun container url ->
        Alcotest.(check bool) "url not empty" true (String.length url > 0);
        Alcotest.(check bool)
          "url starts with http" true
          (String.sub url 0 4 = "http");
        let* host = Localstack_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
