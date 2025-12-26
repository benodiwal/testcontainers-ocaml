(** Basic example: Running an Nginx container *)

open Lwt.Syntax
open Testcontainers

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting Nginx container...\n%!";

      let request =
        Container_request.create "nginx:alpine"
        |> Container_request.with_exposed_port (Port.tcp 80)
        |> Container_request.with_wait_strategy
             (Wait_strategy.for_listening_port (Port.tcp 80))
      in

      Lwt.catch
        (fun () ->
          Container.with_container request (fun container ->
              let* host = Container.host container in
              let* port = Container.mapped_port container (Port.tcp 80) in

              Printf.printf "Nginx is running at http://%s:%d\n%!" host port;
              Printf.printf "Container ID: %s\n%!" (Container.id container);

              Printf.printf "Running tests...\n%!";
              let* () = Lwt_unix.sleep 2.0 in
              Printf.printf "Container cleaned up automatically.\n%!";
              Lwt.return_unit))
        (fun exn ->
          Printf.printf "Error: %s\n%!" (Printexc.to_string exn);
          (match exn with
          | Error.Testcontainers_error err ->
              Printf.printf "Details: %s\n%!" (Error.to_string err)
          | _ -> ());
          Lwt.return_unit)
    end
