(** Generic container management *)

open Lwt.Syntax

type t = {
  id : string;
  request : Container_request.t;
  mutable info : Docker_client.container_info option;
}

let id t = t.id
let name t = match t.info with Some info -> info.name | None -> ""
let host _t = Lwt.return "127.0.0.1"

let refresh_info t =
  let* info = Docker_client.inspect_container t.id in
  t.info <- Some info;
  Lwt.return info

(* TODO: Refactor *)
let mapped_port t port =
  (* Docker needs a moment after start to populate port bindings.
     Poll up to 10 times with 100ms intervals. *)
  let port_key = Port.to_docker_format port in
  let rec poll_for_port attempts =
    let* info = refresh_info t in
    match List.assoc_opt port_key info.network_settings.ports with
    | Some (binding :: _) when binding.host_port <> "" -> (
        try Lwt.return (int_of_string binding.host_port)
        with _ ->
          if attempts > 0 then begin
            let* () = Lwt_unix.sleep 0.1 in
            poll_for_port (attempts - 1)
          end
          else
            Error.raise_error
              (Error.Port_not_mapped
                 {
                   container_port = port.Port.port;
                   protocol = Port.protocol_to_string port.protocol;
                 }))
    | _ ->
        if attempts > 0 then begin
          let* () = Lwt_unix.sleep 0.1 in
          poll_for_port (attempts - 1)
        end
        else
          Error.raise_error
            (Error.Port_not_mapped
               {
                 container_port = port.Port.port;
                 protocol = Port.protocol_to_string port.protocol;
               })
  in
  poll_for_port 10

let mapped_ports t =
  let* info = refresh_info t in
  let ports =
    List.filter_map
      (fun (port_str, bindings) ->
        match bindings with
        | [] -> None
        | binding :: _ -> (
            let container_port = Port.of_string port_str in
            try
              Some
                Port.
                  {
                    container_port;
                    host_port = int_of_string binding.Docker_client.host_port;
                    host_ip =
                      (if binding.host_ip = "" then "0.0.0.0"
                       else binding.host_ip);
                  }
            with _ -> None))
      info.network_settings.ports
  in
  Lwt.return ports

let is_running t =
  let* info = refresh_info t in
  Lwt.return info.state.running

let state t =
  let* info = refresh_info t in
  let state_str = info.state.status in
  Lwt.return
    (match state_str with
    | "created" -> `Created
    | "running" -> `Running
    | "paused" -> `Paused
    | "restarting" -> `Restarting
    | "dead" -> `Dead
    | "exited" -> `Exited
    | _ -> `Exited)

let logs ?since:_ ?(follow = false) t =
  Docker_client.container_logs ~follow t.id

let exec t cmd =
  let* exec_id = Docker_client.exec_create t.id cmd in
  let* output = Docker_client.exec_start exec_id in
  let* exit_code, _running = Docker_client.exec_inspect exec_id in
  Lwt.return (exit_code, output)

let ensure_image_exists image =
  let* exists = Docker_client.image_exists image in
  if exists then Lwt.return_unit else Docker_client.pull_image image

let start request =
  let image = Container_request.image request in
  let* () = ensure_image_exists image in
  let docker_config = Container_request.to_docker_config request in
  let* response = Docker_client.create_container docker_config in
  let container = { id = response.id; request; info = None } in
  let* () = Docker_client.start_container container.id in
  (* Execute wait strategy if present *)
  let* () =
    match Container_request.wait_strategy request with
    | None -> Lwt.return_unit
    | Some strategy ->
        let* host = host container in
        let ctx =
          Wait_strategy.
            {
              container_id = container.id;
              host;
              get_mapped_port = (fun port -> mapped_port container port);
              get_logs = (fun () -> logs container);
              exec = (fun cmd -> exec container cmd);
            }
        in
        Wait_strategy.wait ctx strategy
  in
  Lwt.return container

let stop ?(timeout = 10.0) t =
  Docker_client.stop_container ~timeout:(int_of_float timeout) t.id

let terminate t =
  let* () =
    Lwt.catch
      (fun () -> Docker_client.stop_container ~timeout:5 t.id)
      (fun _ -> Lwt.return_unit)
  in
  Docker_client.remove_container ~force:true ~volumes:true t.id

let with_container request f =
  let* container = start request in
  Lwt.finalize (fun () -> f container) (fun () -> terminate container)

(* Copy operations using Docker archive API *)

(* Create a tar archive from a file, stripping extended attributes for macOS compatibility *)
let create_tar_from_file ~src =
  let filename = Filename.basename src in
  let dir = Filename.dirname src in
  (* Use COPYFILE_DISABLE=1 to strip macOS extended attributes *)
  let cmd =
    Lwt_process.shell
      (Printf.sprintf "COPYFILE_DISABLE=1 tar -c -C %s %s" (Filename.quote dir)
         (Filename.quote filename))
  in
  Lwt_process.pread cmd

(* Create a tar archive from string content *)
let create_tar_from_content ~filename ~content =
  (* Create temp file, tar it, return tar data *)
  let tmp_dir = Filename.get_temp_dir_name () in
  let tmp_file = Filename.concat tmp_dir filename in
  let* () =
    Lwt_io.with_file ~mode:Lwt_io.Output tmp_file (fun oc ->
        Lwt_io.write oc content)
  in
  (* Strip extended attributes on macOS to avoid Docker errors *)
  let* () =
    Lwt.catch
      (fun () ->
        let xattr_cmd =
          Lwt_process.shell
            (Printf.sprintf "xattr -c %s 2>/dev/null" (Filename.quote tmp_file))
        in
        let* _ = Lwt_process.pread xattr_cmd in
        Lwt.return_unit)
      (fun _ -> Lwt.return_unit)
  in
  (* Use COPYFILE_DISABLE=1 to prevent ._* resource fork files *)
  let cmd =
    Lwt_process.shell
      (Printf.sprintf "COPYFILE_DISABLE=1 tar -c -C %s %s"
         (Filename.quote tmp_dir) (Filename.quote filename))
  in
  let* tar_data = Lwt_process.pread cmd in
  let* () = Lwt_unix.unlink tmp_file in
  Lwt.return tar_data

(* Extract a tar archive to a directory *)
let extract_tar_to_dir ~dest ~data =
  let cmd =
    Lwt_process.shell (Printf.sprintf "tar -x -C %s" (Filename.quote dest))
  in
  Lwt_process.pwrite cmd data

let copy_file_to t ~src ~dest =
  let* tar_data = create_tar_from_file ~src in
  Docker_client.put_archive t.id ~path:dest ~data:tar_data

let copy_file_from t ~src ~dest =
  let* tar_data = Docker_client.get_archive t.id ~path:src in
  let dest_dir = Filename.dirname dest in
  extract_tar_to_dir ~dest:dest_dir ~data:tar_data

let copy_content_to t ~content ~dest =
  let filename = Filename.basename dest in
  let dest_dir = Filename.dirname dest in
  let* tar_data = create_tar_from_content ~filename ~content in
  Docker_client.put_archive t.id ~path:dest_dir ~data:tar_data
