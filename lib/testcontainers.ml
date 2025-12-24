(** Testcontainers for OCaml - Docker containers for integration testing

    This library provides lightweight, throwaway instances of databases,
    message brokers, or any service that runs in a Docker container for
    integration testing.

    {1 Quick Start}

    {[
      open Lwt.Syntax
      open Testcontainers

      let () = Lwt_main.run begin
        let request =
          Container_request.create "nginx:alpine"
          |> Container_request.with_exposed_port (Port.tcp 80)
          |> Container_request.with_wait_strategy
               (Wait_strategy.for_listening_port (Port.tcp 80))
        in
        Container.with_container request (fun container ->
          let* port = Container.mapped_port container (Port.tcp 80) in
          Printf.printf "Nginx available on port %d\n" port;
          Lwt.return_unit
        )
      end
    ]}
*)

module Error = Error
module Port = Port
module Volume = Volume
module Docker_client = Docker_client
module Container_request = Container_request
module Wait_strategy = Wait_strategy
module Container = Container
module Network = Network
