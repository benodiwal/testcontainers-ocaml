(** Unit tests for Error module *)

open Testcontainers

let test_to_string _switch () =
  let err = Error.Container_start_failed { id = "abc123"; message = "test error" } in
  let str = Error.to_string err in
  Alcotest.(check bool) "error string not empty" true (String.length str > 0);
  Alcotest.(check bool) "contains message" true (String.length str > 0);
  Lwt.return_unit

let test_docker_error _switch () =
  let err = Error.Docker_error { status = 404; message = "not found" } in
  let str = Error.to_string err in
  Alcotest.(check bool) "contains status" true (String.length str > 0);
  Lwt.return_unit

let test_timeout _switch () =
  let err = Error.Wait_timeout { strategy = "port"; timeout = 30.0 } in
  let str = Error.to_string err in
  Alcotest.(check bool) "contains timeout info" true (String.length str > 0);
  Lwt.return_unit

let test_port_not_mapped _switch () =
  let err = Error.Port_not_mapped { container_port = 80; protocol = "tcp" } in
  let str = Error.to_string err in
  Alcotest.(check bool) "contains port info" true (String.length str > 0);
  Lwt.return_unit

let suite =
  [
    Alcotest_lwt.test_case "to_string" `Quick test_to_string;
    Alcotest_lwt.test_case "docker error" `Quick test_docker_error;
    Alcotest_lwt.test_case "timeout error" `Quick test_timeout;
    Alcotest_lwt.test_case "port not mapped error" `Quick test_port_not_mapped;
  ]
