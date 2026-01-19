(** MockServer container for mocking HTTP services.

    MockServer enables easy mocking of any system you integrate with via HTTP or
    HTTPS. This module provides a containerized MockServer instance for testing.

    {2 Example}
    {[
      open Lwt.Syntax

      let () =
        Lwt_main.run
          begin
            Mockserver_container.with_mockserver (fun _container url ->
                Printf.printf "MockServer running at: %s\n" url;
                (* Configure expectations via MockServer API *)
                Lwt.return_unit)
          end
    ]} *)

type t
(** MockServer container configuration *)

val create : unit -> t
(** Create a default MockServer configuration. Uses image
    [mockserver/mockserver:5.15.0] and port 1080. *)

val with_image : string -> t -> t
(** Use a custom MockServer image *)

val with_log_level : string -> t -> t
(** Set the log level (INFO, DEBUG, TRACE, WARN, ERROR). Default is INFO. *)

val with_max_expectations : int -> t -> t
(** Set the maximum number of expectations MockServer will hold *)

val start : t -> Testcontainers.Container.t Lwt.t
(** Start a MockServer container with the given configuration *)

val url : t -> Testcontainers.Container.t -> string Lwt.t
(** Get the MockServer URL (http://host:port) *)

val host : Testcontainers.Container.t -> string Lwt.t
(** Get the container host *)

val port : t -> Testcontainers.Container.t -> int Lwt.t
(** Get the mapped MockServer port *)

val with_mockserver :
  ?config:(t -> t) ->
  (Testcontainers.Container.t -> string -> 'a Lwt.t) ->
  'a Lwt.t
(** Run a function with a MockServer container. The container is automatically
    terminated when the function completes.

    @param config Optional configuration function
    @param f Function receiving the container and MockServer URL *)
