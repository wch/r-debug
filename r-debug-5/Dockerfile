# To build from the parent directory:
#   docker build -t wch1/r-debug-5 r-debug-5

FROM wch1/r-debug-4

# RDlto: R built with --enable-lto
RUN /tmp/buildR.sh lto
RUN RDlto -q -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/dev")'
RUN RDlto -q -e 'pak::pkg_install(c("devtools", "Rcpp", "roxygen2", "testthat", "memoise", "rmarkdown"))'
