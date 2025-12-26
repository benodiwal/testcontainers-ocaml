(** Integration tests for Network module *)

open Lwt.Syntax
open Testcontainers

let test_create_remove _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let* network = Network.create "test-network" in
    Alcotest.(check bool)
      "network id not empty" true
      (String.length (Network.id network) > 0);
    Alcotest.(check string) "network name" "test-network" (Network.name network);
    let* () = Network.remove network in
    Lwt.return_unit
  end

let test_with_network _switch () =
  if Test_helpers.skip_integration_tests () then Lwt.return_unit
  else begin
    let* () =
      Network.with_network "test-net-2" (fun network ->
          Alcotest.(check bool)
            "network id not empty" true
            (String.length (Network.id network) > 0);
          Lwt.return_unit)
    in
    Lwt.return_unit
  end

let suite =
  [
    Alcotest_lwt.test_case "create and remove" `Slow test_create_remove;
    Alcotest_lwt.test_case "with_network" `Slow test_with_network;
  ]
