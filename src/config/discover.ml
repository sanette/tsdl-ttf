module C = Configurator.V1

let c_source =
  {|
#define _GNU_SOURCE
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
#include <link.h>
#include <string.h>

static int find_sdl2_ttf_cb(struct dl_phdr_info *info, size_t size, void *data)
{
    if (strstr(info->dlpi_name, "SDL2_ttf")) {
        *(const char **)data = info->dlpi_name;
        return 1;
    }
    return 0;
}

static const char *find_sdl2_ttf_path(void)
{
    const char *path = NULL;
    dl_iterate_phdr(find_sdl2_ttf_cb, &path);
    return path;
}
#elif defined(_WIN32)
#include <windows.h>

static const char *find_sdl2_ttf_path(void)
{
    static char path[MAX_PATH];
    HMODULE h = GetModuleHandle("SDL2_ttf.dll");
    if (h && GetModuleFileName(h, path, MAX_PATH))
        return path;
    return NULL;
}
#else
static const char *find_sdl2_ttf_path(void) { return NULL; }
#endif

int main(void)
{
    const SDL_version *v = TTF_Linked_Version();
    const char *path = find_sdl2_ttf_path();
    if (path)
        printf("let library_path = Some \"%s\"\n", path);
    else
        printf("let library_path = None\n");
    printf("let version = Some (%d, %d, %d)\n", v->major, v->minor, v->patch);
    return 0;
}
|}

let none_module () =
  print_string "let library_path = None\nlet version = None\n"

(* Note: this uses GCC-style compiler invocation (-o, -l flags) and sh-style
   shell redirection (2>/dev/null). This works with GCC, Clang, and MinGW on
   Windows, but not with MSVC (cl.exe), which uses different flag syntax
   (/Fe: for output, .lib suffixes for libraries) and cmd.exe redirection.
   MSVC is not supported here; the probe will fail gracefully and return None. *)
let compile_and_run c conf =
  let cc = Option.value ~default:"cc" (C.ocaml_config_var c "c_compiler") in
  let is_windows = Sys.os_type = "Win32" in
  let devnull = if is_windows then "nul" else "/dev/null" in
  let c_file = Filename.temp_file "discover" ".c" in
  let exe_file =
    Filename.temp_file "discover" (if is_windows then ".exe" else "")
  in
  let out_file = Filename.temp_file "discover_out" ".txt" in
  let cleanup () =
    List.iter
      (fun f -> try Sys.remove f with _ -> ())
      [ c_file; exe_file; out_file ]
  in
  let oc = open_out c_file in
  output_string oc c_source;
  close_out oc;
  let compile_cmd =
    Printf.sprintf "%s %s %s -o %s %s 2>%s" cc
      (String.concat " " conf.C.Pkg_config.cflags)
      c_file exe_file
      (String.concat " " conf.C.Pkg_config.libs)
      devnull
  in
  let run_cmd = Printf.sprintf "%s > %s" exe_file out_file in
  let compile_ok = Sys.command compile_cmd = 0 in
  if not compile_ok then
    prerr_endline ("sdl2-ttf-discover: probe compilation failed: " ^ compile_cmd);
  let run_ok = compile_ok && Sys.command run_cmd = 0 in
  if compile_ok && not run_ok then
    prerr_endline ("sdl2-ttf-discover: probe execution failed: " ^ run_cmd);
  let success = compile_ok && run_ok in
  if success then begin
    let ic = open_in out_file in
    let output = In_channel.input_all ic in
    close_in ic;
    print_string output;
    prerr_endline ("sdl2-ttf-discover: " ^ String.trim output)
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
      if not (compile_and_run c conf) then begin
        prerr_endline
          "sdl2-ttf-discover: could not detect SDL2_ttf library path, \
           falling back to runtime heuristics";
        none_module ()
      end)
