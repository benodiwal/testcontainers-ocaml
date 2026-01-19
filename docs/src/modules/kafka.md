# Kafka

The Kafka module provides a pre-configured Apache Kafka container using KRaft mode (no ZooKeeper required) for integration testing.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_kafka

let test_kafka () =
  Kafka_container.with_kafka (fun container bootstrap_servers ->
    Printf.printf "Kafka running at: %s\n" bootstrap_servers;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-kafka
```

In your `dune` file:

```scheme
(libraries testcontainers-kafka)
```

## Configuration

### Basic Usage

```ocaml
Kafka_container.with_kafka (fun container bootstrap_servers ->
  (* bootstrap_servers: "127.0.0.1:9092" *)
  ...
)
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `apache/kafka:3.7.0` | Docker image |

### Custom Image

```ocaml
Kafka_container.with_kafka
  ~config:(fun c -> c
    |> Kafka_container.with_image "apache/kafka:3.6.0")
  (fun container bootstrap_servers -> ...)
```

## Connection Details

### Bootstrap Servers

```
127.0.0.1:9092
```

### Individual Components

```ocaml
Kafka_container.with_kafka (fun container bootstrap_servers ->
  let* host = Kafka_container.host container in  (* "127.0.0.1" *)
  let* port = Kafka_container.port container in  (* 9092 *)
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config = Kafka_container.create () in
  let* container = Kafka_container.start config in
  let* bootstrap = Kafka_container.bootstrap_servers config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Topic Management

### Create a Topic

```ocaml
let create_topic container topic_name =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "/opt/kafka/bin/kafka-topics.sh";
    "--create";
    "--topic"; topic_name;
    "--bootstrap-server"; "localhost:9092";
    "--partitions"; "1";
    "--replication-factor"; "1"
  ] in
  assert (exit_code = 0);
  Printf.printf "Created topic: %s\n" topic_name;
  Lwt.return_unit
```

### List Topics

```ocaml
let list_topics container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "/opt/kafka/bin/kafka-topics.sh";
    "--list";
    "--bootstrap-server"; "localhost:9092"
  ] in
  Printf.printf "Topics: %s\n" output;
  Lwt.return_unit
```

## Producing and Consuming Messages

### Produce Messages

```ocaml
let produce_message container topic message =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "sh"; "-c";
    Printf.sprintf "echo '%s' | /opt/kafka/bin/kafka-console-producer.sh --topic %s --bootstrap-server localhost:9092"
      message topic
  ] in
  Lwt.return (exit_code = 0)
```

### Consume Messages

```ocaml
let consume_messages container topic =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "/opt/kafka/bin/kafka-console-consumer.sh";
    "--topic"; topic;
    "--bootstrap-server"; "localhost:9092";
    "--from-beginning";
    "--timeout-ms"; "5000"
  ] in
  Printf.printf "Messages: %s\n" output;
  Lwt.return_unit
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_kafka

let test_kafka_messaging _switch () =
  Kafka_container.with_kafka (fun container _bootstrap ->
    (* Create topic *)
    let* (code, _) = Container.exec container [
      "/opt/kafka/bin/kafka-topics.sh";
      "--create"; "--topic"; "test-topic";
      "--bootstrap-server"; "localhost:9092";
      "--partitions"; "1";
      "--replication-factor"; "1"
    ] in
    Alcotest.(check int) "topic created" 0 code;

    (* Produce message *)
    let* (code, _) = Container.exec container [
      "sh"; "-c";
      "echo 'Hello Kafka!' | /opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server localhost:9092"
    ] in
    Alcotest.(check int) "message produced" 0 code;

    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "Kafka Tests" [
      "messaging", [
        Alcotest_lwt.test_case "produce" `Slow test_kafka_messaging;
      ];
    ]
  )
```

## Wait Strategy

Kafka uses a log-based wait strategy to ensure the broker is ready:

```ocaml
Wait_strategy.for_log ~timeout:60.0 "Kafka Server started"
```

## KRaft Mode

This module uses Apache Kafka in KRaft mode, which means:
- No ZooKeeper dependency
- Faster startup
- Simpler configuration
- Single container deployment

## Troubleshooting

### Connection Refused

Kafka needs time to start. Always use `with_kafka`:

```ocaml
(* Good *)
Kafka_container.with_kafka (fun container bootstrap -> ...)

(* May fail if Kafka isn't ready *)
let* container = Container.start request in
(* immediate connection attempt *)
```

### Topic Creation Fails

Ensure the broker is fully started before creating topics. The wait strategy handles this automatically with `with_kafka`.

### Consumer Timeout

For tests, use a reasonable timeout:

```ocaml
"--timeout-ms"; "5000"  (* 5 seconds *)
```
