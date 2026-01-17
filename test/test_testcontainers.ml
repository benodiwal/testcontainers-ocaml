(** Main test runner for testcontainers-ocaml

    Combines all test suites from individual test modules.

    Run all tests: dune runtest Run only unit tests: Set
    SKIP_INTEGRATION_TESTS=1 *)

let () =
  Lwt_main.run
    (Alcotest_lwt.run "Testcontainers"
       [
         (* Unit Tests *)
         ("port", Test_port.suite);
         ("volume", Test_volume.suite);
         ("container_request", Test_container_request.suite);
         ("wait_strategy", Test_wait_strategy.suite);
         ("error", Test_error.suite);
         (* Integration Tests - Docker Client *)
         ("docker_client", Test_docker_client.suite);
         (* Integration Tests - Container Lifecycle *)
         ("container", Test_container.suite);
         (* Integration Tests - File Copy *)
         ("file_copy", Test_file_copy.suite);
         (* Integration Tests - Networks *)
         ("network", Test_network.suite);
         (* Integration Tests - Wait Strategies *)
         ("wait_strategy_integration", Test_wait_strategy_integration.suite);
         (* Integration Tests - Modules *)
         ("postgres", Test_postgres.suite);
         ("redis", Test_redis.suite);
         ("rabbitmq", Test_rabbitmq.suite);
         ("mysql", Test_mysql.suite);
         ("mongo", Test_mongo.suite);
         ("kafka", Test_kafka.suite);
         ("elasticsearch", Test_elasticsearch.suite);
         ("localstack", Test_localstack.suite);
         ("memcached", Test_memcached.suite);
       ])
