open Printf

let default_flags = Dl.[ RTLD_NOW; RTLD_GLOBAL ]

let load ?(env = []) ?(debug = false) ~name candidates =
  let flags = default_flags in

  let candidates =
    List.fold_left
      (fun list var ->
        match Sys.getenv_opt var with Some path -> path :: list | None -> list)
      candidates env
  in

  let errors = ref [] in

  let rec try_all = function
    | [] -> None
    | filename :: rest -> (
        try Some (Dl.dlopen ~flags ~filename)
        with exn ->
          errors := (filename, exn) :: !errors;
          try_all rest)
  in

  match try_all candidates with
  | Some h -> Some h
  | None ->
      if debug then begin
        prerr_endline (sprintf "dynlib: could not load %s." name);
        prerr_endline "dynlib: tried:";
        List.iter
          (fun (file, exn) ->
            prerr_endline (sprintf "  - %s (%s)" file (Printexc.to_string exn)))
          (List.rev !errors);
        match env with
        | [] -> ()
        | [ var ] ->
            prerr_endline
              (sprintf
                 "You may use the %s environement variable to specify the %s \
                  library file."
                 var name)
        | list ->
            prerr_endline
              (sprintf
                 "You may use one of the [%s] environement variables to \
                  specify the %s library file."
                 (String.concat "," list) name)
      end;
      None
