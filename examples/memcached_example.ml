(** Memcached example: Running Memcached for integration tests *)

open Lwt.Syntax
open Testcontainers_memcached

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting Memcached container...\n%!";

      Memcached_container.with_memcached (fun container connection_string ->
          Printf.printf "Memcached is ready!\n%!";
          Printf.printf "Connection: %s\n%!" connection_string;

          let* host = Memcached_container.host container in
          let config = Memcached_container.create () in
          let* port = Memcached_container.port config container in

          Printf.printf "Host: %s\n%!" host;
          Printf.printf "Port: %d\n%!" port;

          (* Here you would use your Memcached client library:

             Example:
             let client = Memcached.connect ~host ~port () in
             let* () = Memcached.set client "key" "value" in
             let* value = Memcached.get client "key" in
             ...
          *)
          Printf.printf "Running Memcached tests...\n%!";
          Lwt_unix.sleep 1.0)
    end;
  Printf.printf "Memcached container cleaned up.\n"

(* Memcached with custom memory limit *)
let _memcached_with_memory () =
  Lwt_main.run
    begin
      Memcached_container.with_memcached
        ~config:(fun c -> Memcached_container.with_memory_mb 256 c)
        (fun _container conn ->
          Printf.printf "Memcached (256MB): %s\n%!" conn;
          Lwt.return_unit)
    end
