# Reactivate when we figure out bug with -disable-assert and the byte read
#run file:
#    odin build . -o:aggressive -disable-assert -no-bounds-check && \
#    ./ungron-odin {{file}}

run file:
    odin build . -o:aggressive -no-bounds-check && \
    ./ungron-odin {{file}}

# Reactivate when we figure out bug with -disable-assert and the byte read
#bench file:
#    odin build . -o:aggressive -disable-assert -no-bounds-check && \
#    poop "./ungron-odin {{file}}"

bench file:
    odin build . -o:aggressive -no-bounds-check && \
    poop "./ungron-odin {{file}}"

# can inspect results with `perf report`
perf bin file *args="":
    perf record --call-graph dwarf {{bin}} {{file}} {{args}} > /dev/null

perf-gron file *args="":
    odin build . -o:aggressive -no-bounds-check && just perf ./ungron-odin {{args}} {{file}}

# stackcollapse-perf.pl and flamegraph.pl symlinked into path from flamegraph repo
flamegraph:
    perf script | stackcollapse-perf.pl | flamegraph.pl > perf.svg

