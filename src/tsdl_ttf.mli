module Ttf : sig

(** SDL2_ttf bindings for use with Tsdl

    The UCS-2 Unicode bindings have been omitted; UCS-2 is obsolete,
    and the current implementation of SDL2_ttf converts such strings
    to UTF-8 before using them anyway.

    {{:https://www.libsdl.org/projects/SDL_ttf/docs/index.html}SDL2_ttf API}
*)

type 'a result = [ `Ok of 'a | `Error of string ]
(** The type for function results. In the [`Error] case,
    the string is what {!Tsdl.Sdl.get_error} returned. *)

val init : unit -> unit result
val quit : unit -> unit
val was_init : unit -> bool

type font
val close_font : font -> unit

val open_font : string -> int -> font option
val open_font_index : string -> int -> Signed.long -> font option
val open_font_rw : Tsdl.Sdl.rw_ops -> int -> int -> font option
val open_font_index_rw : Tsdl.Sdl.rw_ops -> int -> int -> Signed.long -> font option

module Style : sig
  type t
  val ( + ) : t -> t -> t
  val test : t -> t -> bool
  val eq : t -> t -> bool
  val normal : t
  val bold : t
  val italic : t
  val underline : t
  val strikethrough : t
end
val get_font_style : font -> Style.t
val set_font_style : font -> Style.t -> unit

val get_font_outline : font -> int
val set_font_outline : font -> int -> unit

module Hinting : sig
  type t = Normal | Light | Mono | None
end
val get_font_hinting : font -> Hinting.t
val set_font_hinting : font -> Hinting.t -> unit

val get_font_kerning_size :
  font -> int -> int -> int

val font_height : font -> int
val font_ascent : font -> int
val font_descent : font -> int
val font_line_skip : font -> int
val get_font_kerning : font -> bool
val set_font_kerning : font -> bool -> unit
val font_faces : font -> Signed.long
val font_face_is_fixed_width : font -> int
val font_face_family_name : font -> string
val font_face_style_name : font -> string
val glyph_is_provided : font -> Unsigned.uint16 -> bool

val glyph_metrics :
  font ->
  Unsigned.uint16 ->
  int Ctypes_static.ptr ->
  int Ctypes_static.ptr ->
  int Ctypes_static.ptr ->
  int Ctypes_static.ptr -> int Ctypes_static.ptr -> int

val size_text :
  font ->
  string -> int Ctypes_static.ptr -> int Ctypes_static.ptr -> int

val size_utf8 :
  font ->
  string -> int Ctypes_static.ptr -> int Ctypes_static.ptr -> int

val render_text_solid :
  font -> string -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_utf8_solid :
  font -> string -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_glyph_solid :
  font ->
  Unsigned.uint16 -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_text_shaded :
  font ->
  string -> Tsdl.Sdl.color -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_utf8_shaded :
  font ->
  string -> Tsdl.Sdl.color -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_glyph_shaded :
  font ->
  Unsigned.uint16 -> Tsdl.Sdl.color -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_text_blended :
  font ->
  string -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_utf8_blended :
  font ->
  string -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option
val render_text_blended_wrapped :
  font ->
  string -> Tsdl.Sdl.color -> Unsigned.uint32 -> Tsdl.Sdl.surface option
val render_utf8_blended_wrapped :
  font ->
  string -> Tsdl.Sdl.color -> Unsigned.uint32 -> Tsdl.Sdl.surface option
val render_glyph_blended :
  font ->
  Unsigned.uint16 -> Tsdl.Sdl.color -> Tsdl.Sdl.surface option

end