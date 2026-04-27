module C = Configurator.V1

let c_source =
  {|
#include <stdio.h>
#include <SDL2/SDL_ttf.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#include <string.h>

static const char *find_sdl2_ttf_path(void)
{
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "SDL2_ttf"))
            return name;
    }
    return NULL;
}
#elif defined(__unix__)
#include <dlfcn.h>

static const char *find_sdl2_ttf_path(void)
{
    Dl_info info;
    if (dladdr((void *)TTF_Init, &info) && info.dli_fname)
        return info.dli_fname;
    return NULL;
}
#else
static const char *find_sdl2_ttf_path(void) { return NULL; }
#endif

int main(void)
{
    const char *path = find_sdl2_ttf_path();
    if (path)
        printf("let library_path = Some \"%s\"\n", path);
    else
        printf("let library_path = None\n");
    printf("let version = Some (%d, %d, %d)\n",
           SDL_TTF_MAJOR_VERSION, SDL_TTF_MINOR_VERSION, SDL_TTF_PATCHLEVEL);
    return 0;
}
|}

let none_module () =
  print_string "let library_path = None\nlet version = None\n"

let compile_and_run c conf =
  let cc = Option.value ~default:"cc" (C.ocaml_config_var c "c_compiler") in
  let extra_link_flags =
    match C.ocaml_config_var c "system" with
    | Some "macosx" -> []
    | _ -> [ "-ldl" ]
  in
  let c_file = Filename.temp_file "discover" ".c" in
  let exe_file = Filename.temp_file "discover" "" in
  let out_file = Filename.temp_file "discover_out" ".txt" in
  let cleanup () =
    List.iter (fun f -> try Sys.remove f with _ -> ()) [ c_file; exe_file; out_file ]
  in
  let oc = open_out c_file in
  output_string oc c_source;
  close_out oc;
  let compile_cmd =
    Printf.sprintf "%s %s %s -o %s %s %s 2>/dev/null" cc
      (String.concat " " conf.C.Pkg_config.cflags)
      c_file exe_file
      (String.concat " " conf.C.Pkg_config.libs)
      (String.concat " " extra_link_flags)
  in
  let run_cmd = Printf.sprintf "%s > %s 2>/dev/null" exe_file out_file in
  let success =
    Sys.command compile_cmd = 0 && Sys.command run_cmd = 0
  in
  if success then begin
    let ic = open_in out_file in
    (try while true do print_char (input_char ic) done with End_of_file -> ());
    close_in ic
  end;
  cleanup ();
  success

let () =
  C.main ~name:"sdl2-ttf-discover" (fun c ->
      let default : C.Pkg_config.package_conf =
        { libs = [ "-lSDL2_ttf" ]; cflags = [] }
      in
      let conf =
        match C.Pkg_config.get c with
        | None -> default
        | Some pc -> (
            match C.Pkg_config.query pc ~package:"SDL2_ttf" with
            | None -> default
            | Some deps -> deps)
      in
      if not (compile_and_run c conf) then none_module ())
