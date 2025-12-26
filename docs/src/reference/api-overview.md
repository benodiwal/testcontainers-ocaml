# API Overview

This page provides a quick reference to all modules and their primary functions.

## Core Modules

### Testcontainers.Container

Container lifecycle management.

```ocaml
(* Start a container *)
val start : Container_request.t -> t Lwt.t

(* Stop a container *)
val stop : ?timeout:float -> t -> unit Lwt.t

(* Stop and remove a container *)
val terminate : t -> unit Lwt.t

(* Start, run function, then terminate *)
val with_container : Container_request.t -> (t -> 'a Lwt.t) -> 'a Lwt.t

(* Get container ID *)
val id : t -> string

(* Get container name *)
val name : t -> string

(* Get host (always 127.0.0.1) *)
val host : t -> string Lwt.t

(* Get mapped port *)
val mapped_port : t -> Port.t -> int Lwt.t

(* Get all mapped ports *)
val mapped_ports : t -> Port.mapped_port list Lwt.t

(* Check if running *)
val is_running : t -> bool Lwt.t

(* Get container state *)
val state : t -> [> `Created | `Running | `Paused | `Exited | `Dead | `Restarting] Lwt.t

(* Execute command in container *)
val exec : t -> string list -> (int * string) Lwt.t

(* Get container logs *)
val logs : ?since:float -> ?follow:bool -> t -> string Lwt.t

(* Copy file to container *)
val copy_file_to : t -> src:string -> dest:string -> unit Lwt.t

(* Copy file from container *)
val copy_file_from : t -> src:string -> dest:string -> unit Lwt.t

(* Copy string content to container *)
val copy_content_to : t -> content:string -> dest:string -> unit Lwt.t
```

### Testcontainers.Container_request

Builder for container configuration.

```ocaml
(* Create request with image *)
val create : string -> t

(* Image configuration *)
val with_image : string -> t -> t
val image : t -> string

(* Port configuration *)
val with_exposed_port : Port.t -> t -> t
val with_exposed_ports : Port.t list -> t -> t
val exposed_ports : t -> Port.t list

(* Environment variables *)
val with_env : string -> string -> t -> t
val with_envs : (string * string) list -> t -> t
val environment : t -> (string * string) list

(* Command and entrypoint *)
val with_cmd : string list -> t -> t
val with_entrypoint : string list -> t -> t
val command : t -> string list option
val entrypoint : t -> string list option

(* Container settings *)
val with_name : string -> t -> t
val with_user : string -> t -> t
val with_working_dir : string -> t -> t
val with_privileged : bool -> t -> t
val name : t -> string option
val user : t -> string option
val working_dir : t -> string option
val privileged : t -> bool

(* Labels *)
val with_label : string -> string -> t -> t
val with_labels : (string * string) list -> t -> t
val labels : t -> (string * string) list

(* Mounts *)
val with_mount : Volume.mount -> t -> t
val mounts : t -> Volume.mount list

(* Wait strategy *)
val with_wait_strategy : Wait_strategy.t -> t -> t
val wait_strategy : t -> Wait_strategy.t option

(* Timeouts *)
val with_startup_timeout : float -> t -> t
val startup_timeout : t -> float

(* Auto remove *)
val with_auto_remove : bool -> t -> t
val auto_remove : t -> bool
```

### Testcontainers.Port

Port types and utilities.

```ocaml
type protocol = Tcp | Udp

type t = {
  port : int;
  protocol : protocol;
}

type mapped_port = {
  container_port : t;
  host_port : int;
  host_ip : string;
}

(* Create ports *)
val tcp : int -> t
val udp : int -> t

(* Parse from string *)
val of_string : string -> t  (* "8080/tcp" -> Port.t *)

(* Convert to string *)
val to_string : t -> string  (* "8080/tcp" *)
val to_docker_format : t -> string

(* Comparison *)
val equal : t -> t -> bool
val compare : t -> t -> int

(* Protocol conversion *)
val protocol_to_string : protocol -> string
```

### Testcontainers.Volume

Volume and mount configuration.

```ocaml
type bind_mode = ReadWrite | ReadOnly

type mount =
  | Bind of { host_path : string; container_path : string; mode : bind_mode }
  | Volume of { name : string; container_path : string; mode : bind_mode }
  | Tmpfs of { container_path : string; size : int option }

(* Create mounts *)
val bind : ?mode:bind_mode -> host:string -> container:string -> unit -> mount
val volume : ?mode:bind_mode -> name:string -> container:string -> unit -> mount
val tmpfs : ?size:int -> container:string -> unit -> mount

(* Utilities *)
val container_path : mount -> string
val to_docker_bind_format : mount -> string
val mode_to_string : bind_mode -> string
```

### Testcontainers.Wait_strategy

Wait strategy configuration.

```ocaml
type t

(* Create strategies *)
val for_listening_port : Port.t -> t
val for_log : ?occurrence:int -> string -> t
val for_log_regex : string -> t
val for_http : ?port:Port.t -> ?status_codes:int list -> string -> t
val for_exec : string list -> t
val for_health_check : unit -> t
val none : t

(* Combinators *)
val all : t list -> t
val any : t list -> t

(* Configuration *)
val with_timeout : float -> t -> t
val with_poll_interval : float -> t -> t

(* Inspection *)
val name : t -> string
val timeout : t -> float
```

### Testcontainers.Network

Docker network management.

```ocaml
type t

(* Create network *)
val create : ?driver:string -> string -> t Lwt.t

(* Remove network *)
val remove : t -> unit Lwt.t

(* Create, use, then remove *)
val with_network : ?driver:string -> string -> (t -> 'a Lwt.t) -> 'a Lwt.t

(* Properties *)
val id : t -> string
val name : t -> string
```

### Testcontainers.Error

Error types and handling.

```ocaml
type t =
  | Container_not_found of string
  | Container_not_running of string
  | Container_start_failed of { id : string; message : string }
  | Container_stop_failed of { id : string; message : string }
  | Wait_timeout of { strategy : string; timeout : float }
  | Docker_error of { status : int; message : string }
  | Docker_connection_failed of string
  | Invalid_configuration of string
  | Image_pull_failed of { image : string; message : string }
  | Port_not_mapped of { container_port : int; protocol : string }

exception Testcontainers_error of t

val to_string : t -> string
val raise_error : t -> 'a
```

### Testcontainers.Docker_client

Low-level Docker API client.

```ocaml
(* Health check *)
val ping : unit -> bool Lwt.t

(* Version info *)
val version : unit -> (string * string) Lwt.t

(* Image operations *)
val image_exists : string -> bool Lwt.t
val pull_image : string -> unit Lwt.t
```

## Module Libraries

### Testcontainers_postgres.Postgres_container

```ocaml
type config

val create : unit -> config
val with_image : string -> config -> config
val with_database : string -> config -> config
val with_username : string -> config -> config
val with_password : string -> config -> config

val database : config -> string
val username : config -> string

val start : config -> Container.t Lwt.t
val host : Container.t -> string Lwt.t
val port : config -> Container.t -> int Lwt.t
val connection_string : config -> Container.t -> string Lwt.t
val jdbc_url : config -> Container.t -> string Lwt.t

val with_postgres : ?config:(config -> config) ->
  (Container.t -> string -> 'a Lwt.t) -> 'a Lwt.t
```

### Testcontainers_mysql.Mysql_container

```ocaml
type config

val create : unit -> config
val with_image : string -> config -> config
val with_database : string -> config -> config
val with_username : string -> config -> config
val with_password : string -> config -> config
val with_root_password : string -> config -> config

val database : config -> string
val username : config -> string
val password : config -> string

val start : config -> Container.t Lwt.t
val host : Container.t -> string Lwt.t
val port : config -> Container.t -> int Lwt.t
val connection_string : config -> Container.t -> string Lwt.t
val jdbc_url : config -> Container.t -> string Lwt.t

val with_mysql : ?config:(config -> config) ->
  (Container.t -> string -> 'a Lwt.t) -> 'a Lwt.t
```

### Testcontainers_mongo.Mongo_container

```ocaml
type config

val create : unit -> config
val with_image : string -> config -> config
val with_username : string -> config -> config
val with_password : string -> config -> config

val username : config -> string
val password : config -> string

val start : config -> Container.t Lwt.t
val host : Container.t -> string Lwt.t
val port : config -> Container.t -> int Lwt.t
val connection_string : config -> Container.t -> string Lwt.t

val with_mongo : ?config:(config -> config) ->
  (Container.t -> string -> 'a Lwt.t) -> 'a Lwt.t
```

### Testcontainers_redis.Redis_container

```ocaml
type config

val create : unit -> config
val with_image : string -> config -> config

val start : config -> Container.t Lwt.t
val host : Container.t -> string Lwt.t
val port : Container.t -> int Lwt.t
val uri : config -> Container.t -> string Lwt.t

val with_redis : ?config:(config -> config) ->
  (Container.t -> string -> 'a Lwt.t) -> 'a Lwt.t
```

### Testcontainers_rabbitmq.Rabbitmq_container

```ocaml
type config

val create : unit -> config
val with_image : string -> config -> config
val with_username : string -> config -> config
val with_password : string -> config -> config
val with_vhost : string -> config -> config

val username : config -> string
val vhost : config -> string

val start : config -> Container.t Lwt.t
val host : Container.t -> string Lwt.t
val amqp_port : Container.t -> int Lwt.t
val management_port : Container.t -> int Lwt.t
val amqp_url : config -> Container.t -> string Lwt.t

val with_rabbitmq : ?config:(config -> config) ->
  (Container.t -> string -> 'a Lwt.t) -> 'a Lwt.t
```
