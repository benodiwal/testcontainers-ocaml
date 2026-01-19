(lang dune 3.20)

(name testcontainers)

(generate_opam_files true)

(source
 (github benodiwal/testcontainers_ocaml))

(authors "Sachin Beniwal <sachinbeniwal0101@gmail.com>")

(maintainers "Sachin Beniwal <sachinbeniwal0101@gmail.com>")

(license Apache-2.0)

(documentation https://benodiwal.github.io/testcontainers_ocaml)

(package
 (name testcontainers)
 (synopsis "Docker containers for OCaml integration tests")
 (description
  "TestContainers is an OCaml library that provides lightweight, throwaway
   instances of databases, message brokers, or any service that runs in a
   Docker container. Enables reliable integration testing with real services
   instead of mocks.")
 (depends
  (ocaml (>= 5.0))
  (dune (>= 3.20))
  (lwt (>= 5.7.0))
  (lwt_ppx (>= 2.1.0))
  (yojson (>= 2.0))
  (re (>= 1.11.0))
  (uri (>= 4.0))
  (logs (>= 0.7.0))
  (fmt (>= 0.9.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0))))
 (tags
  (docker testing integration-testing containers testcontainers)))

(package
 (name testcontainers-postgres)
 (synopsis "PostgreSQL module for testcontainers")
 (description "PostgreSQL container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-redis)
 (synopsis "Redis module for testcontainers")
 (description "Redis container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-rabbitmq)
 (synopsis "RabbitMQ module for testcontainers")
 (description "RabbitMQ container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-mysql)
 (synopsis "MySQL module for testcontainers")
 (description "MySQL container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-mongo)
 (synopsis "MongoDB module for testcontainers")
 (description "MongoDB container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-kafka)
 (synopsis "Kafka module for testcontainers")
 (description "Apache Kafka container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-elasticsearch)
 (synopsis "Elasticsearch module for testcontainers")
 (description "Elasticsearch container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-localstack)
 (synopsis "LocalStack module for testcontainers")
 (description "LocalStack (AWS emulation) container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-memcached)
 (synopsis "Memcached module for testcontainers")
 (description "Memcached container module for testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))

(package
 (name testcontainers-mockserver)
 (synopsis "MockServer module for testcontainers")
 (description "MockServer container module for mocking HTTP services in testcontainers-ocaml")
 (depends
  (testcontainers (= :version))
  (lwt_ppx (>= 2.1.0))
  (alcotest (and :with-test (>= 1.7.0)))
  (alcotest-lwt (and :with-test (>= 1.7.0)))))
