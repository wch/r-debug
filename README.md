[![](https://images.microbadger.com/badges/image/wch1/r-debug.svg)](https://microbadger.com/images/wch1/r-debug)

Status at Docker Hub: [wch1/r-debug](https://hub.docker.com/r/wch1/r-debug/)


Docker image for debugging R memory problems
============================================

The document [debugging-r.md](debugging-r.md) document contains information about diagnosing bugs in C and C++ code that interfaces with R.

This repository contains a Dockerfile for creating an Docker image, `wch1/r-debug` with the following tools and builds of R:

* `gdb`
* `valgrind`
* `R`: The current release version of R.
* `RD`: The current development version of R (R-devel). This version is compiled without optimizations (`-O0`), so a debugger can be used to inspect the code as written, instead of an optimized version of the code which may be significantly different.
* `RDvalgrind`: R-devel compiled with valgrind level 2 instrumentation. This should be started with `RDvalgrind -d valgrind`.
* `RDsan`: R-devel compiled with gcc, Address Sanitizer and Undefined Behavior Sanitizer.
* `RDcsan`: R-devel compiled with clang, Address Sanitizer and Undefined Behavior Sanitizer.
* `RDstrictbarrier`: R-devel compiled with `--enable-strict-barrier`. This can be used with `gctorture(TRUE)`, or `gctorture2(1, inhibit_release=TRUE)`.
* `RDassertthread`: R-devel, with a patch that detects if memory management functions are called from the wrong thread.

See [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-memory-access) for more information about these builds (except the assert-thread build, which uses a patch that I wrote.)

Each of the builds of R has its own library, so that a package installed with one build will not be accidentally used by another (With the exception of base R's "recommended packages". If you want to know the details, see the Dockerfile.) Each build of R comes with devtools and Rcpp installed.


## Usage


### Getting the Docker image

You can pull the Docker image from Docker hub:

```
docker pull wch1/r-debug
```

Or you can build the image by cloning this repository, entering the directory, and running:

```
./buildall.sh
```

This builds a number of intermediate Docker images, in this order:

* wch1/r-devel
* wch1/r-debug-1
* wch1/r-debug-2
* wch1/r-debug-3
* wch1/r-debug-4
* wch1/r-debug

Only the last one, wch1/r-debug, is needed in the end, and it contains all the various builds of R. The reason it is split up into intermediate Docker images is because building the several versions of R takes a long time, and doing it with a single Dockerfile causes timeouts with Docker Hub's automated build system.


### Running containers

To start a container:

```
docker run --rm -ti --security-opt seccomp=unconfined wch1/r-debug

# Then you can run R-devel with:
RD

# Or, to run one of the other builds:
RDvalgrind -d valgrind
RDsan
RDcsan
RDstrictbarrier
RDassertthread
```

The `--security-opt seccomp=unconfined` is needed to use `gdb` in the container. Without it, you'll see a message like `warning: Error disabling address space randomization: Operation not permitted`, and R will fail to start in the debugger.


To mount a local directory in the docker container:

```
docker run --rm -ti --security-opt seccomp=unconfined -v /my/local/dir:/mydir wch1/r-debug

# Mount the current host directory at /mydir
docker run --rm -ti --security-opt seccomp=unconfined -v $(pwd):/mydir wch1/r-debug
```


If you want to have multiple terminals in the same container, start the container with `--name` and use `docker exec` from another terminal:

```
# Start container
docker run --rm -ti --name rd --security-opt seccomp=unconfined wch1/r-debug

# In another terminal, get a bash prompt in the container
docker exec -ti rd /bin/bash
```
