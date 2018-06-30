#!/bin/sh

# Build all the chained Docker images

set -ex

docker build -t wch1/r-devel   r-devel
docker build -t wch1/r-debug-1 r-debug-1
docker build -t wch1/r-debug-2 r-debug-2
docker build -t wch1/r-debug-3 r-debug-3
docker build -t wch1/r-debug-3.5 r-debug-3.5
docker build -t wch1/r-debug-4 r-debug-4
docker build -t wch1/r-debug   r-debug
