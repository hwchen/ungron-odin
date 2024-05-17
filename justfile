run file:
    odin build . -o:aggressive -disable-assert -no-bounds-check && \
    ./ungron-odin {{file}}

# Reactivate when we figure out bug with -disable-assert and the byte read
#bench file:
#    odin build . -o:aggressive -disable-assert -no-bounds-check && \
#    poop "./ungron-odin {{file}}"

bench file:
    odin build . -o:aggressive -no-bounds-check && \
    poop "./ungron-odin {{file}}"
