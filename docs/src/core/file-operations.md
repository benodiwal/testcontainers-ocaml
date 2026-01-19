# File Operations

Testcontainers OCaml supports copying files to and from containers. This is useful for:

- Providing configuration files
- Loading test fixtures
- Extracting logs or generated files
- Setting up initial database state

## Copying Content to Container

### String Content

Copy string content directly to a file in the container:

```ocaml
open Lwt.Syntax
open Testcontainers

let setup_config container =
  let config_content = {|
    server:
      port: 8080
      host: 0.0.0.0
    database:
      url: postgres://localhost/test
  |} in

  Container.copy_content_to container
    ~content:config_content
    ~dest:"/app/config.yaml"
```

The `dest` parameter is the full path including filename.

### Example: Custom nginx Configuration

```ocaml
let run_nginx_test () =
  let request =
    Container_request.create "nginx:alpine"
    |> Container_request.with_exposed_port (Port.tcp 80)
  in

  Container.with_container request (fun container ->
    (* Copy custom nginx config *)
    let nginx_conf = {|
      server {
        listen 80;
        location / {
          return 200 'Hello from test!';
          add_header Content-Type text/plain;
        }
      }
    |} in

    let* () = Container.copy_content_to container
      ~content:nginx_conf
      ~dest:"/etc/nginx/conf.d/default.conf"
    in

    (* Reload nginx to pick up new config *)
    let* _ = Container.exec container ["nginx"; "-s"; "reload"] in

    (* Now test the endpoint *)
    Lwt.return_unit
  )
```

## Copying Files to Container

Copy a file from the host filesystem:

```ocaml
let setup_test_data container =
  Container.copy_file_to container
    ~src:"/path/to/local/testdata.sql"
    ~dest:"/docker-entrypoint-initdb.d/"
```

### Example: Database Initialization

```ocaml
let test_with_seed_data () =
  let request =
    Container_request.create "postgres:16"
    |> Container_request.with_exposed_port (Port.tcp 5432)
    |> Container_request.with_env "POSTGRES_PASSWORD" "secret"
  in

  Container.with_container request (fun container ->
    (* Copy seed data *)
    let* () = Container.copy_file_to container
      ~src:"./test/fixtures/seed.sql"
      ~dest:"/tmp/"
    in

    (* Execute it *)
    let* (exit_code, output) = Container.exec container [
      "psql"; "-U"; "postgres"; "-f"; "/tmp/seed.sql"
    ] in

    if exit_code <> 0 then
      Printf.printf "Seed failed: %s\n" output;

    (* Run tests with seeded data *)
    Lwt.return_unit
  )
```

## Copying Directories to Container

Copy an entire directory from the host to the container:

```ocaml
let copy_test_fixtures container =
  Container.copy_dir_to container
    ~src:"/path/to/local/fixtures"
    ~dest:"/app"
```

The directory is copied with its contents. If `src` is `/path/to/fixtures`, the contents will appear at `/app/fixtures/` in the container.

### Example: Multi-file Configuration

```ocaml
let setup_app_config () =
  let request =
    Container_request.create "my-app:latest"
    |> Container_request.with_exposed_port (Port.tcp 8080)
  in

  Container.with_container request (fun container ->
    (* Copy entire config directory *)
    let* () = Container.copy_dir_to container
      ~src:"./config"
      ~dest:"/app"
    in

    (* Now /app/config/ contains all files from ./config *)
    Lwt.return_unit
  )
```

## Copying Files from Container

Extract files from a running container:

```ocaml
let extract_logs container =
  Container.copy_file_from container
    ~src:"/var/log/app.log"
    ~dest:"/tmp/test-app.log"
```

### Example: Extracting Test Artifacts

```ocaml
let test_with_artifacts () =
  Container.with_container request (fun container ->
    (* Run some process that generates output *)
    let* _ = Container.exec container [
      "sh"; "-c"; "my-tool --output /tmp/report.json"
    ] in

    (* Extract the generated report *)
    let* () = Container.copy_file_from container
      ~src:"/tmp/report.json"
      ~dest:"./test-output/report.json"
    in

    (* Parse and verify the report *)
    Lwt.return_unit
  )
```

## Common Patterns

### Configuration Injection

```ocaml
let with_configured_app config_json f =
  let request =
    Container_request.create "my-app:latest"
    |> Container_request.with_exposed_port (Port.tcp 8080)
  in

  Container.with_container request (fun container ->
    (* Inject configuration *)
    let* () = Container.copy_content_to container
      ~content:config_json
      ~dest:"/app/config.json"
    in

    (* Restart app to pick up config, or use signal *)
    let* _ = Container.exec container ["kill"; "-HUP"; "1"] in
    let* () = Lwt_unix.sleep 1.0 in

    f container
  )
```

### Test Fixtures

```ocaml
let copy_fixtures container fixtures_dir =
  let files = Sys.readdir fixtures_dir in
  Lwt_list.iter_s (fun file ->
    let src = Filename.concat fixtures_dir file in
    Container.copy_file_to container ~src ~dest:"/fixtures/"
  ) (Array.to_list files)
```

### Database Schema Setup

```ocaml
let setup_schema container =
  let schema = {|
    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) UNIQUE NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    );

    CREATE TABLE posts (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id),
      title VARCHAR(255) NOT NULL,
      body TEXT
    );
  |} in

  let* () = Container.copy_content_to container
    ~content:schema
    ~dest:"/tmp/schema.sql"
  in

  Container.exec container [
    "psql"; "-U"; "postgres"; "-d"; "testdb"; "-f"; "/tmp/schema.sql"
  ]
```

### SSL/TLS Certificates

```ocaml
let setup_tls container =
  (* Copy certificate files *)
  let* () = Container.copy_file_to container
    ~src:"./certs/server.crt"
    ~dest:"/etc/ssl/certs/"
  in
  let* () = Container.copy_file_to container
    ~src:"./certs/server.key"
    ~dest:"/etc/ssl/private/"
  in
  Lwt.return_unit
```

## Destination Paths

### File to Directory

If `dest` ends with `/`, the file keeps its original name:

```ocaml
(* Source: /local/myfile.txt *)
(* Dest:   /container/path/myfile.txt *)
Container.copy_file_to container
  ~src:"/local/myfile.txt"
  ~dest:"/container/path/"
```

### File to File (Rename)

If `dest` doesn't end with `/`, it's used as the full path:

```ocaml
(* Source: /local/myfile.txt *)
(* Dest:   /container/path/renamed.txt *)
Container.copy_file_to container
  ~src:"/local/myfile.txt"
  ~dest:"/container/path/renamed.txt"
```

### Content to File

For `copy_content_to`, `dest` must be the full file path:

```ocaml
Container.copy_content_to container
  ~content:"hello"
  ~dest:"/path/to/file.txt"  (* Full path required *)
```

## Error Handling

File operations can fail for various reasons:

```ocaml
let safe_copy container =
  Lwt.catch
    (fun () ->
      Container.copy_content_to container ~content:"test" ~dest:"/app/config"
    )
    (fun exn ->
      Printf.printf "Copy failed: %s\n" (Printexc.to_string exn);
      (* Maybe the directory doesn't exist, create it first *)
      let* _ = Container.exec container ["mkdir"; "-p"; "/app"] in
      Container.copy_content_to container ~content:"test" ~dest:"/app/config"
    )
```

## Platform Notes

### macOS

File operations work seamlessly with Docker Desktop on macOS. Extended attributes (like `com.apple.provenance`) are automatically handled.

### Linux

No special considerations. File operations use Docker's archive API directly.

### Windows

WSL2 backend recommended. File paths should use forward slashes in the container.
