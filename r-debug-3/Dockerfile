# To build from the parent directory:
#   docker build -t wch1/r-debug-3 r-debug-3

FROM wch1/r-debug-2

RUN /tmp/buildR.sh csan

# Modify the RDcsan script to increase stack size with `ulimit -Ss 131072`;
# otherwise we get these messages during package compilation:
# Error: compilation failed -  C stack usage  8042720 is too close to the limit at NULL
RUN sed -i 's/^#!\/bin\/bash/#!\/bin\/bash\nulimit -Ss 131072/' /usr/local/bin/RDcsan
# Increase stack size in .bashrc, so that it is picked up by RDscriptcsan.
RUN echo "\nulimit -Ss 131072" >> $HOME/.bashrc

RUN RDcsan -q -e 'install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch))'
RUN RDcsan -q -e 'pak::pkg_install(c("devtools", "Rcpp", "cpp11", "decor", "roxygen2", "testthat", "memoise", "rmarkdown"))'
