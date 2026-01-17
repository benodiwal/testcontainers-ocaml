(** Elasticsearch example: Running Elasticsearch for integration tests *)

open Lwt.Syntax
open Testcontainers_elasticsearch

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting Elasticsearch container...\n%!";

      (* Simple Elasticsearch without security *)
      Elasticsearch_container.with_elasticsearch (fun container url ->
          Printf.printf "Elasticsearch is ready!\n%!";
          Printf.printf "Connection URL: %s\n%!" url;

          let* host = Elasticsearch_container.host container in
          let config = Elasticsearch_container.create () in
          let* port = Elasticsearch_container.port config container in

          Printf.printf "Host: %s\n%!" host;
          Printf.printf "Port: %d\n%!" port;

          (* Here you would use HTTP client to interact with Elasticsearch:

             Example with cohttp:
             let* resp, body = Cohttp_lwt_unix.Client.get (Uri.of_string (url ^ "/_cluster/health")) in
             let* body_str = Cohttp_lwt.Body.to_string body in
             Printf.printf "Health: %s\n" body_str;
             ...
          *)
          Printf.printf "Running Elasticsearch tests...\n%!";
          Lwt_unix.sleep 1.0)
    end;
  Printf.printf "Elasticsearch container cleaned up.\n"

(* Elasticsearch with security enabled *)
let _elasticsearch_with_security () =
  Lwt_main.run
    begin
      Elasticsearch_container.with_elasticsearch
        ~config:(fun c ->
          c
          |> Elasticsearch_container.with_password "changeme"
          |> Elasticsearch_container.with_security_enabled true)
        (fun _container url ->
          Printf.printf "Elasticsearch with auth: %s\n%!" url;
          (* URL will be: http://elastic:changeme@127.0.0.1:XXXXX *)
          Lwt.return_unit)
    end
