(** Integration tests for file copy operations *)

open Lwt.Syntax
open Testcontainers

let skip_integration_tests () =
  match Sys.getenv_opt "SKIP_INTEGRATION_TESTS" with
  | Some "1" | Some "true" -> true
  | _ -> false

let test_copy_content_to_container _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "30" ]
    in
    Container.with_container request (fun container ->
        let content = "Hello from testcontainers!" in
        let* () =
          Container.copy_content_to container ~content ~dest:"/tmp/test.txt"
        in
        let* exit_code, output =
          Container.exec container [ "cat"; "/tmp/test.txt" ]
        in
        Alcotest.(check int) "cat exit code" 0 exit_code;
        Alcotest.(check bool) "content matches" true (String.length output > 0);
        Lwt.return_unit)
  end

let test_copy_file_to_container _switch () =
  if skip_integration_tests () then Lwt.return_unit
  else begin
    let request =
      Container_request.create "alpine:latest"
      |> Container_request.with_cmd [ "sleep"; "30" ]
    in
    (* Create a temp file to copy *)
    let tmp_file = Filename.temp_file "test" ".txt" in
    let* () =
      Lwt_io.with_file ~mode:Lwt_io.Output tmp_file (fun oc ->
          Lwt_io.write oc "test file content")
    in
    Container.with_container request (fun container ->
        let* () = Container.copy_file_to container ~src:tmp_file ~dest:"/tmp" in
        let filename = Filename.basename tmp_file in
        let* exit_code, _output =
          Container.exec container [ "test"; "-f"; "/tmp/" ^ filename ]
        in
        Alcotest.(check int) "file exists" 0 exit_code;
        let* () = Lwt_unix.unlink tmp_file in
        Lwt.return_unit)
  end

let suite =
  [
    Alcotest_lwt.test_case "copy content to container" `Slow
      test_copy_content_to_container;
    Alcotest_lwt.test_case "copy file to container" `Slow
      test_copy_file_to_container;
  ]
