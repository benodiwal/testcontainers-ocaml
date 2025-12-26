(** Unit tests for Port module *)

open Testcontainers

let test_tcp_creation _switch () =
  let port = Port.tcp 5432 in
  Alcotest.(check int) "port number" 5432 port.port;
  Alcotest.(check string)
    "protocol" "tcp"
    (Port.protocol_to_string port.protocol);
  Lwt.return_unit

let test_udp_creation _switch () =
  let port = Port.udp 53 in
  Alcotest.(check int) "port number" 53 port.port;
  Alcotest.(check string)
    "protocol" "udp"
    (Port.protocol_to_string port.protocol);
  Lwt.return_unit

let test_to_string _switch () =
  let tcp_port = Port.tcp 80 in
  let udp_port = Port.udp 53 in
  Alcotest.(check string) "tcp port string" "80/tcp" (Port.to_string tcp_port);
  Alcotest.(check string) "udp port string" "53/udp" (Port.to_string udp_port);
  Lwt.return_unit

let test_to_docker_format _switch () =
  let port = Port.tcp 8080 in
  Alcotest.(check string)
    "docker format" "8080/tcp"
    (Port.to_docker_format port);
  Lwt.return_unit

let test_of_string _switch () =
  let port1 = Port.of_string "5432/tcp" in
  let port2 = Port.of_string "53/udp" in
  let port3 = Port.of_string "80" in
  Alcotest.(check int) "port1 number" 5432 port1.port;
  Alcotest.(check string)
    "port1 protocol" "tcp"
    (Port.protocol_to_string port1.protocol);
  Alcotest.(check int) "port2 number" 53 port2.port;
  Alcotest.(check string)
    "port2 protocol" "udp"
    (Port.protocol_to_string port2.protocol);
  Alcotest.(check int) "port3 number" 80 port3.port;
  Alcotest.(check string)
    "port3 protocol (default)" "tcp"
    (Port.protocol_to_string port3.protocol);
  Lwt.return_unit

let test_equality _switch () =
  let port1 = Port.tcp 80 in
  let port2 = Port.tcp 80 in
  let port3 = Port.tcp 8080 in
  let port4 = Port.udp 80 in
  Alcotest.(check bool) "same port equal" true (Port.equal port1 port2);
  Alcotest.(check bool) "different port number" false (Port.equal port1 port3);
  Alcotest.(check bool) "different protocol" false (Port.equal port1 port4);
  Lwt.return_unit

let test_compare _switch () =
  let port1 = Port.tcp 80 in
  let port2 = Port.tcp 443 in
  Alcotest.(check bool) "port1 < port2" true (Port.compare port1 port2 < 0);
  Alcotest.(check bool) "port2 > port1" true (Port.compare port2 port1 > 0);
  Alcotest.(check bool) "port1 = port1" true (Port.compare port1 port1 = 0);
  Lwt.return_unit

let suite =
  [
    Alcotest_lwt.test_case "tcp creation" `Quick test_tcp_creation;
    Alcotest_lwt.test_case "udp creation" `Quick test_udp_creation;
    Alcotest_lwt.test_case "to_string" `Quick test_to_string;
    Alcotest_lwt.test_case "to_docker_format" `Quick test_to_docker_format;
    Alcotest_lwt.test_case "of_string" `Quick test_of_string;
    Alcotest_lwt.test_case "equality" `Quick test_equality;
    Alcotest_lwt.test_case "compare" `Quick test_compare;
  ]
