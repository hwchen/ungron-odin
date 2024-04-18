llvm sroa pass was disabled in https://github.com/odin-lang/Odin/commit/b7af4e7f6b3f8f96ca6d3efa492098293bfa4109 , that's probably one of the main reasons for much slower performance than zig.

Revisit perf once sroa is reenabled.
