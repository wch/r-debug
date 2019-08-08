#!/bin/sh

# Build all the chained Docker images
#
# Use ./buildall.sh --rebuild to build from scratch -- this builds the first
# image with --no-cache and therefore causes all the downstream images to also
# be fully rebuilt.

set -ex

if [ "$1" = "--rebuild" ]; then
    args="--no-cache"
fi

docker build $args -t wch1/r-devel   r-devel
docker build -t wch1/r-debug-1 r-debug-1
docker build -t wch1/r-debug-2 r-debug-2
docker build -t wch1/r-debug-3 r-debug-3
docker build -t wch1/r-debug-4 r-debug-4
docker build -t wch1/r-debug   r-debug
