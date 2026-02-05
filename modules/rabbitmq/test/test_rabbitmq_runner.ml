let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-rabbitmq"
       [ ("rabbitmq", Test_rabbitmq.suite) ])
