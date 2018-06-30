# To build from the parent directory:
#   docker build -t wch1/r-debug-3 r-debug-3

FROM wch1/r-debug-2

# RDsan: R-devel with clang, address sanitizer (ASAN) and undefined behavior
# sanitizer (UBSAN). Entry copied from Prof Ripley's setup described at
# http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt. Also increase
# malloc_context_size to a depth of 200 calls.
ENV ASAN_OPTIONS 'alloc_dealloc_mismatch=0:detect_leaks=0:detect_odr_violation=0:malloc_context_size=200'
ENV RGL_USE_NULL true
RUN /tmp/buildR.sh csan

# Modify the RDcsan script to increase stack size with `ulimit -Ss 32768`;
# otherwise we get these messages during package compilation:
# Error: compilation failed -  C stack usage  8042720 is too close to the limit at NULL
RUN sed -i 's/^#!\/bin\/bash/#!\/bin\/bash\nulimit -Ss 32768/' /usr/local/bin/RDcsan
