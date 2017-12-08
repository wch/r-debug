Docker image for debugging R memory problems
============================================

This repository contains a Dockerfile for creating an Docker image with the following tools and builds of R:

* `gdb`
* `valgrind`
* `R`: The current release version of R.
* `RD`: The current development version of R (R-devel).
* `RDvalgrind2`: R-devel compiled with valgrind level 2 instrumentation. This should be started with `RDvalgrind2 -d valgrind`.
* `RDsan`: R-devel compiled with Address Sanitizer and Undefined Behavior Sanitizer.
* `RDstrictbarrier`: R-devel compiled with `--enable-strict-barrier`. This can be used with `gctorture(TRUE)`, or `gctorture2(1, inhibit_release=TRUE)`.
* `RDassertthread`: R-devel, with a patch that detects if memory management functions are called from the wrong thread.

See [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-memory-access) for more information about these builds (except the assert-thread build, which uses a patch that I wrote.)

Each of the builds of R has its own libpath, so that a package installed with one build will not be accidentally used by another. They come with devtools and Rcpp installed.
