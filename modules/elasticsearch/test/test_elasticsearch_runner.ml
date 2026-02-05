let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-elasticsearch"
       [ ("elasticsearch", Test_elasticsearch.suite) ])
