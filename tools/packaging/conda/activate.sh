# On Ubuntu the link libdl.so is packaged separate from libdl-{ver}.so and libdl.so.2
# to avoid renode crashing we add local link on first activation.
# As we link to the link provided by libc package it should work after update

if ( ! [ -e $CONDA_PREFIX/lib/libdl.so ] ) && [ `whereis libdl | grep 'libdl\.so' | wc -l` -eq 0 ] ; then
    find / -name 'libdl.so.2' -exec ln -s {} $CONDA_PREFIX/lib/libdl.so \;
fi
