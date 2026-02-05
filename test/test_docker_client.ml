(** Integration tests for Docker_client module *)

open Lwt.Syntax
open Testcontainers

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let test_ping _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let* result = Docker_client.ping () in
    Alcotest.(check bool) "docker ping" true result;
    Lwt.return_unit
  end

let test_version _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let* version, api_version = Docker_client.version () in
    Alcotest.(check bool) "version not empty" true (String.length version > 0);
    Alcotest.(check bool)
      "api version not empty" true
      (String.length api_version > 0);
    Lwt.return_unit
  end

let test_image_exists _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let* exists = Docker_client.image_exists "alpine:latest" in
    (* May or may not exist, just check it doesn't crash *)
    ignore exists;
    Lwt.return_unit
  end

let suite =
  [
    Alcotest_lwt.test_case "ping" `Slow test_ping;
    Alcotest_lwt.test_case "version" `Slow test_version;
    Alcotest_lwt.test_case "image_exists" `Slow test_image_exists;
  ]
