# To build from the parent directory:
#   docker build -t wch1/r-debug-1 r-debug-1

FROM wch1/r-devel

# RDvalgrind: Install R-devel with valgrind level 2 instrumentation
RUN /tmp/buildR.sh valgrind
RUN RDvalgrind -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
