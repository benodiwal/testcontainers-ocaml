(** Container request builder with functional configuration pattern *)

type t = {
  image : string;
  exposed_ports : Port.exposed_port list;
  env : (string * string) list;
  cmd : string list option;
  entrypoint : string list option;
  mounts : Volume.mount list;
  network : string option;
  network_aliases : string list;
  name : string option;
  labels : (string * string) list;
  working_dir : string option;
  user : string option;
  privileged : bool;
  wait_strategy : Wait_strategy.t option;
  startup_timeout : float;
  auto_remove : bool;
}

let create image =
  {
    image;
    exposed_ports = [];
    env = [];
    cmd = None;
    entrypoint = None;
    mounts = [];
    network = None;
    network_aliases = [];
    name = None;
    labels = [];
    working_dir = None;
    user = None;
    privileged = false;
    wait_strategy = None;
    startup_timeout = 60.0;
    auto_remove = false;
  }

let with_exposed_port port t =
  { t with exposed_ports = port :: t.exposed_ports }

let with_exposed_ports ports t =
  { t with exposed_ports = ports @ t.exposed_ports }

let with_env key value t = { t with env = (key, value) :: t.env }
let with_envs envs t = { t with env = envs @ t.env }
let with_cmd cmd t = { t with cmd = Some cmd }
let with_entrypoint entrypoint t = { t with entrypoint = Some entrypoint }
let with_mount mount t = { t with mounts = mount :: t.mounts }
let with_mounts mounts t = { t with mounts = mounts @ t.mounts }
let with_network network t = { t with network = Some network }

let with_network_alias alias t =
  { t with network_aliases = alias :: t.network_aliases }

let with_name name t = { t with name = Some name }
let with_label key value t = { t with labels = (key, value) :: t.labels }
let with_labels labels t = { t with labels = labels @ t.labels }
let with_working_dir dir t = { t with working_dir = Some dir }
let with_user user t = { t with user = Some user }
let with_privileged privileged t = { t with privileged }
let with_wait_strategy strategy t = { t with wait_strategy = Some strategy }
let with_startup_timeout timeout t = { t with startup_timeout = timeout }
let with_auto_remove auto_remove t = { t with auto_remove }

(* Accessors *)
let image t = t.image
let exposed_ports t = t.exposed_ports
let environment t = t.env
let command t = t.cmd
let entrypoint t = t.entrypoint
let mounts t = t.mounts
let network t = t.network
let network_aliases t = t.network_aliases
let name t = t.name
let labels t = t.labels
let working_dir t = t.working_dir
let user t = t.user
let privileged t = t.privileged
let wait_strategy t = t.wait_strategy
let startup_timeout t = t.startup_timeout
let auto_remove t = t.auto_remove

(* Convert to Docker client config *)
let to_docker_config t =
  let env_list = List.map (fun (k, v) -> Printf.sprintf "%s=%s" k v) t.env in
  let exposed_ports_list = List.map Port.to_docker_format t.exposed_ports in
  let port_bindings =
    List.map
      (fun port ->
        let port_str = Port.to_docker_format port in
        (port_str, [ { Docker_client.host_ip = ""; host_port = "" } ]))
      t.exposed_ports
  in
  let binds = List.map Volume.to_docker_bind_format t.mounts in
  Docker_client.
    {
      image = t.image;
      cmd = t.cmd;
      entrypoint = t.entrypoint;
      env = env_list;
      exposed_ports = exposed_ports_list;
      host_config =
        {
          binds;
          port_bindings;
          publish_all_ports = true;
          privileged = t.privileged;
          auto_remove = t.auto_remove;
          network_mode = t.network;
        };
      labels = t.labels;
      working_dir = t.working_dir;
      user = t.user;
      attach_stdout = true;
      attach_stderr = true;
      tty = false;
    }
