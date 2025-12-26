(** Docker API client abstraction layer.

    This module provides an abstraction over Docker API communication. Uses
    direct Unix socket connection via Lwt_unix. Designed to be swappable for
    future Eio implementation. *)

open Lwt.Syntax

let docker_socket = "/var/run/docker.sock"
let api_version = "v1.43"

module Json = struct
  let get_string key json =
    match json with
    | `Assoc lst -> (
        match List.assoc_opt key lst with
        | Some (`String s) -> Some s
        | _ -> None)
    | _ -> None

  let get_string_exn key json =
    match get_string key json with
    | Some s -> s
    | None -> failwith (Printf.sprintf "Missing key: %s" key)

  let get_int key json =
    match json with
    | `Assoc lst -> (
        match List.assoc_opt key lst with Some (`Int i) -> Some i | _ -> None)
    | _ -> None

  let get_bool key json =
    match json with
    | `Assoc lst -> (
        match List.assoc_opt key lst with Some (`Bool b) -> Some b | _ -> None)
    | _ -> None

  let get_list key json =
    match json with
    | `Assoc lst -> (
        match List.assoc_opt key lst with Some (`List l) -> Some l | _ -> None)
    | _ -> None

  let get_assoc key json =
    match json with
    | `Assoc lst -> (
        match List.assoc_opt key lst with
        | Some (`Assoc a) -> Some (`Assoc a)
        | _ -> None)
    | _ -> None
end

type container_config = {
  image : string;
  cmd : string list option;
  entrypoint : string list option;
  env : string list;
  exposed_ports : string list;
  host_config : host_config;
  labels : (string * string) list;
  working_dir : string option;
  user : string option;
  attach_stdout : bool;
  attach_stderr : bool;
  tty : bool;
}

and host_config = {
  binds : string list;
  port_bindings : (string * port_binding list) list;
  publish_all_ports : bool;
  privileged : bool;
  auto_remove : bool;
  network_mode : string option;
}

and port_binding = { host_ip : string; host_port : string }

type container_state = { status : string; running : bool; exit_code : int }

type container_info = {
  id : string;
  name : string;
  state : container_state;
  network_settings : network_settings;
}

and network_settings = {
  ports : (string * port_binding list) list;
  ip_address : string;
  gateway : string;
}

type create_response = { id : string; warnings : string list }

let connect_to_docker () =
  let sock = Lwt_unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  let addr = Unix.ADDR_UNIX docker_socket in
  let* () = Lwt_unix.connect sock addr in
  Lwt.return sock

let read_http_response ic =
  (* Read status line *)
  let* status_line = Lwt_io.read_line ic in
  let status_code =
    try
      let parts = String.split_on_char ' ' status_line in
      int_of_string (List.nth parts 1)
    with _ -> 500
  in
  (* Read headers *)
  let rec read_headers acc =
    let* line = Lwt_io.read_line ic in
    let line = String.trim line in
    if line = "" then Lwt.return acc else read_headers (line :: acc)
  in
  let* headers = read_headers [] in
  (* Find content-length or transfer-encoding *)
  let content_length =
    List.find_map
      (fun h ->
        let h_lower = String.lowercase_ascii h in
        if
          String.length h_lower > 15
          && String.sub h_lower 0 14 = "content-length"
        then
          let colon_pos = String.index h ':' in
          let value =
            String.trim
              (String.sub h (colon_pos + 1) (String.length h - colon_pos - 1))
          in
          Some (int_of_string value)
        else None)
      headers
  in
  let chunked =
    List.exists
      (fun h ->
        let h_lower = String.lowercase_ascii h in
        String.length h_lower > 17
        && String.sub h_lower 0 17 = "transfer-encoding"
        && String.contains h_lower 'c')
      headers
  in
  (* Read body *)
  let* body =
    match content_length with
    | Some len when len > 0 ->
        let buf = Bytes.create len in
        let* _ = Lwt_io.read_into_exactly ic buf 0 len in
        Lwt.return (Bytes.to_string buf)
    | Some _ -> Lwt.return ""
    | None when chunked ->
        let rec read_chunks acc =
          let* size_line = Lwt_io.read_line ic in
          let size_line = String.trim size_line in
          let size = try int_of_string ("0x" ^ size_line) with _ -> 0 in
          if size = 0 then Lwt.return (String.concat "" (List.rev acc))
          else begin
            let buf = Bytes.create size in
            let* _ = Lwt_io.read_into_exactly ic buf 0 size in
            let* _ = Lwt_io.read_line ic in
            read_chunks (Bytes.to_string buf :: acc)
          end
        in
        read_chunks []
    | None ->
        (* No Content-Length and not chunked - read until EOF (for streaming responses) *)
        let rec read_all acc =
          Lwt.catch
            (fun () ->
              let buf = Bytes.create 4096 in
              let* n = Lwt_io.read_into ic buf 0 4096 in
              if n = 0 then Lwt.return (String.concat "" (List.rev acc))
              else read_all (Bytes.sub_string buf 0 n :: acc))
            (fun _ -> Lwt.return (String.concat "" (List.rev acc)))
        in
        read_all []
  in
  Lwt.return (status_code, body)

let make_request meth path ?body () =
  let* sock = connect_to_docker () in
  let meth_str =
    match meth with
    | `GET -> "GET"
    | `POST -> "POST"
    | `DELETE -> "DELETE"
    | `PUT -> "PUT"
    | `HEAD -> "HEAD"
  in
  let full_path = Printf.sprintf "/%s%s" api_version path in
  let content_length =
    match body with Some b -> String.length b | None -> 0
  in
  let request =
    Printf.sprintf
      "%s %s HTTP/1.1\r\n\
       Host: localhost\r\n\
       Content-Type: application/json\r\n\
       Content-Length: %d\r\n\
       Connection: close\r\n\
       \r\n\
       %s"
      meth_str full_path content_length
      (Option.value body ~default:"")
  in
  let ic = Lwt_io.of_fd ~close:(fun _ -> Lwt.return_unit) ~mode:Lwt_io.Input sock in
  let oc = Lwt_io.of_fd ~close:(fun _ -> Lwt.return_unit) ~mode:Lwt_io.Output sock in
  Lwt.finalize
    (fun () ->
      let* () = Lwt_io.write oc request in
      let* () = Lwt_io.flush oc in
      read_http_response ic)
    (fun () ->
      let* () = Lwt_io.close oc in
      let* () = Lwt_io.close ic in
      Lwt_unix.close sock)

let handle_response (status, body) =
  if status >= 200 && status < 300 then Lwt.return body
  else
    let message =
      try
        let json = Yojson.Safe.from_string body in
        Json.get_string "message" json |> Option.value ~default:body
      with _ -> body
    in
    Error.fail_docker_error ~status ~message

let config_to_json config =
  let exposed_ports =
    List.map (fun p -> (p, `Assoc [])) config.exposed_ports |> fun lst ->
    `Assoc lst
  in
  let port_bindings =
    List.map
      (fun (port, bindings) ->
        let bindings_json =
          List.map
            (fun b ->
              `Assoc
                [
                  ("HostIp", `String b.host_ip);
                  ("HostPort", `String b.host_port);
                ])
            bindings
        in
        (port, `List bindings_json))
      config.host_config.port_bindings
    |> fun lst -> `Assoc lst
  in
  let host_config =
    `Assoc
      [
        ("Binds", `List (List.map (fun s -> `String s) config.host_config.binds));
        ("PortBindings", port_bindings);
        ("PublishAllPorts", `Bool config.host_config.publish_all_ports);
        ("Privileged", `Bool config.host_config.privileged);
        ("AutoRemove", `Bool config.host_config.auto_remove);
      ]
  in
  let base =
    [
      ("Image", `String config.image);
      ("Env", `List (List.map (fun s -> `String s) config.env));
      ("ExposedPorts", exposed_ports);
      ("HostConfig", host_config);
      ("Labels", `Assoc (List.map (fun (k, v) -> (k, `String v)) config.labels));
      ("AttachStdout", `Bool config.attach_stdout);
      ("AttachStderr", `Bool config.attach_stderr);
      ("Tty", `Bool config.tty);
    ]
  in
  let base =
    match config.cmd with
    | Some cmd -> ("Cmd", `List (List.map (fun s -> `String s) cmd)) :: base
    | None -> base
  in
  let base =
    match config.entrypoint with
    | Some ep ->
        ("Entrypoint", `List (List.map (fun s -> `String s) ep)) :: base
    | None -> base
  in
  let base =
    match config.working_dir with
    | Some wd -> ("WorkingDir", `String wd) :: base
    | None -> base
  in
  let base =
    match config.user with
    | Some u -> ("User", `String u) :: base
    | None -> base
  in
  `Assoc base

let parse_create_response body_str =
  let json = Yojson.Safe.from_string body_str in
  let id = Json.get_string_exn "Id" json in
  let warnings =
    match Json.get_list "Warnings" json with
    | Some lst ->
        List.filter_map (function `String s -> Some s | _ -> None) lst
    | None -> []
  in
  { id; warnings }

let parse_port_bindings json =
  match json with
  | `Assoc lst ->
      List.filter_map
        (fun (port, bindings) ->
          match bindings with
          | `List bl ->
              let parsed_bindings =
                List.filter_map
                  (fun b ->
                    match b with
                    | `Assoc _ ->
                        let host_ip =
                          Json.get_string "HostIp" b |> Option.value ~default:""
                        in
                        let host_port =
                          Json.get_string "HostPort" b
                          |> Option.value ~default:""
                        in
                        Some { host_ip; host_port }
                    | _ -> None)
                  bl
              in
              Some (port, parsed_bindings)
          | `Null -> None
          | _ -> None)
        lst
  | _ -> []

let parse_container_info body_str =
  let json = Yojson.Safe.from_string body_str in
  let id = Json.get_string_exn "Id" json in
  let name =
    Json.get_string "Name" json |> Option.value ~default:"" |> fun s ->
    if String.length s > 0 && s.[0] = '/' then
      String.sub s 1 (String.length s - 1)
    else s
  in
  let state_json =
    Json.get_assoc "State" json |> Option.value ~default:(`Assoc [])
  in
  let state =
    {
      status =
        Json.get_string "Status" state_json |> Option.value ~default:"unknown";
      running =
        Json.get_bool "Running" state_json |> Option.value ~default:false;
      exit_code = Json.get_int "ExitCode" state_json |> Option.value ~default:0;
    }
  in
  let network_json =
    Json.get_assoc "NetworkSettings" json |> Option.value ~default:(`Assoc [])
  in
  let ports_json =
    Json.get_assoc "Ports" network_json |> Option.value ~default:(`Assoc [])
  in
  let network_settings =
    {
      ports = parse_port_bindings ports_json;
      ip_address =
        Json.get_string "IPAddress" network_json |> Option.value ~default:"";
      gateway =
        Json.get_string "Gateway" network_json |> Option.value ~default:"";
    }
  in
  { id; name; state; network_settings }

let create_container config =
  let body = Yojson.Safe.to_string (config_to_json config) in
  let* resp = make_request `POST "/containers/create" ~body () in
  let* body_str = handle_response resp in
  Lwt.return (parse_create_response body_str)

let start_container id =
  let path = Printf.sprintf "/containers/%s/start" id in
  let* resp = make_request `POST path () in
  let* _ = handle_response resp in
  Lwt.return_unit

let stop_container ?(timeout = 10) id =
  let path = Printf.sprintf "/containers/%s/stop?t=%d" id timeout in
  let* resp = make_request `POST path () in
  let* _ = handle_response resp in
  Lwt.return_unit

let remove_container ?(force = false) ?(volumes = false) id =
  let path = Printf.sprintf "/containers/%s?force=%b&v=%b" id force volumes in
  let* resp = make_request `DELETE path () in
  let* _ = handle_response resp in
  Lwt.return_unit

let inspect_container id =
  let path = Printf.sprintf "/containers/%s/json" id in
  let* resp = make_request `GET path () in
  let* body_str = handle_response resp in
  Lwt.return (parse_container_info body_str)

let container_logs ?(stdout = true) ?(stderr = true) ?(follow = false)
    ?(tail = "all") id =
  let path =
    Printf.sprintf "/containers/%s/logs?stdout=%b&stderr=%b&follow=%b&tail=%s"
      id stdout stderr follow tail
  in
  let* resp = make_request `GET path () in
  handle_response resp

let wait_container id =
  let path = Printf.sprintf "/containers/%s/wait" id in
  let* resp = make_request `POST path () in
  let* body_str = handle_response resp in
  let json = Yojson.Safe.from_string body_str in
  let exit_code =
    Json.get_int "StatusCode" json |> Option.value ~default:(-1)
  in
  Lwt.return exit_code

let exec_create id cmd =
  let path = Printf.sprintf "/containers/%s/exec" id in
  let body =
    Yojson.Safe.to_string
      (`Assoc
         [
           ("AttachStdout", `Bool true);
           ("AttachStderr", `Bool true);
           ("Cmd", `List (List.map (fun s -> `String s) cmd));
         ])
  in
  let* resp = make_request `POST path ~body () in
  let* body_str = handle_response resp in
  let json = Yojson.Safe.from_string body_str in
  Lwt.return (Json.get_string_exn "Id" json)

let exec_start exec_id =
  let path = Printf.sprintf "/exec/%s/start" exec_id in
  let body =
    Yojson.Safe.to_string
      (`Assoc [ ("Detach", `Bool false); ("Tty", `Bool false) ])
  in
  let* resp = make_request `POST path ~body () in
  handle_response resp

let exec_inspect exec_id =
  let path = Printf.sprintf "/exec/%s/json" exec_id in
  let* resp = make_request `GET path () in
  let* body_str = handle_response resp in
  let json = Yojson.Safe.from_string body_str in
  let exit_code = Json.get_int "ExitCode" json |> Option.value ~default:(-1) in
  let running = Json.get_bool "Running" json |> Option.value ~default:false in
  Lwt.return (exit_code, running)

let pull_image image =
  let path =
    Printf.sprintf "/images/create?fromImage=%s" (Uri.pct_encode image)
  in
  let* resp = make_request `POST path () in
  let* _ = handle_response resp in
  Lwt.return_unit

let image_exists image =
  let path = Printf.sprintf "/images/%s/json" (Uri.pct_encode image) in
  let* status, _body = make_request `GET path () in
  Lwt.return (status >= 200 && status < 300)

let ping () =
  let* resp = make_request `GET "/_ping" () in
  let* body_str = handle_response resp in
  Lwt.return (body_str = "OK")

let version () =
  let* resp = make_request `GET "/version" () in
  let* body_str = handle_response resp in
  let json = Yojson.Safe.from_string body_str in
  let version =
    Json.get_string "Version" json |> Option.value ~default:"unknown"
  in
  let api_version =
    Json.get_string "ApiVersion" json |> Option.value ~default:"unknown"
  in
  Lwt.return (version, api_version)

(* Archive operations for file copy *)
let put_archive id ~path ~data =
  let encoded_path = Uri.pct_encode path in
  let api_path =
    Printf.sprintf "/containers/%s/archive?path=%s" id encoded_path
  in
  let* sock = connect_to_docker () in
  let full_path = Printf.sprintf "/%s%s" api_version api_path in
  let content_length = String.length data in
  let header =
    Printf.sprintf
      "PUT %s HTTP/1.1\r\n\
       Host: localhost\r\n\
       Content-Type: application/x-tar\r\n\
       Content-Length: %d\r\n\
       Connection: close\r\n\
       \r\n"
      full_path content_length
  in
  let request = header ^ data in
  let ic = Lwt_io.of_fd ~close:(fun _ -> Lwt.return_unit) ~mode:Lwt_io.Input sock in
  let oc = Lwt_io.of_fd ~close:(fun _ -> Lwt.return_unit) ~mode:Lwt_io.Output sock in
  let* status, body =
    Lwt.finalize
      (fun () ->
        let* () = Lwt_io.write oc request in
        let* () = Lwt_io.flush oc in
        read_http_response ic)
      (fun () ->
        let* () = Lwt_io.close oc in
        let* () = Lwt_io.close ic in
        Lwt_unix.close sock)
  in
  if status >= 200 && status < 300 then Lwt.return_unit
  else begin
    (* Docker on macOS returns 500 for lsetxattr errors but the file is still copied *)
    let is_xattr_error =
      try
        let json = Yojson.Safe.from_string body in
        let msg = Json.get_string "message" json |> Option.value ~default:"" in
        String.length msg > 0
        && (String.sub msg 0 (min 9 (String.length msg)) = "lsetxattr"
           || String.sub msg 0 (min 10 (String.length msg)) = "lgetxattr")
      with _ -> false
    in
    if is_xattr_error then
      (* Ignore xattr errors - the file is still copied successfully *)
      Lwt.return_unit
    else
      let message =
        try
          let json = Yojson.Safe.from_string body in
          Json.get_string "message" json |> Option.value ~default:body
        with _ -> body
      in
      Error.fail_docker_error ~status ~message
  end

let get_archive id ~path =
  let encoded_path = Uri.pct_encode path in
  let api_path =
    Printf.sprintf "/containers/%s/archive?path=%s" id encoded_path
  in
  let* resp = make_request `GET api_path () in
  handle_response resp

(* Network operations *)
let create_network ~driver name =
  let body =
    Yojson.Safe.to_string
      (`Assoc
         [
           ("Name", `String name);
           ("Driver", `String driver);
           ("CheckDuplicate", `Bool true);
         ])
  in
  let* resp = make_request `POST "/networks/create" ~body () in
  let* body_str = handle_response resp in
  let json = Yojson.Safe.from_string body_str in
  Lwt.return (Json.get_string_exn "Id" json)

let remove_network id =
  let path = Printf.sprintf "/networks/%s" id in
  let* resp = make_request `DELETE path () in
  let* _ = handle_response resp in
  Lwt.return_unit

let connect_container_to_network ~network_id ~container_id ~aliases =
  let aliases_json = `List (List.map (fun a -> `String a) aliases) in
  let body =
    Yojson.Safe.to_string
      (`Assoc
         [
           ("Container", `String container_id);
           ("EndpointConfig", `Assoc [ ("Aliases", aliases_json) ]);
         ])
  in
  let path = Printf.sprintf "/networks/%s/connect" network_id in
  let* resp = make_request `POST path ~body () in
  let* _ = handle_response resp in
  Lwt.return_unit

let disconnect_container_from_network ~network_id ~container_id =
  let body =
    Yojson.Safe.to_string (`Assoc [ ("Container", `String container_id) ])
  in
  let path = Printf.sprintf "/networks/%s/disconnect" network_id in
  let* resp = make_request `POST path ~body () in
  let* _ = handle_response resp in
  Lwt.return_unit
