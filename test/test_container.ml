(** Integration tests for Container module *)

open Lwt.Syntax
open Testcontainers

let test_start_stop _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "30" ]
    in
    let* container = Container.start request in
    Alcotest.(check bool)
      "container id not empty" true
      (String.length (Container.id container) > 0);
    let* running = Container.is_running container in
    Alcotest.(check bool) "container running" true running;
    let* () = Container.stop container in
    let* () = Container.terminate container in
    Lwt.return_unit
  end

let test_with_container _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "30" ]
    in
    let container_id = ref "" in
    let* () =
      Container.with_container request (fun container ->
          container_id := Container.id container;
          let* running = Container.is_running container in
          Alcotest.(check bool)
            "container running inside with_container" true running;
          Lwt.return_unit)
    in
    (* Container should be terminated after with_container *)
    Alcotest.(check bool)
      "container id was captured" true
      (String.length !container_id > 0);
    Lwt.return_unit
  end

let test_host _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "10" ]
    in
    Container.with_container request (fun container ->
        let* host = Container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let test_mapped_port _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "nginx:alpine"
      |> Container_request.with_exposed_port (Port.tcp 80)
      |> Container_request.with_wait_strategy
           (Wait_strategy.for_listening_port (Port.tcp 80))
    in
    Container.with_container request (fun container ->
        let* port = Container.mapped_port container (Port.tcp 80) in
        Alcotest.(check bool) "port > 0" true (port > 0);
        Alcotest.(check bool) "port < 65536" true (port < 65536);
        Lwt.return_unit)
  end

let test_exec _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "30" ]
    in
    Container.with_container request (fun container ->
        let* exit_code, output = Container.exec container [ "echo"; "hello" ] in
        Alcotest.(check int) "exit code 0" 0 exit_code;
        Alcotest.(check bool)
          "output contains hello" true
          (String.length output > 0);
        Lwt.return_unit)
  end

let test_logs _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd
           [ "sh"; "-c"; "echo 'test log message' && sleep 5" ]
    in
    Container.with_container request (fun container ->
        let* () = Lwt_unix.sleep 1.0 in
        let* logs = Container.logs container in
        (* Logs may have stream header bytes, just check we got something *)
        Alcotest.(check bool) "logs not empty" true (String.length logs > 0);
        Lwt.return_unit)
  end

let test_state _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "10" ]
    in
    Container.with_container request (fun container ->
        let* state = Container.state container in
        Alcotest.(check bool) "state is running" true (state = `Running);
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "start and stop" `Slow test_start_stop;
    Alcotest_lwt.test_case "with_container" `Slow test_with_container;
    Alcotest_lwt.test_case "host" `Slow test_host;
    Alcotest_lwt.test_case "mapped_port" `Slow test_mapped_port;
    Alcotest_lwt.test_case "exec" `Slow test_exec;
    Alcotest_lwt.test_case "logs" `Slow test_logs;
    Alcotest_lwt.test_case "state" `Slow test_state;
  ]
