(** Unit tests for Volume module *)

open Testcontainers

let test_bind_mount _switch () =
  let mount = Volume.bind ~host:"/host/path" ~container:"/container/path" () in
  Alcotest.(check string) "docker format" "/host/path:/container/path:rw" (Volume.to_docker_bind_format mount);
  Lwt.return_unit

let test_bind_mount_readonly _switch () =
  let mount = Volume.bind ~mode:Volume.ReadOnly ~host:"/host/path" ~container:"/container/path" () in
  Alcotest.(check string) "docker format readonly" "/host/path:/container/path:ro" (Volume.to_docker_bind_format mount);
  Lwt.return_unit

let test_tmpfs_mount _switch () =
  let mount = Volume.tmpfs ~container:"/tmp/data" () in
  Alcotest.(check string) "container path" "/tmp/data" (Volume.container_path mount);
  Lwt.return_unit

let test_named_volume _switch () =
  let mount = Volume.volume ~name:"myvolume" ~container:"/data" () in
  Alcotest.(check string) "docker format" "myvolume:/data:rw" (Volume.to_docker_bind_format mount);
  Lwt.return_unit

let suite =
  [
    Alcotest_lwt.test_case "bind mount" `Quick test_bind_mount;
    Alcotest_lwt.test_case "bind mount readonly" `Quick test_bind_mount_readonly;
    Alcotest_lwt.test_case "tmpfs mount" `Quick test_tmpfs_mount;
    Alcotest_lwt.test_case "named volume" `Quick test_named_volume;
  ]
