(** LocalStack container module for AWS service emulation *)

open Lwt.Syntax
open Testcontainers

let default_image = "localstack/localstack:3.0"
let default_port = Port.tcp 4566

type t = {
  image : string;
  port : Port.exposed_port;
  services : string list;
  region : string;
}

let create () =
  {
    image = default_image;
    port = default_port;
    services = [];
    region = "us-east-1";
  }

let with_image image t = { t with image }
let with_services services t = { t with services }
let with_region region t = { t with region }

let to_request t =
  let request =
    Container_request.create t.image
    |> Container_request.with_exposed_port t.port
    |> Container_request.with_env "DEBUG" "1"
    |> Container_request.with_env "AWS_DEFAULT_REGION" t.region
  in
  let request =
    if List.length t.services > 0 then
      request
      |> Container_request.with_env "SERVICES" (String.concat "," t.services)
    else request
  in
  request
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log ~timeout:120.0 "Ready.")

let start t =
  let request = to_request t in
  Container.start request

let endpoint t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  Lwt.return (Printf.sprintf "http://%s:%d" host port)

let service_endpoint t container service =
  let* base = endpoint t container in
  Lwt.return (Printf.sprintf "%s/%s" base service)

let host container = Container.host container
let port t container = Container.mapped_port container t.port
let region t = t.region

let with_localstack ?config f =
  let t = match config with Some cfg -> cfg (create ()) | None -> create () in
  let* container = start t in
  let* url = endpoint t container in
  Lwt.finalize
    (fun () -> f container url)
    (fun () -> Container.terminate container)
