# LocalStack

The LocalStack module provides a pre-configured LocalStack container for testing AWS services locally without needing real AWS credentials.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_localstack

let test_localstack () =
  Localstack_container.with_localstack (fun container url ->
    Printf.printf "LocalStack running at: %s\n" url;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-localstack
```

In your `dune` file:

```scheme
(libraries testcontainers-localstack)
```

## Configuration

### Basic Usage

```ocaml
Localstack_container.with_localstack (fun container url ->
  (* url: "http://127.0.0.1:4566" *)
  ...
)
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `localstack/localstack:3.0` | Docker image |
| `with_services` | `["s3"]` | AWS services to enable |
| `with_region` | `us-east-1` | AWS region |

### Enable Multiple Services

```ocaml
Localstack_container.with_localstack
  ~config:(fun c -> c
    |> Localstack_container.with_services ["s3"; "sqs"; "dynamodb"; "lambda"])
  (fun container url -> ...)
```

### Custom Region

```ocaml
Localstack_container.with_localstack
  ~config:(fun c -> c
    |> Localstack_container.with_region "eu-west-1")
  (fun container url -> ...)
```

## Connection Details

### Endpoint URL

```
http://127.0.0.1:4566
```

All AWS services are available on this single endpoint.

### Individual Components

```ocaml
Localstack_container.with_localstack (fun container url ->
  let* host = Localstack_container.host container in  (* "127.0.0.1" *)
  let* port = Localstack_container.port container in  (* 4566 *)
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config =
    Localstack_container.create ()
    |> Localstack_container.with_services ["s3"; "sqs"]
  in
  let* container = Localstack_container.start config in
  let* url = Localstack_container.url config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## AWS CLI Examples

### S3 Operations

```ocaml
let test_s3 container =
  (* Create bucket *)
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "awslocal"; "s3"; "mb"; "s3://my-bucket"
  ] in
  assert (exit_code = 0);

  (* List buckets *)
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "awslocal"; "s3"; "ls"
  ] in
  Printf.printf "Buckets: %s\n" output;

  (* Upload file *)
  let* _ = Testcontainers.Container.exec container [
    "sh"; "-c"; "echo 'Hello S3!' > /tmp/test.txt"
  ] in
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "awslocal"; "s3"; "cp"; "/tmp/test.txt"; "s3://my-bucket/test.txt"
  ] in

  Lwt.return (exit_code = 0)
```

### SQS Operations

```ocaml
let test_sqs container =
  (* Create queue *)
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "awslocal"; "sqs"; "create-queue"; "--queue-name"; "my-queue"
  ] in
  Printf.printf "Queue created: %s\n" output;

  (* Send message *)
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "awslocal"; "sqs"; "send-message";
    "--queue-url"; "http://localhost:4566/000000000000/my-queue";
    "--message-body"; "Hello SQS!"
  ] in

  (* Receive messages *)
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "awslocal"; "sqs"; "receive-message";
    "--queue-url"; "http://localhost:4566/000000000000/my-queue"
  ] in
  Printf.printf "Received: %s\n" output;

  Lwt.return (exit_code = 0)
```

### DynamoDB Operations

```ocaml
let test_dynamodb container =
  (* Create table *)
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "awslocal"; "dynamodb"; "create-table";
    "--table-name"; "users";
    "--attribute-definitions"; "AttributeName=id,AttributeType=S";
    "--key-schema"; "AttributeName=id,KeyType=HASH";
    "--billing-mode"; "PAY_PER_REQUEST"
  ] in

  (* Put item *)
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "awslocal"; "dynamodb"; "put-item";
    "--table-name"; "users";
    "--item"; {|{"id": {"S": "1"}, "name": {"S": "Alice"}}|}
  ] in

  (* Get item *)
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "awslocal"; "dynamodb"; "get-item";
    "--table-name"; "users";
    "--key"; {|{"id": {"S": "1"}}|}
  ] in
  Printf.printf "Item: %s\n" output;

  Lwt.return (exit_code = 0)
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_localstack

let test_s3_bucket _switch () =
  Localstack_container.with_localstack
    ~config:(fun c -> Localstack_container.with_services ["s3"] c)
    (fun container _url ->
      (* Create bucket *)
      let* (code, _) = Container.exec container [
        "awslocal"; "s3"; "mb"; "s3://test-bucket"
      ] in
      Alcotest.(check int) "bucket created" 0 code;

      (* List buckets *)
      let* (code, output) = Container.exec container [
        "awslocal"; "s3"; "ls"
      ] in
      Alcotest.(check int) "list succeeds" 0 code;
      Alcotest.(check bool) "bucket in list" true
        (String.length output > 0);

      Lwt.return_unit
    )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "LocalStack Tests" [
      "s3", [
        Alcotest_lwt.test_case "bucket operations" `Slow test_s3_bucket;
      ];
    ]
  )
```

## Wait Strategy

LocalStack uses a log-based wait strategy:

```ocaml
Wait_strategy.for_log ~timeout:60.0 "Ready."
```

## Supported Services

LocalStack supports many AWS services including:

| Service | Description |
|---------|-------------|
| S3 | Object storage |
| SQS | Message queuing |
| SNS | Pub/sub messaging |
| DynamoDB | NoSQL database |
| Lambda | Serverless functions |
| API Gateway | REST APIs |
| CloudWatch | Monitoring |
| IAM | Identity management |
| KMS | Key management |
| Secrets Manager | Secrets storage |

## Using with AWS SDKs

Configure your AWS SDK to use the LocalStack endpoint:

```ocaml
(* Example configuration for aws-s3 library *)
let endpoint = url  (* "http://127.0.0.1:4566" *)
let region = "us-east-1"
let credentials = {
  access_key_id = "test";
  secret_access_key = "test";
}
```

## Troubleshooting

### Service Not Available

Ensure the service is enabled:

```ocaml
Localstack_container.with_services ["s3"; "sqs"; "dynamodb"]
```

### Slow Startup

LocalStack can take time to initialize all services. The wait strategy ensures readiness, but you can increase the timeout if needed.

### awslocal Command Not Found

The `awslocal` command is included in the LocalStack container. For external access, use the AWS CLI with the endpoint override:

```bash
aws --endpoint-url=http://localhost:4566 s3 ls
```
