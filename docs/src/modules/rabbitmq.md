# RabbitMQ

The RabbitMQ module provides a pre-configured container for integration testing with RabbitMQ message broker.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_rabbitmq

let test_rabbitmq () =
  Rabbitmq_container.with_rabbitmq (fun container amqp_url ->
    Printf.printf "RabbitMQ running at: %s\n" amqp_url;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-rabbitmq
```

In your `dune` file:

```scheme
(libraries testcontainers-rabbitmq)
```

## Configuration

### Basic Configuration

```ocaml
Rabbitmq_container.with_rabbitmq
  ~config:(fun c -> c
    |> Rabbitmq_container.with_username "myuser"
    |> Rabbitmq_container.with_password "mypass"
    |> Rabbitmq_container.with_vhost "/myapp")
  (fun container amqp_url ->
    (* amqp_url: amqp://myuser:mypass@127.0.0.1:5672/myapp *)
    ...
  )
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `rabbitmq:3-management-alpine` | Docker image |
| `with_username` | `guest` | Username |
| `with_password` | `guest` | Password |
| `with_vhost` | `/` | Virtual host |

### Custom Image

```ocaml
Rabbitmq_container.with_rabbitmq
  ~config:(fun c -> c
    |> Rabbitmq_container.with_image "rabbitmq:3.12-alpine")
  (fun container amqp_url -> ...)
```

## Connection Details

### AMQP URL

```
amqp://username:password@host:port/vhost
```

### Individual Components

```ocaml
Rabbitmq_container.with_rabbitmq (fun container amqp_url ->
  let* host = Rabbitmq_container.host container in
  let* amqp_port = Rabbitmq_container.amqp_port container in
  let* mgmt_port = Rabbitmq_container.management_port container in
  let config = Rabbitmq_container.create () in
  let username = Rabbitmq_container.username config in
  let password = Rabbitmq_container.password config in
  let vhost = Rabbitmq_container.vhost config in
  ...
)
```

### Management UI

The default image includes the management plugin:

```ocaml
let* mgmt_port = Rabbitmq_container.management_port container in
Printf.printf "Management UI: http://127.0.0.1:%d\n" mgmt_port;
(* Default credentials: guest/guest *)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config =
    Rabbitmq_container.create ()
    |> Rabbitmq_container.with_username "admin"
    |> Rabbitmq_container.with_password "secret"
    |> Rabbitmq_container.with_vhost "/test"
  in

  let* container = Rabbitmq_container.start config in
  let* amqp_url = Rabbitmq_container.amqp_url config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Queue and Exchange Setup

### Using rabbitmqadmin

```ocaml
let setup_queues container =
  (* Declare exchange *)
  let* (code, _) = Testcontainers.Container.exec container [
    "rabbitmqadmin"; "declare"; "exchange";
    "name=events"; "type=topic"; "durable=true"
  ] in
  assert (code = 0);

  (* Declare queue *)
  let* (code, _) = Testcontainers.Container.exec container [
    "rabbitmqadmin"; "declare"; "queue";
    "name=user.events"; "durable=true"
  ] in
  assert (code = 0);

  (* Create binding *)
  let* (code, _) = Testcontainers.Container.exec container [
    "rabbitmqadmin"; "declare"; "binding";
    "source=events"; "destination=user.events";
    "routing_key=user.*"
  ] in
  assert (code = 0);

  Lwt.return_unit
```

### Using rabbitmqctl

```ocaml
let setup_with_rabbitmqctl container =
  (* Add user *)
  let* _ = Testcontainers.Container.exec container [
    "rabbitmqctl"; "add_user"; "appuser"; "apppass"
  ] in

  (* Set permissions *)
  let* _ = Testcontainers.Container.exec container [
    "rabbitmqctl"; "set_permissions"; "-p"; "/";
    "appuser"; ".*"; ".*"; ".*"
  ] in

  (* Add vhost *)
  let* _ = Testcontainers.Container.exec container [
    "rabbitmqctl"; "add_vhost"; "myapp"
  ] in

  Lwt.return_unit
```

## Publishing and Consuming Messages

### Publish Test Message

```ocaml
let publish_message container =
  let* (code, _) = Testcontainers.Container.exec container [
    "rabbitmqadmin"; "publish";
    "exchange=amq.default";
    "routing_key=test.queue";
    "payload=Hello from test!"
  ] in
  Lwt.return (code = 0)
```

### Get Message from Queue

```ocaml
let get_message container =
  let* (code, output) = Testcontainers.Container.exec container [
    "rabbitmqadmin"; "get"; "queue=test.queue"
  ] in
  Printf.printf "Message: %s\n" output;
  Lwt.return (code = 0)
```

### Check Queue Status

```ocaml
let check_queue_status container queue_name =
  let* (code, output) = Testcontainers.Container.exec container [
    "rabbitmqadmin"; "list"; "queues";
    "name"; "messages"; "consumers"
  ] in
  Printf.printf "Queues:\n%s\n" output;
  Lwt.return (code = 0)
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_rabbitmq

let with_test_rabbitmq f =
  Rabbitmq_container.with_rabbitmq
    ~config:(fun c -> c
      |> Rabbitmq_container.with_username "testuser"
      |> Rabbitmq_container.with_password "testpass")
    (fun container amqp_url ->
      (* Setup queue *)
      let* _ = Container.exec container [
        "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
        "declare"; "queue"; "name=test.queue"; "durable=false"
      ] in
      f container amqp_url
    )

let test_publish_consume _switch () =
  with_test_rabbitmq (fun container _amqp_url ->
    (* Publish message *)
    let* (code, _) = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "publish"; "routing_key=test.queue";
      "payload=Test message content"
    ] in
    Alcotest.(check int) "publish succeeds" 0 code;

    (* Consume message *)
    let* (code, output) = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "get"; "queue=test.queue"; "ackmode=ack_requeue_false"
    ] in
    Alcotest.(check int) "get succeeds" 0 code;
    Alcotest.(check bool) "has content" true
      (String.length output > 0);

    Lwt.return_unit
  )

let test_exchange_routing _switch () =
  with_test_rabbitmq (fun container _amqp_url ->
    (* Create topic exchange *)
    let* _ = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "declare"; "exchange"; "name=events"; "type=topic"
    ] in

    (* Create queues *)
    let* _ = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "declare"; "queue"; "name=user.created"
    ] in
    let* _ = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "declare"; "queue"; "name=user.deleted"
    ] in

    (* Bind queues *)
    let* _ = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "declare"; "binding";
      "source=events"; "destination=user.created";
      "routing_key=user.created"
    ] in

    (* Publish to exchange *)
    let* (code, _) = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "publish"; "exchange=events"; "routing_key=user.created";
      "payload={\"user_id\": 123}"
    ] in
    Alcotest.(check int) "publish succeeds" 0 code;

    (* Verify message routed correctly *)
    let* (code, output) = Container.exec container [
      "rabbitmqadmin"; "-u"; "testuser"; "-p"; "testpass";
      "get"; "queue=user.created"
    ] in
    Alcotest.(check int) "get succeeds" 0 code;
    Alcotest.(check bool) "message routed" true
      (String.length output > 0);

    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "RabbitMQ Tests" [
      "messaging", [
        Alcotest_lwt.test_case "publish/consume" `Slow test_publish_consume;
        Alcotest_lwt.test_case "exchange routing" `Slow test_exchange_routing;
      ];
    ]
  )
```

## Wait Strategy

RabbitMQ module waits for the broker to be fully started:

```ocaml
Wait_strategy.for_log "Server startup complete"
```

## Ports

| Port | Description |
|------|-------------|
| 5672 | AMQP |
| 15672 | Management UI (HTTP) |
| 15692 | Prometheus metrics |

## Troubleshooting

### Connection Refused on Port 5672

Ensure RabbitMQ is fully started:

```ocaml
(* Use with_rabbitmq which handles waiting *)
Rabbitmq_container.with_rabbitmq (fun container amqp_url ->
  (* Safe to connect here *)
  ...
)
```

### Authentication Failed

Check credentials match:

```ocaml
Rabbitmq_container.with_username "myuser"
|> Rabbitmq_container.with_password "mypass"

(* AMQP URL must use same credentials *)
```

### Virtual Host Not Found

Create vhost or use default:

```ocaml
(* Default vhost *)
Rabbitmq_container.with_vhost "/"

(* Or create custom vhost via rabbitmqctl *)
Container.exec container ["rabbitmqctl"; "add_vhost"; "myapp"]
```

### Slow Startup

RabbitMQ can take 10-30 seconds:

```ocaml
Container_request.with_startup_timeout 60.0
```

### Management Plugin Not Available

Use an image with management:

```ocaml
Rabbitmq_container.with_image "rabbitmq:3-management-alpine"
```
