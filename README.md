tsdl-ttf — SDL2\_ttf bindings for OCaml with Tsdl
---------------------------------------------------

Tsdl\_ttf provides bindings to
[SDL2_ttf](https://wiki.libsdl.org/SDL2_ttf/) intended to
be used with [Tsdl](http://erratique.ch/software/tsdl).

It has as siblings [tsdl-image](https://github.com/sanette/tsdl-image)
and [tsdl-mixer](https://github.com/sanette/tsdl-mixer).

Note that these bindings are at an early stage and have only been used
minimally.  The interface may change.  Comments and bug reports are
welcome through the
[github page](https://github.com/sanette/tsdl-ttf).

## Installation

Via [opam](https://opam.ocaml.org/):

    opam install tsdl-ttf

or, to get the latest version:

	opam pin https://github.com/sanette/tsdl-ttf

## Tested on Linux, MacOS, Windows (mingw64)

These bindings use dynamic loading of the SDL2\_ttf library at runtime.

They should work for any version of SDL2\_ttf >= 2.0.14.

On Windows, before installing, you may need to select this `tsdl` version:

	opam pin https://github.com/sanette/tsdl

## Example

See [test/test.ml](https://github.com/sanette/tsdl-ttf/blob/master/test/show_string.ml)

	cd test
	dune exec ./show_string.exe

![Hello](https://github.com/sanette/tsdl-ttf/blob/master/test/hello_ocaml.png)

## Documentation

Documentation is
[here](https://sanette.github.io/tsdl-ttf/Ttf/index.html), it can be
generated with `dune build @doc`, (or `./make_doc.sh`) but the binding
follows the SDL2_ttf interface closely, so it may be sufficient to
consult
[its documentation](https://wiki.libsdl.org/SDL2_ttf).

Starting from version 0.3, the library is usable in a toplevel (with
`#require "tsdl-ttf"`).

## WARNING V0.3 Breaking change

Starting from 0.3, the library name is the same as the opam package
name `tsdl-ttf`. (The library name used to be `tsdl_ttf`, which
was confusing).

## CI

(This CI uses the official `tsdl`. For Windows with the modified
`tsdl`, see the Github actions.)

https://ci.ocamllabs.io/github/sanette/tsdl-ttf
