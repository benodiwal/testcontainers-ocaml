# CI/CD Integration

This guide covers integrating Testcontainers OCaml with popular CI/CD platforms.

## GitHub Actions

### Basic Setup

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup OCaml
        uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: 5.1

      - name: Install dependencies
        run: |
          opam install . --deps-only --with-test
          opam install alcotest alcotest-lwt

      - name: Build
        run: opam exec -- dune build

      - name: Run tests
        run: opam exec -- dune runtest
```

### With Docker Image Caching

```yaml
name: Tests with Caching

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup OCaml
        uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: 5.1
          cache-prefix: v1

      - name: Cache Docker images
        uses: satackey/action-docker-layer-caching@v0.0.11
        continue-on-error: true

      - name: Pull Docker images
        run: |
          docker pull postgres:16-alpine &
          docker pull redis:7-alpine &
          docker pull mysql:8 &
          docker pull mongo:7 &
          docker pull rabbitmq:3-management-alpine &
          wait

      - name: Install dependencies
        run: opam install . --deps-only --with-test

      - name: Run tests
        run: opam exec -- dune runtest
        env:
          CONTAINER_TIMEOUT: "120"
```

### Matrix Testing

```yaml
name: Matrix Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ocaml-version: ['5.0', '5.1', '5.2']

    steps:
      - uses: actions/checkout@v4

      - name: Setup OCaml ${{ matrix.ocaml-version }}
        uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: ${{ matrix.ocaml-version }}

      - name: Install and test
        run: |
          opam install . --deps-only --with-test
          opam exec -- dune runtest
```

## GitLab CI

```yaml
# .gitlab-ci.yml
image: ocaml/opam:debian-ocaml-5.1

services:
  - docker:dind

variables:
  DOCKER_HOST: tcp://docker:2375

stages:
  - test

test:
  stage: test
  before_script:
    - opam install . --deps-only --with-test
  script:
    - opam exec -- dune build
    - opam exec -- dune runtest
  tags:
    - docker
```

## CircleCI

```yaml
# .circleci/config.yml
version: 2.1

jobs:
  test:
    docker:
      - image: ocaml/opam:debian-ocaml-5.1
    steps:
      - checkout
      - setup_remote_docker:
          docker_layer_caching: true
      - run:
          name: Install dependencies
          command: opam install . --deps-only --with-test
      - run:
          name: Run tests
          command: opam exec -- dune runtest

workflows:
  version: 2
  build-and-test:
    jobs:
      - test
```

## Docker-in-Docker Considerations

### Socket Mounting (Preferred)

Most CI systems support mounting the Docker socket:

```yaml
# GitHub Actions - works out of the box
# GitLab CI - use services: docker:dind
# CircleCI - use setup_remote_docker
```

### Environment Variables

```yaml
env:
  DOCKER_HOST: unix:///var/run/docker.sock  # Default
  # or for remote Docker
  DOCKER_HOST: tcp://docker:2375
```

## Test Configuration for CI

### Longer Timeouts

CI environments are often slower:

```ocaml
let ci_timeout =
  if Sys.getenv_opt "CI" = Some "true" then 120.0
  else 60.0

let request =
  Container_request.create "postgres:16"
  |> Container_request.with_startup_timeout ci_timeout
```

### Skip Resource-Intensive Tests

```ocaml
let skip_heavy_tests =
  Sys.getenv_opt "CI" = Some "true" &&
  Sys.getenv_opt "RUN_HEAVY_TESTS" <> Some "true"

let test_heavy_operation _switch () =
  if skip_heavy_tests then begin
    print_endline "Skipping heavy test in CI";
    Lwt.return_unit
  end else
    run_heavy_test ()
```

### Conditional Test Suites

```ocaml
let integration_tests =
  if Sys.getenv_opt "SKIP_INTEGRATION" = Some "true" then
    []
  else
    [
      Alcotest_lwt.test_case "postgres" `Slow test_postgres;
      Alcotest_lwt.test_case "redis" `Slow test_redis;
    ]

let () =
  Lwt_main.run (
    Alcotest_lwt.run "Tests" [
      ("unit", unit_tests);
      ("integration", integration_tests);
    ]
  )
```

## Debugging CI Failures

### Verbose Output

```yaml
- name: Run tests (verbose)
  run: opam exec -- dune runtest --force --verbose
```

### Container Logs on Failure

```ocaml
let test_with_ci_debug _switch () =
  Lwt.catch
    (fun () ->
      Container.with_container request (fun container ->
        run_test container))
    (fun exn ->
      if Sys.getenv_opt "CI" = Some "true" then begin
        (* In CI, print more debug info *)
        Printf.printf "Test failed in CI\n";
        Printf.printf "Exception: %s\n" (Printexc.to_string exn)
      end;
      Lwt.fail exn)
```

### Artifacts

```yaml
# GitHub Actions
- name: Run tests
  run: opam exec -- dune runtest
  continue-on-error: true

- name: Upload test results
  uses: actions/upload-artifact@v3
  if: always()
  with:
    name: test-results
    path: _build/default/test/_build/_tests/
```

## Performance in CI

### Parallel Jobs

```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - run: opam exec -- dune runtest test/unit

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - run: opam exec -- dune runtest test/integration

  e2e-tests:
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
    steps:
      - run: opam exec -- dune runtest test/e2e
```

### Image Pre-warming

```yaml
- name: Pre-warm Docker cache
  run: |
    # Pull images in parallel
    docker pull postgres:16-alpine &
    docker pull redis:7-alpine &
    docker pull nginx:alpine &
    wait
```

## Security Considerations

### Secrets Management

```yaml
- name: Run tests
  run: opam exec -- dune runtest
  env:
    # Don't use production credentials
    TEST_DB_PASSWORD: ${{ secrets.TEST_DB_PASSWORD }}
```

### Network Isolation

```yaml
# Tests run in isolated Docker network by default
# No additional configuration needed
```

## Complete CI Example

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: 5.1
      - run: opam install ocamlformat
      - run: opam exec -- dune build @fmt

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: 5.1
      - run: opam install . --deps-only
      - run: opam exec -- dune build

  unit-tests:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: 5.1
      - run: opam install . --deps-only --with-test
      - run: SKIP_INTEGRATION_TESTS=1 opam exec -- dune runtest

  integration-tests:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: 5.1
      - run: |
          docker pull postgres:16-alpine
          docker pull redis:7-alpine
      - run: opam install . --deps-only --with-test
      - run: opam exec -- dune runtest
        env:
          CONTAINER_TIMEOUT: "120"

  docs:
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - run: |
          cargo install mdbook
          cd docs && mdbook build
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs/book
```
