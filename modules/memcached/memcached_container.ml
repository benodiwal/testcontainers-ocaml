(** Memcached container module *)

open Lwt.Syntax
open Testcontainers

let default_image = "memcached:1.6-alpine"
let default_port = Port.tcp 11211

type t = {
  image : string;
  port : Port.exposed_port;
  memory_mb : int;
}

let create () = { image = default_image; port = default_port; memory_mb = 64 }
let with_image image t = { t with image }
let with_memory_mb mb t = { t with memory_mb = mb }

let to_request t =
  Container_request.create t.image
  |> Container_request.with_exposed_port t.port
  |> Container_request.with_cmd [ "memcached"; "-m"; string_of_int t.memory_mb ]
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_listening_port ~timeout:30.0 t.port)

let start t =
  let request = to_request t in
  Container.start request

let connection_string t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  Lwt.return (Printf.sprintf "%s:%d" host port)

let host container = Container.host container
let port t container = Container.mapped_port container t.port

let with_memcached ?config f =
  let t = match config with Some cfg -> cfg (create ()) | None -> create () in
  let* container = start t in
  let* conn = connection_string t container in
  Lwt.finalize
    (fun () -> f container conn)
    (fun () -> Container.terminate container)
