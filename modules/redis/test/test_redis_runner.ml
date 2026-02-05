let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-redis" [ ("redis", Test_redis.suite) ])
