(** Error types for testcontainers *)

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

let to_string = function
  | Container_not_found id ->
      Printf.sprintf "Container not found: %s" id
  | Container_not_running id ->
      Printf.sprintf "Container not running: %s" id
  | Container_start_failed { id; message } ->
      Printf.sprintf "Failed to start container %s: %s" id message
  | Container_stop_failed { id; message } ->
      Printf.sprintf "Failed to stop container %s: %s" id message
  | Wait_timeout { strategy; timeout } ->
      Printf.sprintf "Wait strategy '%s' timed out after %.1fs" strategy timeout
  | Docker_error { status; message } ->
      Printf.sprintf "Docker API error (status %d): %s" status message
  | Docker_connection_failed msg ->
      Printf.sprintf "Failed to connect to Docker daemon: %s" msg
  | Invalid_configuration msg ->
      Printf.sprintf "Invalid configuration: %s" msg
  | Image_pull_failed { image; message } ->
      Printf.sprintf "Failed to pull image %s: %s" image message
  | Port_not_mapped { container_port; protocol } ->
      Printf.sprintf "Port %d/%s not mapped" container_port protocol

let raise_error err = raise (Testcontainers_error err)

let fail_container_not_found id = raise_error (Container_not_found id)
let fail_docker_error ~status ~message = raise_error (Docker_error { status; message })
let fail_invalid_config msg = raise_error (Invalid_configuration msg)
let fail_wait_timeout ~strategy ~timeout = raise_error (Wait_timeout { strategy; timeout })
