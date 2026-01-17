(** Kafka example: Running Apache Kafka for integration tests *)

open Lwt.Syntax
open Testcontainers_kafka

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting Kafka container (KRaft mode)...\n%!";

      Kafka_container.with_kafka (fun container bootstrap_servers ->
          Printf.printf "Kafka is ready!\n%!";
          Printf.printf "Bootstrap servers: %s\n%!" bootstrap_servers;

          let* host = Kafka_container.host container in
          let config = Kafka_container.create () in
          let* port = Kafka_container.port config container in

          Printf.printf "Host: %s\n%!" host;
          Printf.printf "Port: %d\n%!" port;

          (* Here you would use your Kafka client library:
             - ocaml-kafka: https://github.com/didier-wenzek/ocaml-kafka

             Example:
             let producer = Kafka.new_producer ["bootstrap.servers", bootstrap_servers] in
             let topic = Kafka.new_topic producer "my-topic" [] in
             Kafka.produce topic Kafka.partition_unassigned "message";
             ...
          *)
          Printf.printf "Running Kafka tests...\n%!";
          Lwt_unix.sleep 1.0)
    end;
  Printf.printf "Kafka container cleaned up.\n"
