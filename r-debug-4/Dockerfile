# To build from the parent directory:
#   docker build -t wch1/r-debug-4 r-debug-4

FROM wch1/r-debug-3.5

# RDstrictbarrier: Make sure that R objects are protected properly.
RUN /tmp/buildR.sh strictbarrier
RUN RDstrictbarrier -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
