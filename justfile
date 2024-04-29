run file:
    odin build . -o:aggressive -disable-assert -no-bounds-check && \
    ./ungron-odin {{file}}

bench file:
    odin build . -o:aggressive -disable-assert -no-bounds-check && \
    poop "./ungron-odin {{file}}"
