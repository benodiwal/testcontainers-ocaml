(** Redis example: Running Redis for integration tests *)

open Lwt.Syntax
open Testcontainers_redis

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting Redis container...\n%!";

      (* Simple Redis without password *)
      Redis_container.with_redis (fun container uri ->
          Printf.printf "Redis is ready!\n%!";
          Printf.printf "Connection URI: %s\n%!" uri;

          let* host = Redis_container.host container in
          let config = Redis_container.create () in
          let* port = Redis_container.port config container in

          Printf.printf "Host: %s\n%!" host;
          Printf.printf "Port: %d\n%!" port;

          (* Here you would use your Redis client library:
         - redis-lwt: https://github.com/0xffea/redis-lwt

         Example:
         let* conn = Redis_lwt.connect ~uri () in
         let* _ = Redis_lwt.set conn "key" "value" in
         let* value = Redis_lwt.get conn "key" in
         ...
      *)
          Printf.printf "Running Redis tests...\n%!";
          Lwt_unix.sleep 1.0)
    end;
  Printf.printf "Redis container cleaned up.\n"

(* Redis with password authentication *)
let _redis_with_password () =
  Lwt_main.run
    begin
      Redis_container.with_redis
        ~config:(fun c -> Redis_container.with_password "mysecret" c)
        (fun _container uri ->
          Printf.printf "Redis with auth: %s\n%!" uri;
          (* URI will be: redis://:mysecret@127.0.0.1:XXXXX *)
          Lwt.return_unit)
    end
