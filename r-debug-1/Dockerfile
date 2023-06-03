# To build from the parent directory:
#   docker build -t wch1/r-debug-1 r-debug-1

FROM wch1/r-devel

# RDvalgrind: Install R-devel with valgrind level 2 instrumentation
RUN /tmp/buildR.sh valgrind
RUN RDvalgrind -q -e 'install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))'
RUN RDvalgrind -q -e 'pak::pkg_install(c("devtools", "Rcpp", "cpp11", "decor", "roxygen2", "testthat", "memoise", "rmarkdown"))'
