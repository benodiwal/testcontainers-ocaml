(** Kafka container module using Confluent Kafka image *)

open Lwt.Syntax
open Testcontainers

let default_image = "confluentinc/cp-kafka:7.5.0"
let default_port = Port.tcp 9092

type t = { image : string; port : Port.exposed_port; kraft_mode : bool }

let create () =
  { image = default_image; port = default_port; kraft_mode = true }

let with_image image t = { t with image }
let with_kraft_mode kraft_mode t = { t with kraft_mode }

let to_request t =
  let cluster_id = "MkU3OEVBNTcwNTJENDM2Qk" in
  Container_request.create t.image
  |> Container_request.with_exposed_port t.port
  |> Container_request.with_env "KAFKA_NODE_ID" "1"
  |> Container_request.with_env "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
       "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT"
  |> Container_request.with_env "KAFKA_ADVERTISED_LISTENERS"
       "PLAINTEXT://localhost:29092,PLAINTEXT_HOST://localhost:9092"
  |> Container_request.with_env "KAFKA_PROCESS_ROLES" "broker,controller"
  |> Container_request.with_env "KAFKA_CONTROLLER_QUORUM_VOTERS"
       "1@localhost:29093"
  |> Container_request.with_env "KAFKA_LISTENERS"
       "PLAINTEXT://0.0.0.0:29092,CONTROLLER://0.0.0.0:29093,PLAINTEXT_HOST://0.0.0.0:9092"
  |> Container_request.with_env "KAFKA_INTER_BROKER_LISTENER_NAME" "PLAINTEXT"
  |> Container_request.with_env "KAFKA_CONTROLLER_LISTENER_NAMES" "CONTROLLER"
  |> Container_request.with_env "CLUSTER_ID" cluster_id
  |> Container_request.with_env "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR" "1"
  |> Container_request.with_env "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS" "0"
  |> Container_request.with_env "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR" "1"
  |> Container_request.with_env "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
       "1"
  |> Container_request.with_env "KAFKA_LOG_DIRS" "/tmp/kraft-combined-logs"
  |> Container_request.with_wait_strategy
       (Wait_strategy.for_log ~timeout:60.0 "Kafka Server started")

let start t =
  let request = to_request t in
  Container.start request

let bootstrap_servers t container =
  let* host = Container.host container in
  let* port = Container.mapped_port container t.port in
  Lwt.return (Printf.sprintf "%s:%d" host port)

let host container = Container.host container
let port t container = Container.mapped_port container t.port

let with_kafka ?config f =
  let t = match config with Some cfg -> cfg (create ()) | None -> create () in
  let* container = start t in
  let* servers = bootstrap_servers t container in
  Lwt.finalize
    (fun () -> f container servers)
    (fun () -> Container.terminate container)
