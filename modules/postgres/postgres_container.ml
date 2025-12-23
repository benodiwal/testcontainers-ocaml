(** PostgreSQL container module with sensible defaults *)

open Lwt.Syntax
open Testcontainers

let default_image = "postgres:16-alpine"
let default_port = Port.tcp 5432
let default_database = "test"
let default_username = "test"
let default_password = "test"

type t = {
  image : string;
  database : string;
  username : string;
  password : string;
  init_scripts : string list;
  port : Port.exposed_port;
}

let create () = {
  image = default_image;
  database = default_database;
  username = default_username;
  password = default_password;
  init_scripts = [];
  port = default_port;
}

let with_image image t = { t with image }
let with_database database t = { t with database }
let with_username username t = { t with username }
let with_password password t = { t with password }
let with_init_script script t = { t with init_scripts = script :: t.init_scripts }
let with_init_scripts scripts t = { t with init_scripts = scripts @ t.init_scripts }

let database t = t.database
let username t = t.username
let password t = t.password

let to_request t =
  Container_request.create t.image
  |> Container_request.with_exposed_port t.port
  |> Container_request.with_env "POSTGRES_DB" t.database
  |> Container_request.with_env "POSTGRES_USER" t.username
  |> Container_request.with_env "POSTGRES_PASSWORD" t.password
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log ~occurrence:2 ~timeout:60.0
          "database system is ready to accept connections")

let start t =
  let request = to_request t in
  Container.start request

let connection_string ?(params = []) t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  let base = Printf.sprintf "postgresql://%s:%s@%s:%d/%s"
    t.username t.password host port t.database in
  let params_str =
    if params = [] then ""
    else "?" ^ String.concat "&" (List.map (fun (k, v) -> k ^ "=" ^ v) params)
  in
  Lwt.return (base ^ params_str)

let jdbc_url t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  Lwt.return (Printf.sprintf "jdbc:postgresql://%s:%d/%s" host port t.database)

let host container = Container.host container

let port t container = Container.mapped_port container t.port

let with_postgres ?config f =
  let t = match config with
    | Some cfg -> cfg (create ())
    | None -> create ()
  in
  let* container = start t in
  let* conn_str = connection_string t container in
  Lwt.finalize
    (fun () -> f container conn_str)
    (fun () -> Container.terminate container)
