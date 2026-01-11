open Ctypes
open Foreign
open Tsdl

module Ttf = struct
  type 'a result = 'a Sdl.result

  (* Set [debug] to true to print the foreign symbols in the CI. Don't forget to
     set this to false before release. *)
  let debug = true
  let pre = if debug then print_endline else ignore
  let error () = Error (`Msg (Sdl.get_error ()))

  let zero_to_ok =
    let read = function 0 -> Ok () | _err -> error () in
    view ~read ~write:(fun _ -> assert false) int

  let bool =
    let read = function 0 -> false | _ -> true in
    let write = function true -> 1 | false -> 0 in
    view ~read ~write int

  let int32_as_uint32_t =
    view ~read:Unsigned.UInt32.to_int32 ~write:Unsigned.UInt32.of_int32 uint32_t

  let int64_as_long =
    view ~read:Signed.Long.to_int64 ~write:Signed.Long.of_int64 long

  (* let surface =
   *   view ~read:Sdl.unsafe_surface_of_ptr ~write:Sdl.unsafe_ptr_of_surface nativeint *)
  let surface_result =
    let read v =
      if Nativeint.(compare v zero) = 0 then error ()
      else Ok (Sdl.unsafe_surface_of_ptr v)
    and write = function
      | Error _ -> raw_address_of_ptr @@ null
      | Ok s -> Sdl.unsafe_ptr_of_surface s
    in
    view ~read ~write nativeint

  let rw_ops =
    view ~read:Sdl.unsafe_rw_ops_of_ptr ~write:Sdl.unsafe_ptr_of_rw_ops
      nativeint

  type _font
  type font = _font structure ptr

  let font_struct : _font structure typ = structure "TTF_Font"
  let font : _font structure ptr typ = ptr font_struct
  let font_opt : _font structure ptr option typ = ptr_opt font_struct

  let font_result =
    let read = function None -> error () | Some v -> Ok v
    and write = function Error _ -> None | Ok s -> Some s in
    view ~read ~write font_opt

  (* pkg-config --variable=libdir SDL2_ttf *)
  (* Use Configurator.V1.Pkg_config instead? *)
  let pkg_config () =
    try
      let ic = Unix.open_process_in "pkg-config --variable=libdir SDL2_ttf" in
      let dir = input_line ic in
      close_in ic;
      Some dir
    with _ -> None

  (* This "hack" seems to be necessary for linux if you want to use
     #require "tsdl-ttf"
     in the toplevel, see
     https://github.com/ocamllabs/ocaml-ctypes/issues/70 *)
  let from : Dl.library option =
    (if debug then
       Sdl.(
         log_info Log.category_system "Loading Sdl_ttf, Target = %s"
           Build_config.system));
    let env = try Sys.getenv "LIBSDL2_PATH" with Not_found -> "" in
    let filename, path =
      match Build_config.system with
      | "macosx" -> ("libSDL2_ttf-2.0.0.dylib", [ "/opt/homebrew/lib/" ])
      | "win32" | "win64" ->
          (* On native Windows DLLs are loaded from the PATH *)
          ("SDL2_ttf.dll", [ "" ])
      | "cygwin" | "mingw" | "mingw64" ->
          (* For Windows POSIX emulators (Cygwin and MSYS2), hardcoded
             locations are available in addition to the PATH *)
          ( "SDL2_ttf.dll",
            [
              "";
              "/usr/x86_64-w64-mingw32/sys-root/mingw/bin";
              "/usr/i686-w64-mingw32/sys-root/mingw/bin";
              "/clangarm64/bin";
              "/clang64/bin";
              "/clang32/bin";
              "/ucrt64/bin";
              "/mingw64/bin";
              "/mingw32/bin";
            ] )
      | _ ->
          ( "libSDL2_ttf-2.0.so.0",
            [ "/usr/lib/x86_64-linux-gnu/"; "/usr/local/lib" ] )
    in
    let rec loop = function
      | [] -> None
      | dir :: rest -> (
          let filename =
            if dir = "" then filename else Filename.concat dir filename
          in
          try Some Dl.(dlopen ~filename ~flags:[ RTLD_NOW ])
          with _ -> loop rest)
    in
    match loop (env :: path) with
    | Some f -> Some f
    | None -> (
        (* We execute pkg_config only if everything else failed. *)
        match pkg_config () with
        | Some dir -> loop [ dir ]
        | None ->
            print_endline
              ("Cannot find " ^ filename ^ ", please set LIBSDL2_PATH");
            None)

  let foreign = foreign ?from

  let init =
    pre "TTF_Init";
    foreign "TTF_Init" (void @-> returning zero_to_ok)

  let version = structure "SDL_version"
  let version_major = field version "major" uint8_t
  let version_minor = field version "minor" uint8_t
  let version_patch = field version "patch" uint8_t
  let () = seal version

  let linked_version =
    pre "TTF_Linked_Version";
    foreign "TTF_Linked_Version" (void @-> returning (ptr version))

  let linked_version () =
    let get v f = Unsigned.UInt8.to_int (getf v f) in
    let v = linked_version () in
    let v = !@v in
    (get v version_major, get v version_minor, get v version_patch)

  let version = linked_version ()

  let () =
    if debug then
      let a, b, c = version in
      Sdl.log "SDL_ttf Version (%u,%u,%u)" a b c

  let open_font =
    pre "TTF_OpenFont";
    foreign "TTF_OpenFont" (string @-> int @-> returning font_result)

  let open_font_index =
    pre "TTF_OpenFontIndex";
    foreign "TTF_OpenFontIndex"
      (string @-> int @-> int64_as_long @-> returning font_result)

  let open_font_rw =
    pre "TTF_OpenFontRW";
    foreign "TTF_OpenFontRW" (rw_ops @-> int @-> int @-> returning font_result)

  let open_font_index_rw =
    pre "TTF_OpenFontIndexRW";
    foreign "TTF_OpenFontIndexRW"
      (rw_ops @-> int @-> int @-> int64_as_long @-> returning font_result)

  (* let byte_swapped_unicode =
   *   pre "TTF_ByteSwappedUNICODE"; foreign "TTF_ByteSwappedUNICODE" (int @-> returning void) *)

  module Style = struct
    type t = Unsigned.uint32

    let i = Unsigned.UInt32.of_int
    let ( + ) = Unsigned.UInt32.logor
    let ( - ) st flag = Unsigned.UInt32.(logand st (lognot flag))
    let test f m = Unsigned.UInt32.(compare (logand f m) zero <> 0)
    let eq f f' = Unsigned.UInt32.(compare f f' = 0)
    let normal = i 0
    let bold = i 1
    let italic = i 2
    let underline = i 4
    let strikethrough = i 8
  end

  let get_font_style =
    pre "TTF_GetFontStyle";
    foreign "TTF_GetFontStyle" (font @-> returning uint32_t)

  let set_font_style =
    pre "TTF_SetFontStyle";
    foreign "TTF_SetFontStyle" (font @-> uint32_t @-> returning void)

  let get_font_outline =
    pre "TTF_GetFontOutline";
    foreign "TTF_GetFontOutline" (font @-> returning int)

  let set_font_outline =
    pre "TTF_SetFontOutline";
    foreign "TTF_SetFontOutline" (font @-> int @-> returning void)

  module Hinting = struct
    type t = Normal | Light | Mono | None

    let t =
      let read = function
        | 0 -> Normal
        | 1 -> Light
        | 2 -> Mono
        | 3 -> None
        | _ -> failwith "Unexpected value"
      in
      let write = function Normal -> 0 | Light -> 1 | Mono -> 2 | None -> 3 in
      view ~read ~write int
  end

  let get_font_hinting =
    pre "TTF_GetFontHinting";
    foreign "TTF_GetFontHinting" (font @-> returning Hinting.t)

  let set_font_hinting =
    pre "TTF_SetFontHinting";
    foreign "TTF_SetFontHinting" (font @-> Hinting.t @-> returning void)

  let font_height =
    pre "TTF_FontHeight";
    foreign "TTF_FontHeight" (font @-> returning int)

  let font_ascent =
    pre "TTF_FontAscent";
    foreign "TTF_FontAscent" (font @-> returning int)

  let font_descent =
    pre "TTF_FontDescent";
    foreign "TTF_FontDescent" (font @-> returning int)

  let font_line_skip =
    pre "TTF_FontLineSkip";
    foreign "TTF_FontLineSkip" (font @-> returning int)

  let get_font_kerning =
    pre "TTF_GetFontKerning";
    foreign "TTF_GetFontKerning" (font @-> returning bool)

  let set_font_kerning =
    pre "TTF_SetFontKerning";
    foreign "TTF_SetFontKerning" (font @-> bool @-> returning void)

  let font_faces =
    pre "TTF_FontFaces";
    foreign "TTF_FontFaces" (font @-> returning int64_as_long)

  let font_face_is_fixed_width =
    pre "TTF_FontFaceIsFixedWidth";
    foreign "TTF_FontFaceIsFixedWidth" (font @-> returning int)

  let font_face_family_name =
    pre "TTF_FontFaceFamilyName";
    foreign "TTF_FontFaceFamilyName" (font @-> returning string)

  let font_face_style_name =
    pre "TTF_FontFaceStyleName";
    foreign "TTF_FontFaceStyleName" (font @-> returning string)

  let glyph_ucs2 =
    view ~read:Unsigned.UInt16.to_int ~write:Unsigned.UInt16.of_int uint16_t

  let glyph_32 =
    view ~read:Unsigned.UInt32.to_int ~write:Unsigned.UInt32.of_int uint32_t

  let glyph_is_provided =
    pre "TTF_GlyphIsProvided";
    foreign "TTF_GlyphIsProvided" (font @-> glyph_ucs2 @-> returning bool)

  let glyph_is_provided32 =
    pre "TTF_GlyphIsProvided32";
    if version >= (2, 0, 18) then
      foreign "TTF_GlyphIsProvided32" (font @-> glyph_32 @-> returning bool)
    else fun _ ->
      failwith "TTF_GlyphIsProvided32 not implemented (need SDL_ttf >= 2.0.18)"

  module GlyphMetrics = struct
    type t = {
      min_x : int;
      max_x : int;
      min_y : int;
      max_y : int;
      advance : int;
    }
  end

  let glyph_metrics =
    pre "TTF_GlyphMetrics";
    foreign "TTF_GlyphMetrics"
      (font
      @-> glyph_ucs2
      @-> ptr int
      @-> ptr int
      @-> ptr int
      @-> ptr int
      @-> ptr int
      @-> returning int)

  let glyph_metrics f g =
    let min_x, max_x, min_y, max_y, advance =
      ( allocate int 0,
        allocate int 0,
        allocate int 0,
        allocate int 0,
        allocate int 0 )
    in
    if 0 = glyph_metrics f g min_x max_x min_y max_y advance then
      Ok
        GlyphMetrics.
          {
            min_x = !@min_x;
            max_x = !@max_x;
            min_y = !@min_y;
            max_y = !@max_y;
            advance = !@advance;
          }
    else error ()

  let size_text =
    pre "TTF_SizeText";
    foreign "TTF_SizeText"
      (font @-> string @-> ptr int @-> ptr int @-> returning int)

  let size_text f s =
    let w, h = (allocate int 0, allocate int 0) in
    if 0 = size_text f s w h then Ok (!@w, !@h) else error ()

  let size_utf8 =
    pre "TTF_SizeUTF8";
    foreign "TTF_SizeUTF8"
      (font @-> string @-> ptr int @-> ptr int @-> returning int)

  let size_utf8 f s =
    let w, h = (allocate int 0, allocate int 0) in
    if 0 = size_utf8 f s w h then Ok (!@w, !@h) else error ()

  (* let size_unicode =
   *   pre "TTF_SizeUNICODE"; foreign "TTF_SizeUNICODE" (font @-> ptr glyph_ucs2 @-> ptr int @-> ptr int @-> returning int) *)

  type _color
  type color = _color structure

  let color : color typ = structure "SDL_Color"
  let color_r = field color "r" uint8_t
  let color_g = field color "g" uint8_t
  let color_b = field color "b" uint8_t
  let color_a = field color "a" uint8_t
  let () = seal color

  let color =
    let read v =
      let r, g, b, a =
        Unsigned.UInt8.
          ( to_int @@ getf v color_r,
            to_int @@ getf v color_g,
            to_int @@ getf v color_b,
            to_int @@ getf v color_a )
      in
      Sdl.Color.create ~r ~g ~b ~a
    in
    let write v =
      let c = make color in
      setf c color_r (Unsigned.UInt8.of_int (Sdl.Color.r v));
      setf c color_g (Unsigned.UInt8.of_int (Sdl.Color.g v));
      setf c color_b (Unsigned.UInt8.of_int (Sdl.Color.b v));
      setf c color_a (Unsigned.UInt8.of_int (Sdl.Color.a v));
      c
    in
    view ~read ~write color

  let render_text_solid =
    pre "TTF_RenderText_Solid";
    foreign "TTF_RenderText_Solid"
      (font @-> string @-> color @-> returning surface_result)

  let render_utf8_solid =
    pre "TTF_RenderUTF8_Solid";
    foreign "TTF_RenderUTF8_Solid"
      (font @-> string @-> color @-> returning surface_result)
  (* let render_unicode_solid = pre "TTF_RenderUNICODE_Solid"; foreign "TTF_RenderUNICODE_Solid" (font @-> ptr glyph_ucs2 @-> color @-> returning surface_result) *)

  let render_glyph_solid =
    pre "TTF_RenderGlyph_Solid";
    foreign "TTF_RenderGlyph_Solid"
      (font @-> glyph_ucs2 @-> color @-> returning surface_result)

  let render_glyph32_solid =
    pre "TTF_RenderGlyph32_Solid";
    if version >= (2, 0, 18) then
      foreign "TTF_RenderGlyph32_Solid"
        (font @-> glyph_32 @-> color @-> returning surface_result)
    else fun _ ->
      failwith
        "TTF_RenderGlyph32_Solid not implemented (need SDL_ttf >= 2.0.18)"

  let render_text_shaded =
    pre "TTF_RenderText_Shaded";
    foreign "TTF_RenderText_Shaded"
      (font @-> string @-> color @-> color @-> returning surface_result)

  let render_utf8_shaded =
    pre "TTF_RenderUTF8_Shaded";
    foreign "TTF_RenderUTF8_Shaded"
      (font @-> string @-> color @-> color @-> returning surface_result)
  (* let render_unicode_shaded = pre "TTF_RenderUNICODE_Shaded"; foreign "TTF_RenderUNICODE_Shaded" (font @-> ptr glyph_ucs2 @-> color @-> color @-> returning surface_result) *)

  let render_glyph_shaded =
    pre "TTF_RenderGlyph_Shaded";
    foreign "TTF_RenderGlyph_Shaded"
      (font @-> glyph_ucs2 @-> color @-> color @-> returning surface_result)

  let render_glyph32_shaded =
    pre "TTF_RenderGlyph32_Shaded";
    if version >= (2, 0, 18) then
      foreign "TTF_RenderGlyph32_Shaded"
        (font @-> glyph_32 @-> color @-> color @-> returning surface_result)
    else fun _ ->
      failwith
        "TTF_RenderGlyph32_Shaded not implemented (need SDL_ttf >= 2.0.18)"

  let render_text_blended =
    pre "TTF_RenderText_Blended";
    foreign "TTF_RenderText_Blended"
      (font @-> string @-> color @-> returning surface_result)

  let render_utf8_blended =
    pre "TTF_RenderUTF8_Blended";
    foreign "TTF_RenderUTF8_Blended"
      (font @-> string @-> color @-> returning surface_result)
  (* let render_unicode_blended = pre "TTF_RenderUNICODE_Blended"; foreign "TTF_RenderUNICODE_Blended" (font @-> ptr glyph_ucs2 @-> color @-> returning surface_result) *)

  let render_text_blended_wrapped =
    pre "TTF_RenderText_Blended_Wrapped";
    foreign "TTF_RenderText_Blended_Wrapped"
      (font
      @-> string
      @-> color
      @-> int32_as_uint32_t
      @-> returning surface_result)

  let render_utf8_blended_wrapped =
    pre "TTF_RenderUTF8_Blended_Wrapped";
    foreign "TTF_RenderUTF8_Blended_Wrapped"
      (font
      @-> string
      @-> color
      @-> int32_as_uint32_t
      @-> returning surface_result)
  (* let render_unicode_blended_wrapped = pre "TTF_RenderUNICODE_Blended_Wrapped"; foreign "TTF_RenderUNICODE_Blended_Wrapped" (font @-> ptr glyph_ucs2 @-> color @-> int32_as_uint32_t @-> returning surface_result) *)

  let render_glyph_blended =
    pre "TTF_RenderGlyph_Blended";
    foreign "TTF_RenderGlyph_Blended"
      (font @-> glyph_ucs2 @-> color @-> returning surface_result)

  let render_glyph32_blended =
    pre "TTF_RenderGlyph32_Blended";
    if version >= (2, 0, 18) then
      foreign "TTF_RenderGlyph32_Blended"
        (font @-> glyph_32 @-> color @-> returning surface_result)
    else fun _ ->
      failwith
        "TTF_RenderGlyph32_Blended not implemented (need SDL_ttf >= 2.0.18)"

  let close_font =
    pre "TTF_CloseFont";
    foreign "TTF_CloseFont" (font @-> returning void)

  let quit =
    pre "TTF_Quit";
    foreign "TTF_Quit" (void @-> returning void)

  let was_init =
    pre "TTF_WasInit";
    foreign "TTF_WasInit" (void @-> returning bool)

  let get_font_kerning_size =
    pre "TTF_GetFontKerningSize";
    foreign "TTF_GetFontKerningSize" (font @-> int @-> int @-> returning int)
end
