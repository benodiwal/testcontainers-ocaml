(** Volume and mount types for container configuration *)

type bind_mode =
  | ReadWrite
  | ReadOnly

type mount =
  | Bind of {
      host_path : string;
      container_path : string;
      mode : bind_mode;
    }
  | Volume of {
      name : string;
      container_path : string;
      mode : bind_mode;
    }
  | Tmpfs of {
      container_path : string;
      size : int option;
    }

let bind ?(mode = ReadWrite) ~host ~container () =
  Bind { host_path = host; container_path = container; mode }

let volume ?(mode = ReadWrite) ~name ~container () =
  Volume { name; container_path = container; mode }

let tmpfs ?size ~container () =
  Tmpfs { container_path = container; size }

let mode_to_string = function
  | ReadWrite -> "rw"
  | ReadOnly -> "ro"

let to_docker_bind_format = function
  | Bind { host_path; container_path; mode } ->
      Printf.sprintf "%s:%s:%s" host_path container_path (mode_to_string mode)
  | Volume { name; container_path; mode } ->
      Printf.sprintf "%s:%s:%s" name container_path (mode_to_string mode)
  | Tmpfs { container_path; size } ->
      let size_opt = match size with
        | Some s -> Printf.sprintf ",size=%d" s
        | None -> ""
      in
      Printf.sprintf "type=tmpfs,destination=%s%s" container_path size_opt

let container_path = function
  | Bind { container_path; _ } -> container_path
  | Volume { container_path; _ } -> container_path
  | Tmpfs { container_path; _ } -> container_path
