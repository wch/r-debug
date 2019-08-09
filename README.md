[![](https://images.microbadger.com/badges/image/wch1/r-debug.svg)](https://microbadger.com/images/wch1/r-debug)

As of 2019-08-08, the following Docker images are built daily and pushed to Docker Hub.

* [wch1/r-devel](https://hub.docker.com/r/wch1/r-devel/) contains just the current development version of R.
* [wch1/r-debug](https://hub.docker.com/r/wch1/r-debug/) contains all the instrumented builds of R described below.

Docker image for debugging R memory problems
============================================

See [debugging-r.md](debugging-r.md) for in-depth information about diagnosing bugs in C and C++ code that interfaces with R.

This repository contains a Dockerfile for creating an Docker image, `wch1/r-debug` with the following tools and builds of R:

* `gdb`
* `valgrind`
* `R`: The current release version of R.
* `RD`: The current development version of R (R-devel). This version is compiled without optimizations (`-O0`), so a debugger can be used to inspect the code as written, instead of an optimized version of the code which may be significantly different.
* `RDvalgrind`: R-devel compiled with valgrind level 2 instrumentation. This should be started with `RDvalgrind -d valgrind`.
* `RDsan`: R-devel compiled with gcc, Address Sanitizer and Undefined Behavior Sanitizer.
* `RDcsan`: R-devel compiled with clang, Address Sanitizer and Undefined Behavior Sanitizer.
* `RDstrictbarrier`: R-devel compiled with `--enable-strict-barrier`. This can be used with `gctorture(TRUE)`, or `gctorture2(1, inhibit_release=TRUE)`.
* `RDthreadcheck`: R-devel compiled with `-DTHREADCHECK`, which causes it to detect if memory management functions are called from the wrong thread.


See [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Checking-memory-access) for more information about these builds (except for the threadcheck build, which is not documented there.)

Each of the builds of R has its own library, so that a package installed with one build will not be accidentally used by another (With the exception of base R's "recommended packages". If you want to know the details, see the Dockerfile.) Each build of R comes with devtools and Rcpp installed, as well as a few other supporting packages.


## Usage


### Quick start

If you just want to get started quickly, run this to pull the image and start a container:

```
docker run --rm -ti --security-opt seccomp=unconfined wch1/r-debug
```

The SAN build of R-devel can detect many types of memory problems with a relatively small performance penalty, compared to some of the other builds of R. You can run it with:

```
RDsan
```

Inside of this R session, install packages and run your code. It will automatically detect memory errors and print out diagnostic information.

The Clang-SAN build also has low overhead. You can start it with:

```
RDcsan
```

Note that you'll have to install packages separately for each build of R.


For more details about getting the Docker image and starting containser, see below. Also read the [debugging-r.md](debugging-r.md) document for much more information about the various builds of R and different kinds of memory problems you may encounter.


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

Only the last one, wch1/r-debug, is needed in the end, and it contains all the various builds of R. The reason it is split up into intermediate Docker images is because building the several versions of R takes a long time, and doing it with a single Dockerfile causes timeouts with Docker Hub's automated build system. (As of 2019-08, it is no longer built with the Docker Hub automated build system; instead it is built on a local computer and pushed to Docker Hub. The intermediate steps could therefore be consolidated into a single step.)

If you have previously built Docker images and want to start over without using the cached images, use:

```
./buildall.sh --rebuild
```

This causes `docker build` to be run with `--no-cache` for the first Docker image in the chain. The rest of the images will then be built from scratch.


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
RDthreadcheck
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
