(** Unit tests for Container_request module *)

open Testcontainers

let test_create _switch () =
  let request = Container_request.create "nginx:alpine" in
  Alcotest.(check string) "image" "nginx:alpine" (Container_request.image request);
  Alcotest.(check int) "no exposed ports" 0 (List.length (Container_request.exposed_ports request));
  Alcotest.(check int) "no env vars" 0 (List.length (Container_request.environment request));
  Lwt.return_unit

let test_with_exposed_port _switch () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_exposed_port (Port.tcp 80)
  in
  Alcotest.(check int) "one exposed port" 1 (List.length (Container_request.exposed_ports request));
  Lwt.return_unit

let test_with_multiple_ports _switch () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_exposed_port (Port.tcp 80)
    |> Container_request.with_exposed_port (Port.tcp 443)
    |> Container_request.with_exposed_ports [Port.tcp 8080; Port.tcp 8443]
  in
  Alcotest.(check int) "four exposed ports" 4 (List.length (Container_request.exposed_ports request));
  Lwt.return_unit

let test_with_env _switch () =
  let request =
    Container_request.create "postgres:16"
    |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
    |> Container_request.with_env "POSTGRES_USER" "admin"
  in
  let env = Container_request.environment request in
  Alcotest.(check int) "two env vars" 2 (List.length env);
  Alcotest.(check bool) "password set" true (List.mem ("POSTGRES_PASSWORD", "secret") env);
  Alcotest.(check bool) "user set" true (List.mem ("POSTGRES_USER", "admin") env);
  Lwt.return_unit

let test_with_envs _switch () =
  let request =
    Container_request.create "app:latest"
    |> Container_request.with_envs [("KEY1", "val1"); ("KEY2", "val2")]
  in
  let env = Container_request.environment request in
  Alcotest.(check int) "two env vars" 2 (List.length env);
  Lwt.return_unit

let test_with_labels _switch () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_label "app" "test"
    |> Container_request.with_label "env" "ci"
    |> Container_request.with_labels [("version", "1.0"); ("team", "backend")]
  in
  let labels = Container_request.labels request in
  Alcotest.(check int) "four labels" 4 (List.length labels);
  Lwt.return_unit

let test_with_cmd _switch () =
  let request =
    Container_request.create "alpine:latest"
    |> Container_request.with_cmd ["echo"; "hello"]
  in
  Alcotest.(check bool) "cmd set" true (Option.is_some (Container_request.command request));
  Alcotest.(check (list string)) "cmd value" ["echo"; "hello"] (Option.get (Container_request.command request));
  Lwt.return_unit

let test_with_entrypoint _switch () =
  let request =
    Container_request.create "alpine:latest"
    |> Container_request.with_entrypoint ["/bin/sh"; "-c"]
  in
  Alcotest.(check bool) "entrypoint set" true (Option.is_some (Container_request.entrypoint request));
  Lwt.return_unit

let test_with_working_dir _switch () =
  let request =
    Container_request.create "alpine:latest"
    |> Container_request.with_working_dir "/app"
  in
  Alcotest.(check (option string)) "working dir" (Some "/app") (Container_request.working_dir request);
  Lwt.return_unit

let test_with_user _switch () =
  let request =
    Container_request.create "alpine:latest"
    |> Container_request.with_user "nobody"
  in
  Alcotest.(check (option string)) "user" (Some "nobody") (Container_request.user request);
  Lwt.return_unit

let test_with_privileged _switch () =
  let request =
    Container_request.create "alpine:latest"
    |> Container_request.with_privileged true
  in
  Alcotest.(check bool) "privileged" true (Container_request.privileged request);
  Lwt.return_unit

let test_with_name _switch () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_name "my-nginx"
  in
  Alcotest.(check (option string)) "name" (Some "my-nginx") (Container_request.name request);
  Lwt.return_unit

let test_with_mount _switch () =
  let mount = Volume.bind ~host:"/tmp" ~container:"/data" () in
  let request =
    Container_request.create "alpine:latest"
    |> Container_request.with_mount mount
  in
  Alcotest.(check int) "one mount" 1 (List.length (Container_request.mounts request));
  Lwt.return_unit

let test_with_startup_timeout _switch () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_startup_timeout 120.0
  in
  Alcotest.(check (float 0.1)) "timeout" 120.0 (Container_request.startup_timeout request);
  Lwt.return_unit

let test_with_auto_remove _switch () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_auto_remove true
  in
  Alcotest.(check bool) "auto_remove" true (Container_request.auto_remove request);
  Lwt.return_unit

let suite =
  [
    Alcotest_lwt.test_case "create" `Quick test_create;
    Alcotest_lwt.test_case "with_exposed_port" `Quick test_with_exposed_port;
    Alcotest_lwt.test_case "with_multiple_ports" `Quick test_with_multiple_ports;
    Alcotest_lwt.test_case "with_env" `Quick test_with_env;
    Alcotest_lwt.test_case "with_envs" `Quick test_with_envs;
    Alcotest_lwt.test_case "with_labels" `Quick test_with_labels;
    Alcotest_lwt.test_case "with_cmd" `Quick test_with_cmd;
    Alcotest_lwt.test_case "with_entrypoint" `Quick test_with_entrypoint;
    Alcotest_lwt.test_case "with_working_dir" `Quick test_with_working_dir;
    Alcotest_lwt.test_case "with_user" `Quick test_with_user;
    Alcotest_lwt.test_case "with_privileged" `Quick test_with_privileged;
    Alcotest_lwt.test_case "with_name" `Quick test_with_name;
    Alcotest_lwt.test_case "with_mount" `Quick test_with_mount;
    Alcotest_lwt.test_case "with_startup_timeout" `Quick test_with_startup_timeout;
    Alcotest_lwt.test_case "with_auto_remove" `Quick test_with_auto_remove;
  ]
