let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-localstack"
       [ ("localstack", Test_localstack.suite) ])
