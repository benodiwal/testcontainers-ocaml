(** Port type definitions for container port mapping *)

type protocol = Tcp | Udp
type exposed_port = { port : int; protocol : protocol }

type mapped_port = {
  container_port : exposed_port;
  host_port : int;
  host_ip : string;
}

let tcp port = { port; protocol = Tcp }
let udp port = { port; protocol = Udp }
let protocol_to_string = function Tcp -> "tcp" | Udp -> "udp"

let protocol_of_string = function
  | "tcp" -> Tcp
  | "udp" -> Udp
  | s -> failwith (Printf.sprintf "Unknown protocol: %s" s)

let to_string { port; protocol } =
  Printf.sprintf "%d/%s" port (protocol_to_string protocol)

let to_docker_format { port; protocol } =
  Printf.sprintf "%d/%s" port (protocol_to_string protocol)

let of_string s =
  match String.split_on_char '/' s with
  | [ port_str; proto_str ] ->
      { port = int_of_string port_str; protocol = protocol_of_string proto_str }
  | [ port_str ] -> { port = int_of_string port_str; protocol = Tcp }
  | _ -> failwith (Printf.sprintf "Invalid port format: %s" s)

let equal p1 p2 = p1.port = p2.port && p1.protocol = p2.protocol

let compare p1 p2 =
  match Int.compare p1.port p2.port with
  | 0 -> compare p1.protocol p2.protocol
  | n -> n
