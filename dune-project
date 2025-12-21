(lang dune 3.20)

(name testcontainers_ocaml)

(generate_opam_files true)

(source
 (github benodiwal/testcontainers_ocaml))

(authors "Sachin Beniwal <sachinbeniwal0101.com>")

(maintainers "Sachin Beniwal <sachinbeniwal0101.com>")

(license Apache-2.0)

(documentation https://url/to/documentation)

(package
 (name testcontainers_ocaml)
 (synopsis "Docker containers for OCaml integration tests")
 (description "TestContainers is an OCaml library that provides lightweight, throwaway
      instances of databases, message brokers, or any service that runs in a
      Docker container. Built on Eio for OCaml 5+, it enables reliable
      integration testing with real services instead of mocks.")
 (depends ocaml)
 (tags
  (docker testing integration-testing containers)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
