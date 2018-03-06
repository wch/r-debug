# To build from the parent directory:
#   docker build -t wch1/r-debug-3 r-debug-3

FROM wch1/r-debug-2

# RDsan: R-devel with clang, address sanitizer (ASAN) and undefined behavior
# sanitizer (UBSAN). Entry copied from Prof Ripley's setup described at
# http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt. Also increase
# malloc_context_size to a depth of 200 calls.
ENV ASAN_OPTIONS 'alloc_dealloc_mismatch=0:detect_leaks=0:detect_odr_violation=0:malloc_context_size=200'
ENV RGL_USE_NULL true

# Need to increase stack size; otherwise we get these messages during package
# compilation:
# Error: compilation failed -  C stack usage  8042720 is too close to the limit at NULL
# Note that this only has an effect if you run bash in the container; if you
# run RDcsan directly, it won't work.
RUN echo "ulimit -Ss 16384" >> /root/.bashrc

RUN /tmp/buildR.sh csan
RUN RDcsan -q -e 'install.packages(c("devtools", "Rcpp"))'
