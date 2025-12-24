(** MongoDB example: Running MongoDB for integration tests *)

open Lwt.Syntax
open Testcontainers_mongo

let () =
  Lwt_main.run begin
    Printf.printf "Starting MongoDB container...\n%!";

    Mongo_container.with_mongo
      ~config:(fun c ->
        c
        |> Mongo_container.with_username "admin"
        |> Mongo_container.with_password "secret")
      (fun container conn_str ->
        Printf.printf "MongoDB is ready!\n%!";
        Printf.printf "Connection string: %s\n%!" conn_str;

        let* host = Mongo_container.host container in
        let config = Mongo_container.create ()
          |> Mongo_container.with_username "admin" in
        let* port = Mongo_container.port config container in

        Printf.printf "Host: %s\n%!" host;
        Printf.printf "Port: %d\n%!" port;

        Printf.printf "Running MongoDB tests...\n%!";
        Lwt_unix.sleep 1.0
      )
  end;
  Printf.printf "MongoDB container cleaned up.\n"
