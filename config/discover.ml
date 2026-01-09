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
      let libs =
        if
          List.mem "-lmingw32" conf.libs
          (* Hack to remove "-mwindows" and "-lSDL2main" *)
        then
          List.filter (( <> ) "-mwindows") conf.libs
          |> List.filter (( <> ) "-lSDL2main")
        else conf.libs
      in
      C.Flags.write_sexp "c_library_flags.sexp" libs;
      C.Flags.write_sexp "c_flags.sexp" conf.cflags)
