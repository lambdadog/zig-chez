# zig-chez

Zig bindings for Chez Scheme. Includes a build step to compile (with
support for cross compilation) Chez Scheme.

## Status

 - [ ] Core C bindings
   + [ ] Factor out memory layout logic for bindings
     - This will require a lot of work learning the logic by which
       `scheme.h` is actually generated in
       [mkheader.ss](https://github.com/cisco/ChezScheme/blob/main/s/mkheader.ss),
       but will ensure correctness whereas bindings currently are a
       very manual mapping from the generated `scheme.h` headers.
   + [ ] Synchronization primitives
	 - Requires some way of passing config to `chez.zig`, I suspect
       with some orchestration in `build.zig` using `OptionsStep`.
	 - Requires porting over some GCC extended ASM
 - [ ] Idiomatic Zig bindings
 - [ ] [embedcore](https://github.com/lambdadog/embedcore)
   + An emacs core-like binding for writing extensible software using
     Zig and Chez Scheme. On a basic level, enables powerful
     configuration-as-code, but on an advanced level can enable an
     ecosystem.
