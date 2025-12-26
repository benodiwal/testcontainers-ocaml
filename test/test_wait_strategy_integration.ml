(** Integration tests for Wait_strategy execution *)

open Lwt.Syntax
open Testcontainers

let test_wait_for_port _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "nginx:alpine"
      |> Container_request.with_exposed_port (Port.tcp 80)
      |> Container_request.with_wait_strategy
           (Wait_strategy.for_listening_port (Port.tcp 80))
    in
    Container.with_container request (fun container ->
      let* running = Container.is_running container in
      Alcotest.(check bool) "container running after port wait" true running;
      Lwt.return_unit
    )
  end

let test_wait_for_log _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd ["sh"; "-c"; "echo 'READY' && sleep 30"]
      |> Container_request.with_wait_strategy
           (Wait_strategy.for_log "READY")
    in
    Container.with_container request (fun container ->
      let* running = Container.is_running container in
      Alcotest.(check bool) "container running after log wait" true running;
      Lwt.return_unit
    )
  end

let test_wait_for_http _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "nginx:alpine"
      |> Container_request.with_exposed_port (Port.tcp 80)
      |> Container_request.with_wait_strategy
           (Wait_strategy.for_http ~port:(Port.tcp 80) "/")
    in
    Container.with_container request (fun container ->
      let* running = Container.is_running container in
      Alcotest.(check bool) "container running after http wait" true running;
      Lwt.return_unit
    )
  end

let suite =
  [
    Alcotest_lwt.test_case "wait for port" `Slow test_wait_for_port;
    Alcotest_lwt.test_case "wait for log" `Slow test_wait_for_log;
    Alcotest_lwt.test_case "wait for http" `Slow test_wait_for_http;
  ]
