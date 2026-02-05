let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-postgres"
       [ ("postgres", Test_postgres.suite) ])
