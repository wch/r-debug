# To build from the parent directory:
#   docker build -t wch1/r-debug r-debug

FROM wch1/r-debug-4

# RDassertthread: Make sure that R's memory management functions are called
# only from the main R thread.
COPY assertthread.patch /tmp/r-source
RUN (cd /tmp/r-source && patch -p0 < assertthread.patch)
RUN /tmp/buildR.sh assertthread
RUN RDassertthread -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
