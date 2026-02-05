let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-mongo" [ ("mongo", Test_mongo.suite) ])
