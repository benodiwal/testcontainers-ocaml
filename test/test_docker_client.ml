(** Tests for Docker_client module *)

open Lwt.Syntax
open Testcontainers

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

(* Unit tests for version comparison *)

let test_compare_versions_equal _switch () =
  Alcotest.(check int)
    "equal versions" 0
    (Docker_client.compare_versions "1.44" "1.44");
  Lwt.return_unit

let test_compare_versions_less _switch () =
  Alcotest.(check bool)
    "1.43 < 1.44" true
    (Docker_client.compare_versions "1.43" "1.44" < 0);
  Lwt.return_unit

let test_compare_versions_greater _switch () =
  Alcotest.(check bool)
    "1.48 > 1.47" true
    (Docker_client.compare_versions "1.48" "1.47" > 0);
  Lwt.return_unit

let test_compare_versions_major _switch () =
  Alcotest.(check bool)
    "2.0 > 1.99" true
    (Docker_client.compare_versions "2.0" "1.99" > 0);
  Lwt.return_unit

(* Unit tests for version negotiation logic *)

let test_negotiate_uses_daemon_version _switch () =
  (* daemon 1.46 with max 1.47 → uses 1.46 *)
  let result = Docker_client.negotiate_version "1.46" in
  Alcotest.(check string) "uses daemon version" "1.46" result;
  Lwt.return_unit

let test_negotiate_caps_at_max _switch () =
  (* daemon 1.48 with max 1.47 → uses 1.47 *)
  let result = Docker_client.negotiate_version "1.48" in
  Alcotest.(check string) "caps at max version" "1.47" result;
  Lwt.return_unit

let test_negotiate_rejects_too_old _switch () =
  (* daemon 1.23 with min 1.24 → raises error *)
  let raised =
    try
      let _ = Docker_client.negotiate_version "1.23" in
      false
    with Error.Testcontainers_error (Error.Api_version_too_old _) -> true
  in
  Alcotest.(check bool) "raises Api_version_too_old" true raised;
  Lwt.return_unit

let test_negotiate_exact_min _switch () =
  (* daemon version exactly at minimum → uses it *)
  let result = Docker_client.negotiate_version "1.24" in
  Alcotest.(check string) "uses exact min version" "1.24" result;
  Lwt.return_unit

let test_negotiate_exact_max _switch () =
  (* daemon version exactly at maximum → uses it *)
  let result = Docker_client.negotiate_version "1.47" in
  Alcotest.(check string) "uses exact max version" "1.47" result;
  Lwt.return_unit

(* Integration tests *)

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
    (* Unit tests - version negotiation *)
    Alcotest_lwt.test_case "compare_versions equal" `Quick
      test_compare_versions_equal;
    Alcotest_lwt.test_case "compare_versions less" `Quick
      test_compare_versions_less;
    Alcotest_lwt.test_case "compare_versions greater" `Quick
      test_compare_versions_greater;
    Alcotest_lwt.test_case "compare_versions major" `Quick
      test_compare_versions_major;
    Alcotest_lwt.test_case "negotiate uses daemon version" `Quick
      test_negotiate_uses_daemon_version;
    Alcotest_lwt.test_case "negotiate caps at max" `Quick
      test_negotiate_caps_at_max;
    Alcotest_lwt.test_case "negotiate rejects too old" `Quick
      test_negotiate_rejects_too_old;
    Alcotest_lwt.test_case "negotiate exact min" `Quick test_negotiate_exact_min;
    Alcotest_lwt.test_case "negotiate exact max" `Quick test_negotiate_exact_max;
    (* Integration tests *)
    Alcotest_lwt.test_case "ping" `Slow test_ping;
    Alcotest_lwt.test_case "version" `Slow test_version;
    Alcotest_lwt.test_case "image_exists" `Slow test_image_exists;
  ]
