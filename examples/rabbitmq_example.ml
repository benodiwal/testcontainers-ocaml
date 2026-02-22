(** RabbitMQ example: Running RabbitMQ for integration tests *)

open Lwt.Syntax
open Testcontainers_rabbitmq

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting RabbitMQ container...\n%!";

      Rabbitmq_container.with_rabbitmq
        ~config:(fun c ->
          c
          |> Rabbitmq_container.with_username "myuser"
          |> Rabbitmq_container.with_password "mypassword"
          |> Rabbitmq_container.with_vhost "/")
        (fun container amqp_url ->
          Printf.printf "RabbitMQ is ready!\n%!";
          Printf.printf "AMQP URL: %s\n%!" amqp_url;

          let config =
            Rabbitmq_container.create ()
            |> Rabbitmq_container.with_username "myuser"
            |> Rabbitmq_container.with_password "mypassword"
          in

          let* host = Rabbitmq_container.host container in
          let* amqp_port = Rabbitmq_container.amqp_port config container in
          let* mgmt_port =
            Rabbitmq_container.management_port config container
          in
          let* mgmt_url = Rabbitmq_container.management_url config container in

          Printf.printf "Host: %s\n%!" host;
          Printf.printf "AMQP port: %d\n%!" amqp_port;
          Printf.printf "Management port: %d\n%!" mgmt_port;
          Printf.printf "Management URL: %s\n%!" mgmt_url;

          (* Here you would use your AMQP client library:
             - amqp-client: https://github.com/andersfugmann/amqp-client

             Example:
             let%lwt connection = Amqp_client_lwt.Connection.make ~id:"test" amqp_url in
             let%lwt channel = Amqp_client_lwt.Connection.open_channel
               ~id:"test" Amqp_client_lwt.Channel.no_confirm connection in
             let%lwt exchange = Amqp_client_lwt.Exchange.declare channel
               Amqp_client_lwt.Exchange.topic_t "my-exchange" in
             let%lwt queue = Amqp_client_lwt.Queue.declare channel "my-queue" in
             ...
          *)
          Printf.printf "Running RabbitMQ tests...\n%!";
          Lwt_unix.sleep 1.0)
    end;
  Printf.printf "RabbitMQ container cleaned up.\n"
