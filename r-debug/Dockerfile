# To build from the parent directory:
#   docker build -t wch1/r-debug r-debug

FROM wch1/r-debug-4

# RDthreadcheck: Make sure that R's memory management functions are called
# only from the main R thread.
RUN /tmp/buildR.sh threadcheck
RUN RDthreadcheck -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
