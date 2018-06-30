# To build from the parent directory:
#   docker build -t wch1/r-debug-3.5 r-debug-3.5

FROM wch1/r-debug-3

# This was originally done in r-debug-3, but it took too long on Docker Hub
# and the build would time out.
RUN RDcsan -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
