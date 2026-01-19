(** MockServer container module for mocking HTTP services *)

open Lwt.Syntax
open Testcontainers

let default_image = "mockserver/mockserver:5.15.0"
let default_port = Port.tcp 1080

type t = {
  image : string;
  port : Port.exposed_port;
  log_level : string;
  max_expectations : int option;
}

let create () =
  {
    image = default_image;
    port = default_port;
    log_level = "INFO";
    max_expectations = None;
  }

let with_image image t = { t with image }
let with_log_level level t = { t with log_level = level }
let with_max_expectations n t = { t with max_expectations = Some n }

let to_request t =
  let envs =
    [ ("MOCKSERVER_LOG_LEVEL", t.log_level) ]
    @
    match t.max_expectations with
    | Some n -> [ ("MOCKSERVER_MAX_EXPECTATIONS", string_of_int n) ]
    | None -> []
  in
  Container_request.create t.image
  |> Container_request.with_exposed_port t.port
  |> Container_request.with_envs envs
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log ~timeout:60.0 "started on port")

let start t =
  let request = to_request t in
  Container.start request

let url t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  Lwt.return (Printf.sprintf "http://%s:%d" host port)

let host container = Container.host container
let port t container = Container.mapped_port container t.port

let with_mockserver ?config f =
  let t = match config with Some cfg -> cfg (create ()) | None -> create () in
  let* container = start t in
  let* endpoint = url t container in
  Lwt.finalize
    (fun () -> f container endpoint)
    (fun () -> Container.terminate container)
