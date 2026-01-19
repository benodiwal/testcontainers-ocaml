# MockServer

The MockServer module provides a pre-configured MockServer container for mocking HTTP/HTTPS services in integration tests.

## Quick Start

```ocaml
open Testcontainers_mockserver

let test_mockserver () =
  Mockserver_container.with_mockserver (fun container url ->
    Printf.printf "MockServer running at: %s\n" url;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-mockserver
```

In your `dune` file:

```scheme
(libraries testcontainers-mockserver)
```

## Configuration

### Basic Usage

```ocaml
Mockserver_container.with_mockserver (fun container url ->
  (* url: "http://127.0.0.1:1080" *)
  ...
)
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `mockserver/mockserver:5.15.0` | Docker image |
| `with_log_level` | `INFO` | Log level (INFO, DEBUG, TRACE, WARN, ERROR) |
| `with_max_expectations` | None | Maximum number of expectations |

### Custom Configuration

```ocaml
Mockserver_container.with_mockserver
  ~config:(fun c -> c
    |> Mockserver_container.with_log_level "DEBUG"
    |> Mockserver_container.with_max_expectations 100)
  (fun container url -> ...)
```

## Connection Details

### HTTP URL

```
http://127.0.0.1:1080
```

### Individual Components

```ocaml
Mockserver_container.with_mockserver (fun container url ->
  let* host = Mockserver_container.host container in  (* "127.0.0.1" *)
  let* port = Mockserver_container.port config container in  (* 1080 *)
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config =
    Mockserver_container.create ()
    |> Mockserver_container.with_log_level "DEBUG"
  in
  let* container = Mockserver_container.start config in
  let* url = Mockserver_container.url config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Creating Expectations

### Simple Expectation

```ocaml
let create_expectation container =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/expectation";
    "-H"; "Content-Type: application/json";
    "-d"; {|{
      "httpRequest": {
        "method": "GET",
        "path": "/api/hello"
      },
      "httpResponse": {
        "statusCode": 200,
        "body": "Hello World!"
      }
    }|}
  ] in
  Lwt.return (exit_code = 0)
```

### Expectation with Headers

```ocaml
let create_expectation_with_headers container =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/expectation";
    "-H"; "Content-Type: application/json";
    "-d"; {|{
      "httpRequest": {
        "method": "GET",
        "path": "/api/user",
        "headers": {
          "Authorization": ["Bearer token123"]
        }
      },
      "httpResponse": {
        "statusCode": 200,
        "headers": {
          "Content-Type": ["application/json"]
        },
        "body": "{\"name\": \"Alice\", \"id\": 1}"
      }
    }|}
  ] in
  Lwt.return (exit_code = 0)
```

### POST Request Expectation

```ocaml
let create_post_expectation container =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/expectation";
    "-H"; "Content-Type: application/json";
    "-d"; {|{
      "httpRequest": {
        "method": "POST",
        "path": "/api/users",
        "body": {
          "type": "JSON",
          "json": {"name": "Bob"}
        }
      },
      "httpResponse": {
        "statusCode": 201,
        "body": "{\"id\": 2, \"name\": \"Bob\"}"
      }
    }|}
  ] in
  Lwt.return (exit_code = 0)
```

## Testing the Mock

### Make a Request

```ocaml
let test_mock container =
  (* First create the expectation *)
  let* _ = create_expectation container in

  (* Then test it *)
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "curl"; "-s"; "http://localhost:1080/api/hello"
  ] in
  Printf.printf "Response: %s\n" output;
  Lwt.return (exit_code = 0 && output = "Hello World!")
```

## Verification

### Verify Request Was Made

```ocaml
let verify_request container =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/verify";
    "-H"; "Content-Type: application/json";
    "-d"; {|{
      "httpRequest": {
        "method": "GET",
        "path": "/api/hello"
      },
      "times": {
        "atLeast": 1
      }
    }|}
  ] in
  Lwt.return (exit_code = 0)
```

## Clearing Expectations

### Clear All Expectations

```ocaml
let clear_all container =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/clear"
  ] in
  Lwt.return (exit_code = 0)
```

### Reset MockServer

```ocaml
let reset container =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/reset"
  ] in
  Lwt.return (exit_code = 0)
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_mockserver

let test_api_mock _switch () =
  Mockserver_container.with_mockserver (fun container url ->
    (* Create expectation *)
    let* (code, _) = Container.exec container [
      "curl"; "-s"; "-X"; "PUT";
      "http://localhost:1080/mockserver/expectation";
      "-H"; "Content-Type: application/json";
      "-d"; {|{
        "httpRequest": {"path": "/api/users/1"},
        "httpResponse": {
          "statusCode": 200,
          "body": "{\"id\": 1, \"name\": \"Alice\"}"
        }
      }|}
    ] in
    Alcotest.(check int) "expectation created" 0 code;

    (* Test the mock *)
    let* (code, output) = Container.exec container [
      "curl"; "-s"; "http://localhost:1080/api/users/1"
    ] in
    Alcotest.(check int) "request succeeds" 0 code;
    Alcotest.(check bool) "has response" true
      (String.length output > 0);

    (* Verify the request was made *)
    let* (code, _) = Container.exec container [
      "curl"; "-s"; "-X"; "PUT";
      "http://localhost:1080/mockserver/verify";
      "-H"; "Content-Type: application/json";
      "-d"; {|{
        "httpRequest": {"path": "/api/users/1"},
        "times": {"atLeast": 1}
      }|}
    ] in
    Alcotest.(check int) "verification passes" 0 code;

    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "MockServer Tests" [
      "api", [
        Alcotest_lwt.test_case "mock endpoints" `Slow test_api_mock;
      ];
    ]
  )
```

## Wait Strategy

MockServer uses a log-based wait strategy:

```ocaml
Wait_strategy.for_log ~timeout:60.0 "started on port"
```

## Use Cases

### Testing External API Dependencies

Mock external APIs your application depends on:

```ocaml
(* Mock a payment gateway *)
let mock_payment_api container =
  let* _ = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/expectation";
    "-H"; "Content-Type: application/json";
    "-d"; {|{
      "httpRequest": {
        "method": "POST",
        "path": "/v1/charges"
      },
      "httpResponse": {
        "statusCode": 200,
        "body": "{\"id\": \"ch_123\", \"status\": \"succeeded\"}"
      }
    }|}
  ] in
  Lwt.return_unit
```

### Testing Error Handling

```ocaml
(* Mock error responses *)
let mock_error_response container =
  let* _ = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/expectation";
    "-H"; "Content-Type: application/json";
    "-d"; {|{
      "httpRequest": {"path": "/api/fail"},
      "httpResponse": {
        "statusCode": 500,
        "body": "{\"error\": \"Internal Server Error\"}"
      }
    }|}
  ] in
  Lwt.return_unit
```

### Testing Timeouts

```ocaml
(* Mock slow response *)
let mock_slow_response container =
  let* _ = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    "http://localhost:1080/mockserver/expectation";
    "-H"; "Content-Type: application/json";
    "-d"; {|{
      "httpRequest": {"path": "/api/slow"},
      "httpResponse": {
        "statusCode": 200,
        "delay": {"timeUnit": "SECONDS", "value": 5}
      }
    }|}
  ] in
  Lwt.return_unit
```

## Troubleshooting

### Expectation Not Matching

Check that the request matches exactly:
- HTTP method
- Path
- Headers (if specified)
- Body (if specified)

Enable DEBUG logging for more details:

```ocaml
Mockserver_container.with_log_level "DEBUG"
```

### Connection Refused

Always use `with_mockserver` which waits for the server to be ready:

```ocaml
(* Good *)
Mockserver_container.with_mockserver (fun container url -> ...)
```

### Multiple Expectations

MockServer matches expectations in order. Put more specific expectations before general ones.
