(** MySQL example: Running MySQL for integration tests *)

open Lwt.Syntax
open Testcontainers_mysql

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting MySQL container...\n%!";

      Mysql_container.with_mysql
        ~config:(fun c ->
          c
          |> Mysql_container.with_database "myapp_test"
          |> Mysql_container.with_username "testuser"
          |> Mysql_container.with_password "testpass"
          |> Mysql_container.with_root_password "rootpass")
        (fun container conn_str ->
          Printf.printf "MySQL is ready!\n%!";
          Printf.printf "Connection string: %s\n%!" conn_str;

          let* host = Mysql_container.host container in
          let config =
            Mysql_container.create ()
            |> Mysql_container.with_database "myapp_test"
          in
          let* port = Mysql_container.port config container in

          Printf.printf "Host: %s\n%!" host;
          Printf.printf "Port: %d\n%!" port;
          Printf.printf "Database: %s\n%!" (Mysql_container.database config);
          Printf.printf "Username: %s\n%!" (Mysql_container.username config);

          Printf.printf "Running database tests...\n%!";
          Lwt_unix.sleep 1.0)
    end;
  Printf.printf "MySQL container cleaned up.\n"
