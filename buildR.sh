#!/bin/bash
set -e -x

# Env vars used by configure
export LIBnn=lib
export CFLAGS="$(R CMD config CFLAGS) -g -O0 -Wall"
export CXXFLAGS="$(R CMD config CXXFLAGS) -g -O0 -Wall"


# =============================================================================
# Customized settings for various builds
# =============================================================================
if [[ $# -eq 0 ]]; then
    suffix=""
    configure_flags=""

elif [[ $1 = "valgrind2" ]]; then
    suffix="valgrind2"
    configure_flags="--with-valgrind-instrumentation=2"

elif [[ $1 = "san" ]]; then
    suffix="san"
    configure_flags=""
    # Settings borrowed from:
    # http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt
    # https://github.com/rocker-org/r-devel-san/blob/master/Dockerfile
    # But without -mtune=native because the Docker image needs to be portable.
    export CXX="g++ -fsanitize=address,undefined,bounds-strict -fno-omit-frame-pointer"
    export CFLAGS="${CFLAGS} -pedantic -fsanitize=address"
    export FFLAGS="${CFLAGS}"
    export FCFLAGS="${CFLAGS}"
    export CXXFLAGS="${CFLAGS} -pedantic"
    export MAIN_LDFLAGS="-fsanitize=address,undefined"

    # Did not copy over ~/.R/Makevars from BDR's page because other R
    # installations would get them, and packages should inherit these
    # settings.
elif [[ "$1" = "strictbarrier" ]]; then
    suffix="strictbarrier"
    configure_flags="--enable-strict-barrier"

elif [[ "$1" = "assertthread" ]]; then
    suffix="assertthread"
    configure_flags=""
fi

dirname="RD${suffix}"

# =============================================================================
# Build
# =============================================================================
mkdir -p /usr/local/${dirname}/

cd /tmp/r-source

./configure \
    --prefix=/usr/local/${dirname} \
    --enable-R-shlib \
    --without-blas \
    --without-lapack \
    --with-readline \
    ${configure_flags}

# Do some stuff to simulate an SVN checkout.
# https://github.com/wch/r-source/wiki
(cd doc/manual && make front-matter html-non-svn)
echo -n 'Revision: ' > SVN-REVISION
git log --format=%B -n 1 \
  | grep "^git-svn-id"    \
  | sed -E 's/^git-svn-id: https:\/\/svn.r-project.org\/R\/[^@]*@([0-9]+).*$/\1/' \
  >> SVN-REVISION
echo -n 'Last Changed Date: ' >>  SVN-REVISION
git log -1 --pretty=format:"%ad" --date=iso | cut -d' ' -f1 >> SVN-REVISION

make --jobs=$(nproc)
make install

# Clean up, but don't delete rsync'ed packages
git clean -xdf -e src/library/Recommended/
rm src/library/Recommended/Makefile

# Set default CRAN repo
echo 'options(
  repos = c(CRAN = "https://cloud.r-project.org/"),
  download.file.method = "libcurl",
  # Detect number of physical cores
  Ncpus = parallel::detectCores(logical=FALSE)
)' >> /usr/local/${dirname}/lib/R/etc/Rprofile.site

# Create RD and RDscript (with suffix) in /usr/local/bin
cp /usr/local/${dirname}/bin/R /usr/local/bin/RD${suffix}
cp /usr/local/${dirname}/bin/Rscript /usr/local/bin/RDscript${suffix}
