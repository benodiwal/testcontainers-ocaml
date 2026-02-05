let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-mockserver"
       [ ("mockserver", Test_mockserver.suite) ])
