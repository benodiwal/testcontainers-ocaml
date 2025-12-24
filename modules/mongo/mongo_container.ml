(** MongoDB container module for integration testing *)

open Lwt.Syntax
open Testcontainers

let default_image = "mongo:7"
let default_port = 27017
let default_username = "root"
let default_password = "password"

type config = {
  image : string;
  username : string option;
  password : string option;
}

let create () = {
  image = default_image;
  username = None;
  password = None;
}

let with_image image config = { config with image }
let with_username username config = { config with username = Some username }
let with_password password config = { config with password = Some password }

let username config = Option.value config.username ~default:""
let password config = Option.value config.password ~default:""

let start config =
  let request =
    Container_request.create config.image
    |> Container_request.with_exposed_port (Port.tcp default_port)
  in
  let request = match config.username, config.password with
    | Some u, Some p ->
        request
        |> Container_request.with_env "MONGO_INITDB_ROOT_USERNAME" u
        |> Container_request.with_env "MONGO_INITDB_ROOT_PASSWORD" p
    | _ -> request
  in
  let request =
    request
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_log "Waiting for connections")
  in
  Container.start request

let port _config container =
  Container.mapped_port container (Port.tcp default_port)

let host container =
  Container.host container

let connection_string config container =
  let* h = host container in
  let* p = port config container in
  match config.username, config.password with
  | Some u, Some pw ->
      Lwt.return (Printf.sprintf "mongodb://%s:%s@%s:%d" u pw h p)
  | _ ->
      Lwt.return (Printf.sprintf "mongodb://%s:%d" h p)

let with_mongo ?(config = Fun.id) f =
  let cfg = config (create ()) in
  let request =
    Container_request.create cfg.image
    |> Container_request.with_exposed_port (Port.tcp default_port)
  in
  let request = match cfg.username, cfg.password with
    | Some u, Some p ->
        request
        |> Container_request.with_env "MONGO_INITDB_ROOT_USERNAME" u
        |> Container_request.with_env "MONGO_INITDB_ROOT_PASSWORD" p
    | _ -> request
  in
  let request =
    request
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_log "Waiting for connections")
  in
  Container.with_container request (fun container ->
    let* conn_str = connection_string cfg container in
    f container conn_str)
