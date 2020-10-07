# To build from the parent directory:
#   docker build -t wch1/r-debug-2 r-debug-2

FROM wch1/r-debug-1

RUN /tmp/buildR.sh san
RUN RDsan -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
