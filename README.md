llvm sroa pass was disabled in https://github.com/odin-lang/Odin/commit/b7af4e7f6b3f8f96ca6d3efa492098293bfa4109 , that's probably one of the main reasons for much slower performance than zig.

Revisit perf once sroa is reenabled.

Reason for slow perf was actually that logging is not compiled out, and that there are extra flushes. After removing those, and with -o:aggressive, on current odin 2024-05 the difference on citylots is about 4.29 v. 4.75. So odin is well in range then.
