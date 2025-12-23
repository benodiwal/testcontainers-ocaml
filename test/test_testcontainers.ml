(* Testcontainers tests - placeholder *)

let () =
  Lwt_main.run
    (Alcotest_lwt.run "Testcontainers"
       [
         ( "placeholder",
           [
             Alcotest_lwt.test_case "passes" `Quick (fun _switch () ->
                 Lwt.return_unit);
           ] );
       ])
