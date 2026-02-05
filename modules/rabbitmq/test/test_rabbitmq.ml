(** Tests for RabbitMQ module *)

open Lwt.Syntax

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let string_starts_with ~prefix s =
  let plen = String.length prefix in
  String.length s >= plen && String.sub s 0 plen = prefix

let test_config _switch () =
  let config =
    Testcontainers_rabbitmq.Rabbitmq_container.create ()
    |> Testcontainers_rabbitmq.Rabbitmq_container.with_username "admin"
    |> Testcontainers_rabbitmq.Rabbitmq_container.with_password "secret"
    |> Testcontainers_rabbitmq.Rabbitmq_container.with_vhost "/test"
  in
  Alcotest.(check string)
    "username" "admin"
    (Testcontainers_rabbitmq.Rabbitmq_container.username config);
  Alcotest.(check string)
    "vhost" "/test"
    (Testcontainers_rabbitmq.Rabbitmq_container.vhost config);
  Lwt.return_unit

let test_container _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    Testcontainers_rabbitmq.Rabbitmq_container.with_rabbitmq
      (fun container amqp_url ->
        Alcotest.(check bool)
          "amqp url not empty" true
          (String.length amqp_url > 0);
        Alcotest.(check bool)
          "amqp url contains amqp://" true
          (string_starts_with ~prefix:"amqp://" amqp_url);
        let* host = Testcontainers_rabbitmq.Rabbitmq_container.host container in
        Alcotest.(check string) "host is localhost" "127.0.0.1" host;
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "config" `Quick test_config;
    Alcotest_lwt.test_case "container" `Slow test_container;
  ]
