# To build from the parent directory:
#   docker build -t wch1/r-debug-4 r-debug-4

FROM wch1/r-debug-3

# RDstrictbarrier: Make sure that R objects are protected properly.
RUN /tmp/buildR.sh strictbarrier
RUN RDstrictbarrier -q -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/dev")'
RUN RDstrictbarrier -q -e 'pak::pkg_install(c("devtools", "Rcpp", "cpp11", "decor", "roxygen2", "testthat", "memoise", "rmarkdown"))'
