let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-kafka" [ ("kafka", Test_kafka.suite) ])
