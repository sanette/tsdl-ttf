(** Simple dynamic library loader for ctypes-based bindings *)

val load :
  ?env:string list ->
  ?debug:bool ->
  name:string ->
  string list ->
  Dl.library option
(** [load ?env ?debug ~name candidates] tries to load a dynamic library.

    - [name] is used for diagnostics only (e.g. "SDL2")
    - [candidates] is a list of filenames / paths to try
    - if [env] is provided and the environment variable exists, its value is
      tried first
    - if [debug] is true, detailed errors are printed

    Returns [Some handle] on success, [None] on failure. *)
