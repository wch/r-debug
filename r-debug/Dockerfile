# To build from the parent directory:
#   docker build -t wch1/r-debug r-debug

FROM wch1/r-debug-5

# RDthreadcheck: Make sure that R's memory management functions are called
# only from the main R thread.
RUN /tmp/buildR.sh threadcheck
RUN RDthreadcheck -q -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/dev")'
RUN RDthreadcheck -q -e 'pak::pkg_install(c("devtools", "Rcpp", "roxygen2", "testthat", "memoise", "rmarkdown"))'
