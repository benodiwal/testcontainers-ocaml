(** MySQL container module for integration testing *)

open Lwt.Syntax
open Testcontainers

let default_image = "mysql:8"
let default_port = 3306
let default_database = "test"
let default_username = "test"
let default_password = "test"
let default_root_password = "root"

type config = {
  image : string;
  database : string;
  username : string;
  password : string;
  root_password : string;
}

let create () =
  {
    image = default_image;
    database = default_database;
    username = default_username;
    password = default_password;
    root_password = default_root_password;
  }

let with_image image config = { config with image }
let with_database database config = { config with database }
let with_username username config = { config with username }
let with_password password config = { config with password }
let with_root_password root_password config = { config with root_password }
let database config = config.database
let username config = config.username
let password config = config.password

let start config =
  let request =
    Container_request.create config.image
    |> Container_request.with_exposed_port (Port.tcp default_port)
    |> Container_request.with_env "MYSQL_DATABASE" config.database
    |> Container_request.with_env "MYSQL_USER" config.username
    |> Container_request.with_env "MYSQL_PASSWORD" config.password
    |> Container_request.with_env "MYSQL_ROOT_PASSWORD" config.root_password
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_log ~occurrence:2 "ready for connections")
  in
  Container.start request

let port config container =
  ignore config;
  Container.mapped_port container (Port.tcp default_port)

let host _container = Container.host _container

let connection_string config container =
  let* h = host container in
  let* p = port config container in
  Lwt.return
    (Printf.sprintf "mysql://%s:%s@%s:%d/%s" config.username config.password h p
       config.database)

let jdbc_url config container =
  let* h = host container in
  let* p = port config container in
  Lwt.return (Printf.sprintf "jdbc:mysql://%s:%d/%s" h p config.database)

let with_mysql ?(config = Fun.id) f =
  let cfg = config (create ()) in
  let request =
    Container_request.create cfg.image
    |> Container_request.with_exposed_port (Port.tcp default_port)
    |> Container_request.with_env "MYSQL_DATABASE" cfg.database
    |> Container_request.with_env "MYSQL_USER" cfg.username
    |> Container_request.with_env "MYSQL_PASSWORD" cfg.password
    |> Container_request.with_env "MYSQL_ROOT_PASSWORD" cfg.root_password
    |> Container_request.with_wait_strategy
         (Wait_strategy.for_log ~occurrence:2 "ready for connections")
  in
  Container.with_container request (fun container ->
      let* conn_str = connection_string cfg container in
      f container conn_str)
