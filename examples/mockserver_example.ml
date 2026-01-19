(** MockServer example - demonstrates mocking HTTP services *)

open Testcontainers_mockserver

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting MockServer container...\n%!";
      Mockserver_container.with_mockserver
        ~config:(fun c -> Mockserver_container.with_log_level "INFO" c)
        (fun _container url ->
          Printf.printf "MockServer is running at: %s\n%!" url;
          Printf.printf
            "You can now configure expectations via the MockServer API\n%!";
          Printf.printf "\nExample curl commands:\n%!";
          Printf.printf "  # Create an expectation\n%!";
          Printf.printf "  curl -X PUT '%s/mockserver/expectation' \\\n%!" url;
          Printf.printf "    -H 'Content-Type: application/json' \\\n%!";
          Printf.printf
            "    -d '{\"httpRequest\": {\"path\": \"/hello\"}, \
             \"httpResponse\": {\"body\": \"Hello World!\"}}'\n\
             %!";
          Printf.printf "\n  # Test the mock endpoint\n%!";
          Printf.printf "  curl '%s/hello'\n%!" url;
          Printf.printf "\nContainer cleaned up automatically.\n%!";
          Lwt.return_unit)
    end
