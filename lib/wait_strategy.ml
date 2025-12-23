(** Wait strategies for container readiness detection *)

open Lwt.Syntax

type context = {
  container_id : string;
  host : string;
  get_mapped_port : Port.exposed_port -> int Lwt.t;
  get_logs : unit -> string Lwt.t;
  exec : string list -> (int * string) Lwt.t;
}

type strategy_fn = context -> unit Lwt.t

type t = {
  name : string;
  timeout : float;
  poll_interval : float;
  strategy : strategy_fn;
}

let default_timeout = 60.0
let default_poll_interval = 0.5

let make ~name ~strategy =
  { name; timeout = default_timeout; poll_interval = default_poll_interval; strategy }

let with_timeout timeout t =
  { t with timeout }

let with_poll_interval interval t =
  { t with poll_interval = interval }

let name t = t.name
let timeout t = t.timeout

(* Helper to poll until condition is met or timeout *)
let poll_until ~timeout ~interval ~check =
  let start_time = Unix.gettimeofday () in
  let rec loop () =
    let elapsed = Unix.gettimeofday () -. start_time in
    if elapsed >= timeout then
      Lwt.return_false
    else
      let* result = check () in
      if result then
        Lwt.return_true
      else begin
        let* () = Lwt_unix.sleep interval in
        loop ()
      end
  in
  loop ()

(* Wait for a TCP port to be listening *)
let for_listening_port ?(timeout = default_timeout) port =
  let strategy ctx =
    let* host_port = ctx.get_mapped_port port in
    let check () =
      Lwt.catch
        (fun () ->
          let addr = Unix.ADDR_INET (Unix.inet_addr_loopback, host_port) in
          let sock = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
          Lwt.finalize
            (fun () ->
              let* () = Lwt_unix.connect sock addr in
              Lwt.return_true)
            (fun () -> Lwt_unix.close sock))
        (fun _ -> Lwt.return_false)
    in
    let* success = poll_until ~timeout ~interval:default_poll_interval ~check in
    if success then
      Lwt.return_unit
    else
      Error.fail_wait_timeout ~strategy:(Printf.sprintf "listening_port(%d)" port.Port.port) ~timeout
  in
  make ~name:(Printf.sprintf "listening_port(%s)" (Port.to_string port)) ~strategy
  |> with_timeout timeout

(* Wait for a specific log message *)
let for_log ?(occurrence = 1) ?(timeout = default_timeout) message =
  let strategy ctx =
    let check () =
      let* logs = ctx.get_logs () in
      let count = ref 0 in
      let idx = ref 0 in
      while !idx < String.length logs && !count < occurrence do
        match String.index_from_opt logs !idx message.[0] with
        | None -> idx := String.length logs
        | Some pos ->
            if pos + String.length message <= String.length logs then begin
              let substr = String.sub logs pos (String.length message) in
              if substr = message then begin
                incr count;
                idx := pos + String.length message
              end else
                idx := pos + 1
            end else
              idx := String.length logs
      done;
      Lwt.return (!count >= occurrence)
    in
    let* success = poll_until ~timeout ~interval:default_poll_interval ~check in
    if success then
      Lwt.return_unit
    else
      Error.fail_wait_timeout ~strategy:(Printf.sprintf "log(%s)" message) ~timeout
  in
  make ~name:(Printf.sprintf "log(%s, occurrence=%d)" message occurrence) ~strategy
  |> with_timeout timeout

(* Wait for a log message matching a regex *)
let for_log_regex ?(occurrence = 1) ?(timeout = default_timeout) pattern =
  let regex = Re.Pcre.regexp pattern in
  let strategy ctx =
    let check () =
      let* logs = ctx.get_logs () in
      let matches = Re.all regex logs in
      Lwt.return (List.length matches >= occurrence)
    in
    let* success = poll_until ~timeout ~interval:default_poll_interval ~check in
    if success then
      Lwt.return_unit
    else
      Error.fail_wait_timeout ~strategy:(Printf.sprintf "log_regex(%s)" pattern) ~timeout
  in
  make ~name:(Printf.sprintf "log_regex(%s, occurrence=%d)" pattern occurrence) ~strategy
  |> with_timeout timeout

(* Simple HTTP request for health checks *)
let http_get host port path =
  let sock = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Lwt.finalize
    (fun () ->
      let addr = Unix.ADDR_INET (Unix.inet_addr_of_string host, port) in
      let* () = Lwt_unix.connect sock addr in
      let request = Printf.sprintf "GET %s HTTP/1.1\r\nHost: %s:%d\r\nConnection: close\r\n\r\n"
        path host port in
      let ic = Lwt_io.of_fd ~mode:Lwt_io.Input sock in
      let oc = Lwt_io.of_fd ~mode:Lwt_io.Output sock in
      let* () = Lwt_io.write oc request in
      let* () = Lwt_io.flush oc in
      let* status_line = Lwt_io.read_line ic in
      let status_code =
        try
          let parts = String.split_on_char ' ' status_line in
          int_of_string (List.nth parts 1)
        with _ -> 0
      in
      Lwt.return status_code)
    (fun () -> Lwt_unix.close sock)

(* Wait for HTTP endpoint to return expected status *)
let for_http ?(port = Port.tcp 80) ?(status_codes = [200]) ?(timeout = default_timeout)
    ?method_:_ path =
  let strategy ctx =
    let* host_port = ctx.get_mapped_port port in
    let check () =
      Lwt.catch
        (fun () ->
          let* status = http_get ctx.host host_port path in
          Lwt.return (List.mem status status_codes))
        (fun _ -> Lwt.return_false)
    in
    let* success = poll_until ~timeout ~interval:default_poll_interval ~check in
    if success then
      Lwt.return_unit
    else
      Error.fail_wait_timeout ~strategy:(Printf.sprintf "http(%s)" path) ~timeout
  in
  make ~name:(Printf.sprintf "http(%s)" path) ~strategy
  |> with_timeout timeout

(* Wait for command execution to return expected exit code *)
let for_exec ?(timeout = default_timeout) ?(exit_code = 0) cmd =
  let strategy ctx =
    let check () =
      Lwt.catch
        (fun () ->
          let* (actual_code, _output) = ctx.exec cmd in
          Lwt.return (actual_code = exit_code))
        (fun _ -> Lwt.return_false)
    in
    let* success = poll_until ~timeout ~interval:default_poll_interval ~check in
    if success then
      Lwt.return_unit
    else
      Error.fail_wait_timeout ~strategy:(Printf.sprintf "exec(%s)" (String.concat " " cmd)) ~timeout
  in
  make ~name:(Printf.sprintf "exec(%s)" (String.concat " " cmd)) ~strategy
  |> with_timeout timeout

(* Wait for Docker health check to pass *)
let for_health_check ?(timeout = default_timeout) () =
  let strategy ctx =
    let check () =
      let* info = Docker_client.inspect_container ctx.container_id in
      Lwt.return (info.state.status = "healthy" || info.state.running)
    in
    let* success = poll_until ~timeout ~interval:default_poll_interval ~check in
    if success then
      Lwt.return_unit
    else
      Error.fail_wait_timeout ~strategy:"health_check" ~timeout
  in
  make ~name:"health_check" ~strategy
  |> with_timeout timeout

(* Combinator: all strategies must pass *)
let all strategies =
  let combined_strategy ctx =
    Lwt_list.iter_s (fun s -> s.strategy ctx) strategies
  in
  let names = List.map (fun s -> s.name) strategies in
  make ~name:(Printf.sprintf "all(%s)" (String.concat ", " names)) ~strategy:combined_strategy

(* Combinator: any strategy passing is sufficient *)
let any strategies =
  let combined_strategy ctx =
    let* results = Lwt_list.map_p (fun s ->
      Lwt.catch
        (fun () ->
          let* () = s.strategy ctx in
          Lwt.return_true)
        (fun _ -> Lwt.return_false)
    ) strategies in
    if List.exists Fun.id results then
      Lwt.return_unit
    else
      Error.fail_wait_timeout ~strategy:"any" ~timeout:0.0
  in
  let names = List.map (fun s -> s.name) strategies in
  make ~name:(Printf.sprintf "any(%s)" (String.concat ", " names)) ~strategy:combined_strategy

(* No-op wait strategy *)
let none =
  make ~name:"none" ~strategy:(fun _ -> Lwt.return_unit)

(* Execute wait strategy *)
let wait ctx strategy =
  strategy.strategy ctx
