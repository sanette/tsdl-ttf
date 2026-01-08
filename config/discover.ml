module C = Configurator.V1

let () =
  let package = "SDL2_ttf" in
  C.main ~name:"foo" (fun c ->
      let default : C.Pkg_config.package_conf =
        { libs = [ "-l" ^ package ]; cflags = [] }
      in
      let conf =
        match C.Pkg_config.get c with
        | None -> default
        | Some pc -> (
            match C.Pkg_config.query pc ~package with
            | None -> default
            | Some deps -> deps)
      in
      let cflags = if List.mem "-lmingw32" conf.cflags
          (* Hack to add "-link" before "-mwindows" if it's not already
             there: *)
        then let rec loop acc link = function
            | [] -> List.rev acc
            | "-mwindows" :: rest when not link ->
              List.rev_append acc (("-link") :: ("-mwindows") :: rest)
            | "-link" :: rest -> loop ("-link" :: acc) true rest
            | a :: rest -> loop (a :: acc) false rest in
          loop [] false conf.cflags
        else conf.cflags in
      C.Flags.write_sexp "c_library_flags.sexp" conf.libs;
      C.Flags.write_sexp "c_flags.sexp" cflags)
