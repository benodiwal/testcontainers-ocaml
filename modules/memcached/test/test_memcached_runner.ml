let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-memcached"
       [ ("memcached", Test_memcached.suite) ])
