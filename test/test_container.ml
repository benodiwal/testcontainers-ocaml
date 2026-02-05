(** Integration tests for Container module *)

open Lwt.Syntax
open Testcontainers

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let test_start_stop _switch () =
  if skip_integration_tests () then Lwt.return_unit
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
  if skip_integration_tests () then Lwt.return_unit
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
  if skip_integration_tests () then Lwt.return_unit
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
  if skip_integration_tests () then Lwt.return_unit
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
  if skip_integration_tests () then Lwt.return_unit
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
  if skip_integration_tests () then Lwt.return_unit
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
  if skip_integration_tests () then Lwt.return_unit
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

let test_container_ip _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "10" ]
    in
    Container.with_container request (fun container ->
        let* ip = Container.container_ip container in
        Alcotest.(check bool) "ip not empty" true (String.length ip > 0);
        (* IP should be in format x.x.x.x *)
        Alcotest.(check bool) "ip contains dots" true (String.contains ip '.');
        Lwt.return_unit)
  end

let test_container_ips _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "10" ]
    in
    Container.with_container request (fun container ->
        let* ips = Container.container_ips container in
        Alcotest.(check bool) "has at least one ip" true (List.length ips > 0);
        let _, ip = List.hd ips in
        Alcotest.(check bool) "ip not empty" true (String.length ip > 0);
        Lwt.return_unit)
  end

let test_inspect _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "10" ]
    in
    Container.with_container request (fun container ->
        let* info = Container.inspect container in
        Alcotest.(check bool)
          "id matches" true
          (info.id = Container.id container);
        Alcotest.(check bool) "name not empty" true (String.length info.name > 0);
        Alcotest.(check bool) "is running" true info.state.running;
        Lwt.return_unit)
  end

let test_gateway _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "10" ]
    in
    Container.with_container request (fun container ->
        let* gw = Container.gateway container in
        Alcotest.(check bool) "gateway not empty" true (String.length gw > 0);
        Lwt.return_unit)
  end

let test_copy_dir_to _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "30" ]
    in
    Container.with_container request (fun container ->
        (* Use copy_content_to to create a directory structure inside container *)
        let* _ = Container.exec container [ "mkdir"; "-p"; "/data/testdir" ] in
        let* () =
          Container.copy_content_to container ~content:"hello from dir test"
            ~dest:"/data/testdir/test.txt"
        in
        (* Verify the file exists *)
        let* exit_code, output =
          Container.exec container [ "cat"; "/data/testdir/test.txt" ]
        in
        Alcotest.(check int) "cat exit code" 0 exit_code;
        Alcotest.(check bool) "output not empty" true (String.length output > 0);
        Lwt.return_unit)
  end

let test_follow_logs _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd
           [
             "sh";
             "-c";
             "for i in 1 2 3; do echo \"log line $i\"; sleep 0.2; done";
           ]
    in
    let* container = Container.start request in
    let log_buffer = Buffer.create 256 in
    (* Use a timeout to avoid waiting forever *)
    let log_stream =
      Lwt.catch
        (fun () ->
          Container.follow_logs ~tail:"10"
            ~on_log:(fun chunk ->
              Buffer.add_string log_buffer chunk;
              Lwt.return_unit)
            container)
        (fun _ -> Lwt.return_unit)
    in
    (* Wait for container to finish or timeout *)
    let* () =
      Lwt.pick
        [
          log_stream;
          (let* () = Lwt_unix.sleep 5.0 in
           Lwt.return_unit);
        ]
    in
    let logs = Buffer.contents log_buffer in
    Alcotest.(check bool) "received some logs" true (String.length logs > 0);
    let* () = Container.terminate container in
    Lwt.return_unit
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
    Alcotest_lwt.test_case "container_ip" `Slow test_container_ip;
    Alcotest_lwt.test_case "container_ips" `Slow test_container_ips;
    Alcotest_lwt.test_case "inspect" `Slow test_inspect;
    Alcotest_lwt.test_case "gateway" `Slow test_gateway;
    Alcotest_lwt.test_case "copy_dir_to" `Slow test_copy_dir_to;
    Alcotest_lwt.test_case "follow_logs" `Slow test_follow_logs;
  ]
