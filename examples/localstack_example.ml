(** LocalStack example: Running AWS services locally for integration tests *)

open Lwt.Syntax
open Testcontainers_localstack

let () =
  Lwt_main.run
    begin
      Printf.printf "Starting LocalStack container...\n%!";

      Localstack_container.with_localstack
        ~config:(fun c ->
          c
          |> Localstack_container.with_services [ "s3"; "sqs"; "dynamodb" ]
          |> Localstack_container.with_region "us-east-1")
        (fun container endpoint ->
          Printf.printf "LocalStack is ready!\n%!";
          Printf.printf "Endpoint: %s\n%!" endpoint;

          let* host = Localstack_container.host container in
          let config =
            Localstack_container.create ()
            |> Localstack_container.with_services [ "s3"; "sqs"; "dynamodb" ]
          in
          let* port = Localstack_container.port config container in

          Printf.printf "Host: %s\n%!" host;
          Printf.printf "Port: %d\n%!" port;
          Printf.printf "Region: %s\n%!" (Localstack_container.region config);

          (* Here you would use AWS SDK with custom endpoint:

             Example with aws-s3:
             let credentials = Aws.Credentials.make ~access_key:"test" ~secret_key:"test" () in
             let config = Aws.Config.make ~credentials ~region:"us-east-1" ~endpoint () in
             let* result = Aws_s3.list_buckets config in
             ...

             For S3: endpoint ^ "/s3"
             For SQS: endpoint ^ "/sqs"
             For DynamoDB: endpoint ^ "/dynamodb"
          *)
          Printf.printf "Running LocalStack tests...\n%!";
          Lwt_unix.sleep 1.0)
    end;
  Printf.printf "LocalStack container cleaned up.\n"
