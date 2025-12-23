(** Redis container module with sensible defaults *)

open Lwt.Syntax
open Testcontainers

let default_image = "redis:7-alpine"
let default_port = Port.tcp 6379

type t = {
  image : string;
  password : string option;
  port : Port.exposed_port;
}

let create () = {
  image = default_image;
  password = None;
  port = default_port;
}

let with_image image t = { t with image }
let with_password password t = { t with password = Some password }

let to_request t =
  let request =
    Container_request.create t.image
    |> Container_request.with_exposed_port t.port
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_listening_port ~timeout:60.0 t.port)
  in
  match t.password with
  | Some pw ->
      request
      |> Container_request.with_cmd ["redis-server"; "--requirepass"; pw]
  | None -> request

let start t =
  let request = to_request t in
  Container.start request

let connection_uri t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  let uri = match t.password with
    | Some pw -> Printf.sprintf "redis://:%s@%s:%d" pw host port
    | None -> Printf.sprintf "redis://%s:%d" host port
  in
  Lwt.return uri

let host container = Container.host container

let port t container = Container.mapped_port container t.port

let with_redis ?config f =
  let t = match config with
    | Some cfg -> cfg (create ())
    | None -> create ()
  in
  let* container = start t in
  let* uri = connection_uri t container in
  Lwt.finalize
    (fun () -> f container uri)
    (fun () -> Container.terminate container)
