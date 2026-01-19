# Elasticsearch

The Elasticsearch module provides a pre-configured Elasticsearch container for integration testing with full-text search and analytics.

## Quick Start

```ocaml
open Lwt.Syntax
open Testcontainers_elasticsearch

let test_elasticsearch () =
  Elasticsearch_container.with_elasticsearch (fun container url ->
    Printf.printf "Elasticsearch running at: %s\n" url;
    Lwt.return_unit
  )
```

## Installation

```bash
opam install testcontainers-elasticsearch
```

In your `dune` file:

```scheme
(libraries testcontainers-elasticsearch)
```

## Configuration

### Basic Usage

```ocaml
Elasticsearch_container.with_elasticsearch (fun container url ->
  (* url: "http://127.0.0.1:9200" *)
  ...
)
```

### Configuration Options

| Function | Default | Description |
|----------|---------|-------------|
| `with_image` | `elasticsearch:8.12.0` | Docker image |
| `with_password` | `changeme` | Elastic user password |

### Custom Configuration

```ocaml
Elasticsearch_container.with_elasticsearch
  ~config:(fun c -> c
    |> Elasticsearch_container.with_image "elasticsearch:7.17.0"
    |> Elasticsearch_container.with_password "mysecretpassword")
  (fun container url -> ...)
```

## Connection Details

### HTTP URL

```
http://127.0.0.1:9200
```

### Individual Components

```ocaml
Elasticsearch_container.with_elasticsearch (fun container url ->
  let* host = Elasticsearch_container.host container in  (* "127.0.0.1" *)
  let* port = Elasticsearch_container.port container in  (* 9200 *)
  ...
)
```

## Manual Lifecycle

```ocaml
let run_tests () =
  let config = Elasticsearch_container.create () in
  let* container = Elasticsearch_container.start config in
  let* url = Elasticsearch_container.url config container in

  (* Run tests... *)

  let* () = Testcontainers.Container.terminate container in
  Lwt.return_unit
```

## Index Operations

### Create an Index

```ocaml
let create_index container index_name =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    Printf.sprintf "http://localhost:9200/%s" index_name;
    "-H"; "Content-Type: application/json";
    "-d"; {|{"settings": {"number_of_shards": 1, "number_of_replicas": 0}}|}
  ] in
  Printf.printf "Create index response: %s\n" output;
  Lwt.return (exit_code = 0)
```

### Delete an Index

```ocaml
let delete_index container index_name =
  let* (exit_code, _) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "DELETE";
    Printf.sprintf "http://localhost:9200/%s" index_name
  ] in
  Lwt.return (exit_code = 0)
```

## Document Operations

### Index a Document

```ocaml
let index_document container index_name doc_id json_body =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "PUT";
    Printf.sprintf "http://localhost:9200/%s/_doc/%s" index_name doc_id;
    "-H"; "Content-Type: application/json";
    "-d"; json_body
  ] in
  Printf.printf "Index response: %s\n" output;
  Lwt.return (exit_code = 0)
```

### Get a Document

```ocaml
let get_document container index_name doc_id =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "curl"; "-s";
    Printf.sprintf "http://localhost:9200/%s/_doc/%s" index_name doc_id
  ] in
  Printf.printf "Document: %s\n" output;
  Lwt.return output
```

### Search Documents

```ocaml
let search container index_name query =
  let* (exit_code, output) = Testcontainers.Container.exec container [
    "curl"; "-s"; "-X"; "GET";
    Printf.sprintf "http://localhost:9200/%s/_search" index_name;
    "-H"; "Content-Type: application/json";
    "-d"; query
  ] in
  Printf.printf "Search results: %s\n" output;
  Lwt.return output
```

## Complete Test Example

```ocaml
open Lwt.Syntax
open Testcontainers
open Testcontainers_elasticsearch

let test_elasticsearch_crud _switch () =
  Elasticsearch_container.with_elasticsearch (fun container _url ->
    (* Create index *)
    let* (code, _) = Container.exec container [
      "curl"; "-s"; "-X"; "PUT"; "http://localhost:9200/products";
      "-H"; "Content-Type: application/json";
      "-d"; {|{"settings": {"number_of_shards": 1}}|}
    ] in
    Alcotest.(check int) "index created" 0 code;

    (* Index document *)
    let* (code, _) = Container.exec container [
      "curl"; "-s"; "-X"; "PUT"; "http://localhost:9200/products/_doc/1";
      "-H"; "Content-Type: application/json";
      "-d"; {|{"name": "OCaml Book", "price": 29.99, "category": "books"}|}
    ] in
    Alcotest.(check int) "document indexed" 0 code;

    (* Refresh index for immediate search *)
    let* _ = Container.exec container [
      "curl"; "-s"; "-X"; "POST"; "http://localhost:9200/products/_refresh"
    ] in

    (* Search *)
    let* (code, output) = Container.exec container [
      "curl"; "-s"; "http://localhost:9200/products/_search?q=name:OCaml"
    ] in
    Alcotest.(check int) "search succeeds" 0 code;
    Alcotest.(check bool) "found results" true (String.length output > 0);

    Lwt.return_unit
  )

let () =
  Lwt_main.run (
    Alcotest_lwt.run "Elasticsearch Tests" [
      "crud", [
        Alcotest_lwt.test_case "operations" `Slow test_elasticsearch_crud;
      ];
    ]
  )
```

## Wait Strategy

Elasticsearch uses an HTTP health check wait strategy:

```ocaml
Wait_strategy.for_http ~port:(Port.tcp 9200)
  ~status_codes:[200] "/_cluster/health?wait_for_status=yellow"
```

## Security Configuration

The module runs Elasticsearch with security disabled for easier testing:

```
xpack.security.enabled=false
```

For production-like testing with security enabled, use a custom container configuration.

## Performance Tips

### Single Node Setup

For faster tests, use single shard and no replicas:

```json
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  }
}
```

### Disable Refresh Interval

For bulk indexing tests:

```json
{
  "settings": {
    "refresh_interval": "-1"
  }
}
```

## Troubleshooting

### Container Startup Slow

Elasticsearch requires significant memory. Ensure Docker has at least 2GB RAM available.

### Search Returns No Results

Remember to refresh the index after indexing:

```ocaml
let* _ = Container.exec container [
  "curl"; "-s"; "-X"; "POST"; "http://localhost:9200/myindex/_refresh"
] in
```

### Connection Refused

Always use `with_elasticsearch` which waits for the cluster to be ready:

```ocaml
(* Good *)
Elasticsearch_container.with_elasticsearch (fun container url -> ...)
```
