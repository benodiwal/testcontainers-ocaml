(** RabbitMQ container module with sensible defaults *)

open Lwt.Syntax
open Testcontainers

let default_image = "rabbitmq:3-management-alpine"
let default_amqp_port = Port.tcp 5672
let default_management_port = Port.tcp 15672
let default_username = "guest"
let default_password = "guest"
let default_vhost = "/"

type t = {
  image : string;
  username : string;
  password : string;
  vhost : string;
  amqp_port : Port.exposed_port;
  management_port : Port.exposed_port;
}

let create () = {
  image = default_image;
  username = default_username;
  password = default_password;
  vhost = default_vhost;
  amqp_port = default_amqp_port;
  management_port = default_management_port;
}

let with_image image t = { t with image }
let with_username username t = { t with username }
let with_password password t = { t with password }
let with_vhost vhost t = { t with vhost }

let username t = t.username
let password t = t.password
let vhost t = t.vhost

let to_request t =
  Container_request.create t.image
  |> Container_request.with_exposed_port t.amqp_port
  |> Container_request.with_exposed_port t.management_port
  |> Container_request.with_env "RABBITMQ_DEFAULT_USER" t.username
  |> Container_request.with_env "RABBITMQ_DEFAULT_PASS" t.password
  |> Container_request.with_env "RABBITMQ_DEFAULT_VHOST" t.vhost
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log ~timeout:60.0 "Server startup complete")

let start t =
  let request = to_request t in
  Container.start request

let amqp_url t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.amqp_port in
  let vhost = if t.vhost = "/" then "" else Uri.pct_encode t.vhost in
  Lwt.return (Printf.sprintf "amqp://%s:%s@%s:%d/%s"
    t.username t.password host port vhost)

let management_url t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.management_port in
  Lwt.return (Printf.sprintf "http://%s:%d" host port)

let host container = Container.host container

let amqp_port t container = Container.mapped_port container t.amqp_port

let management_port t container = Container.mapped_port container t.management_port

let with_rabbitmq ?config f =
  let t = match config with
    | Some cfg -> cfg (create ())
    | None -> create ()
  in
  let* container = start t in
  let* url = amqp_url t container in
  Lwt.finalize
    (fun () -> f container url)
    (fun () -> Container.terminate container)
