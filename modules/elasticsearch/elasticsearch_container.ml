(** Elasticsearch container module *)

open Lwt.Syntax
open Testcontainers

let default_image = "elasticsearch:8.11.0"
let default_port = Port.tcp 9200

type t = {
  image : string;
  port : Port.exposed_port;
  password : string option;
  security_enabled : bool;
}

let create () =
  {
    image = default_image;
    port = default_port;
    password = None;
    security_enabled = false;
  }

let with_image image t = { t with image }

let with_password password t =
  { t with password = Some password; security_enabled = true }

let with_security_enabled enabled t = { t with security_enabled = enabled }

let to_request t =
  let request =
    Container_request.create t.image
    |> Container_request.with_exposed_port t.port
    |> Container_request.with_env "discovery.type" "single-node"
    |> Container_request.with_env "xpack.security.enabled"
         (if t.security_enabled then "true" else "false")
    |> Container_request.with_env "ES_JAVA_OPTS" "-Xms512m -Xmx512m"
  in
  let request =
    match t.password with
    | Some pw -> request |> Container_request.with_env "ELASTIC_PASSWORD" pw
    | None -> request
  in
  request
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_http ~port:t.port ~timeout:120.0 "/_cluster/health")

let start t =
  let request = to_request t in
  Container.start request

let connection_url t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  let scheme = "http" in
  let url =
    match t.password with
    | Some pw when t.security_enabled ->
        Printf.sprintf "%s://elastic:%s@%s:%d" scheme pw host port
    | _ -> Printf.sprintf "%s://%s:%d" scheme host port
  in
  Lwt.return url

let host container = Container.host container
let port t container = Container.mapped_port container t.port

let with_elasticsearch ?config f =
  let t = match config with Some cfg -> cfg (create ()) | None -> create () in
  let* container = start t in
  let* url = connection_url t container in
  Lwt.finalize
    (fun () -> f container url)
    (fun () -> Container.terminate container)
