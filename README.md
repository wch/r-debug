(https://images.microbadger.com/badges/image/wch1/r-debug.svg)](https://microbadger.com/images/wch1/r-debug)

Status at Docker Hub: [wch1/r-debug](https://hub.docker.com/r/wch1/r-debug/)


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


## Usage


### Getting the Docker image

You can pull the Docker image from Docker hub:

```
docker pull wch1/r-debug
```

Or you can build the image by cloning this repository, entering the directory, and running:

```
docker build -t wch1/r-debug .
```


### Running containers

To use:

```
docker run --rm -ti wch1/r-debug

# Then you can run R-devel with:
RD

# Or, to run one of the other builds:
RDvalgrind2 -d valgrind
RDsan
RDstrictbarrier
RDassertthread
```


To mount a local directory in the docker container:

```
docker run --rm -ti -v /my/local/dir:/mydir wch1/r-debug

```


If you want to have multiple terminals in the same container, start the container with `--name` and use `docker exec` from another terminal:

```
# Start container
docker run --rm -ti --name rd wch1/r-debug

# In another terminal, get a bash prompt in the container
docker exec -ti rd /bin/bash
```
