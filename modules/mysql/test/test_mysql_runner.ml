let () =
  Lwt_main.run
    (Alcotest_lwt.run "testcontainers-mysql" [ ("mysql", Test_mysql.suite) ])
