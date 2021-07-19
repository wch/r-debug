# To build from the parent directory:
#   docker build -t wch1/r-debug-2 r-debug-2

FROM wch1/r-debug-1

RUN /tmp/buildR.sh san
RUN RDsan -q -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/dev")'
RUN RDsan -q -e 'pak::pkg_install(c("devtools", "Rcpp", "roxygen2", "testthat", "memoise", "rmarkdown"))'
