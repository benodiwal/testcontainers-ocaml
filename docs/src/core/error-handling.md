# Error Handling

Testcontainers OCaml uses a combination of Lwt-based error handling and a custom exception type for container-related errors.

## Error Types

All Testcontainers errors are wrapped in the `Testcontainers_error` exception:

```ocaml
exception Testcontainers_error of Error.t
```

The `Error.t` type covers all possible failure scenarios:

```ocaml
type t =
  | Container_not_found of string
  | Container_not_running of string
  | Container_start_failed of { id : string; message : string }
  | Container_stop_failed of { id : string; message : string }
  | Wait_timeout of { strategy : string; timeout : float }
  | Docker_error of { status : int; message : string }
  | Docker_connection_failed of string
  | Invalid_configuration of string
  | Image_pull_failed of { image : string; message : string }
  | Port_not_mapped of { container_port : int; protocol : string }
```

## Converting Errors to Strings

```ocaml
let handle_error err =
  let message = Error.to_string err in
  Printf.printf "Error: %s\n" message
```

Example outputs:

```
Container not found: abc123def456
Failed to start container abc123: port already allocated
Wait strategy 'port:5432/tcp' timed out after 60.0s
Docker API error (status 404): No such image: invalid:latest
Port 8080/tcp not mapped
```

## Catching Errors

### Basic Pattern

```ocaml
open Lwt.Syntax

let run_test () =
  Lwt.catch
    (fun () ->
      Container.with_container request (fun container ->
        (* test code *)
        Lwt.return_unit
      ))
    (function
      | Error.Testcontainers_error err ->
          Printf.printf "Testcontainers error: %s\n" (Error.to_string err);
          Lwt.return_unit
      | exn ->
          Printf.printf "Other error: %s\n" (Printexc.to_string exn);
          Lwt.return_unit)
```

### Handling Specific Errors

```ocaml
let run_with_retry () =
  Lwt.catch
    (fun () -> Container.start request)
    (function
      | Error.Testcontainers_error (Error.Image_pull_failed { image; message }) ->
          Printf.printf "Failed to pull %s: %s\n" image message;
          Printf.printf "Trying with local image...\n";
          let local_request = Container_request.with_image "local:latest" request in
          Container.start local_request

      | Error.Testcontainers_error (Error.Wait_timeout { strategy; timeout }) ->
          Printf.printf "Wait strategy '%s' timed out after %.1fs\n" strategy timeout;
          Lwt.fail_with "Container not ready"

      | Error.Testcontainers_error (Error.Docker_connection_failed msg) ->
          Printf.printf "Cannot connect to Docker: %s\n" msg;
          Printf.printf "Is Docker running?\n";
          Lwt.fail_with "Docker not available"

      | exn ->
          Lwt.fail exn)
```

## Common Error Scenarios

### Docker Not Running

```ocaml
(* Error: Docker_connection_failed "Connection refused" *)

(* Solution: Start Docker *)
(* docker info *)
```

### Image Not Found

```ocaml
(* Error: Image_pull_failed { image = "invalid:tag"; message = "not found" } *)

(* Solution: Check image name/tag *)
let request = Container_request.create "postgres:16"  (* valid tag *)
```

### Port Not Exposed

```ocaml
(* Error: Port_not_mapped { container_port = 5432; protocol = "tcp" } *)

(* Solution: Expose the port *)
let request =
  Container_request.create "postgres:16"
  |> Container_request.with_exposed_port (Port.tcp 5432)  (* add this *)
```

### Wait Strategy Timeout

```ocaml
(* Error: Wait_timeout { strategy = "log:ready"; timeout = 60.0 } *)

(* Solutions: *)

(* 1. Increase timeout *)
Wait_strategy.with_timeout 120.0 strategy

(* 2. Use correct wait condition *)
Wait_strategy.for_log "database system is ready"  (* exact message *)

(* 3. Check container logs for actual startup message *)
let* logs = Container.logs container in
print_endline logs
```

### Container Start Failed

```ocaml
(* Error: Container_start_failed { id = "abc"; message = "port already allocated" } *)

(* Solutions: *)

(* 1. Remove conflicting container *)
(* docker ps -a *)
(* docker rm -f <container_id> *)

(* 2. Use random port mapping (default behavior) *)
Container_request.with_exposed_port (Port.tcp 5432)  (* Docker assigns random host port *)
```

## Ensuring Cleanup on Error

`with_container` ensures cleanup even on errors:

```ocaml
let test_that_fails () =
  Container.with_container request (fun container ->
    (* This error won't leak the container *)
    failwith "Test failed"
  )
  (* Container is still cleaned up *)
```

For manual lifecycle management, use `Lwt.finalize`:

```ocaml
let test_with_manual_cleanup () =
  let* container = Container.start request in
  Lwt.finalize
    (fun () ->
      (* Test code that might fail *)
      do_something container)
    (fun () ->
      (* Always runs, even on error *)
      Container.terminate container)
```

## Debugging Tips

### Enable Verbose Logging

```ocaml
let debug_container container =
  let* logs = Container.logs container in
  Printf.printf "=== Container Logs ===\n%s\n" logs;

  let* state = Container.state container in
  Printf.printf "State: %s\n" (match state with
    | `Running -> "running"
    | `Exited -> "exited"
    | _ -> "other");

  Lwt.return_unit
```

### Check Docker Directly

```bash
# List containers
docker ps -a

# Check specific container
docker logs <container_id>
docker inspect <container_id>

# Check Docker events
docker events --since 1h
```

### Inspect Failed Container

Don't terminate failed containers immediately—inspect them first:

```ocaml
let debug_on_failure () =
  let* container = Container.start request in
  Lwt.catch
    (fun () ->
      run_tests container)
    (fun exn ->
      (* Debug before cleanup *)
      let* logs = Container.logs container in
      Printf.printf "Container logs:\n%s\n" logs;

      let id = Container.id container in
      Printf.printf "Container ID: %s\n" id;
      Printf.printf "Inspect with: docker inspect %s\n" id;

      (* Optionally, don't terminate to allow manual inspection *)
      (* let* () = Container.terminate container in *)

      Lwt.fail exn)
```

## Testing Error Handling

```ocaml
let test_handles_docker_errors _switch () =
  (* Test with invalid image *)
  let request = Container_request.create "this-image-does-not-exist:never" in

  Lwt.catch
    (fun () ->
      let* _container = Container.start request in
      Alcotest.fail "Should have failed")
    (function
      | Error.Testcontainers_error (Error.Image_pull_failed _) ->
          Lwt.return_unit  (* Expected *)
      | exn ->
          Alcotest.fail (Printf.sprintf "Wrong error: %s" (Printexc.to_string exn)))
```
