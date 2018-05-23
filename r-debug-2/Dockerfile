# To build from the parent directory:
#   docker build -t wch1/r-debug-2 r-debug-2

FROM wch1/r-debug-1

# RDsan: R-devel with address sanitizer (ASAN) and undefined behavior sanitizer (UBSAN)
# Entry copied from Prof Ripley's setup described at http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt
# Also increase malloc_context_size to a depth of 200 calls.
ENV ASAN_OPTIONS 'alloc_dealloc_mismatch=0:detect_leaks=0:detect_odr_violation=0:malloc_context_size=200'
ENV RGL_USE_NULL true
RUN /tmp/buildR.sh san
RUN RDsan -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
