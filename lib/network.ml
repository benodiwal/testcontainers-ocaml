(** Docker network management *)

open Lwt.Syntax

type t = { id : string; name : string }

let id t = t.id
let name t = t.name

let create ?(driver = "bridge") name =
  let* response = Docker_client.create_network ~driver name in
  Lwt.return { id = response; name }

let remove t = Docker_client.remove_network t.id

let with_network ?driver name f =
  let* network = create ?driver name in
  Lwt.finalize (fun () -> f network) (fun () -> remove network)
