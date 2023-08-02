#!/bin/bash
set -e -x

# Env vars used by configure. These settings are from `R CMD config CFLAGS`
# and CXXFLAGS, but without `-O2` and `-fdebug-prefix-map=...`, and with `-g`,
# `-O0`.
export LIBnn=lib
export CFLAGS="-fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g -O0 -Wall"
export CXXFLAGS="-fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g -O0 -Wall"
export R_BATCHSAVE="--no-save --no-restore"

# =============================================================================
# Customized settings for various builds
# =============================================================================
if [[ $# -eq 0 ]]; then
    suffix=""
    configure_flags=""

elif [[ "$1" = "valgrind" ]]; then
    suffix="valgrind"
    configure_flags="-C --with-valgrind-instrumentation=2 --without-recommended-packages --with-system-valgrind-headers"

elif [[ "$1" = "san" ]]; then
    suffix="san"
    configure_flags="--without-recommended-packages --disable-openmp"
    # Settings borrowed from:
    # http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt
    # https://github.com/rocker-org/r-devel-san/blob/master/Dockerfile
    # But without -mtune=native because the Docker image needs to be portable.
    export CXX="g++ -fsanitize=address,undefined,bounds-strict -fno-omit-frame-pointer"
    export CFLAGS="${CFLAGS} -pedantic -fsanitize=address"
    export DEFS=-DSWITCH_TO_REFCNT
    export FFLAGS="-g -O0"
    export FCFLAGS="-g -O0"
    export CXXFLAGS="${CXXFLAGS} -Wall -pedantic"
    export MAIN_LDFLAGS="-fsanitize=address,undefined -pthread"

    # Did not copy over ~/.R/Makevars from BDR's page because other R
    # installations would also read that file, and packages built for those
    # other R installations would inherit settings meant for this build.

elif [[ "$1" = "csan" ]]; then
    suffix="csan"
    configure_flags="--without-recommended-packages --disable-openmp"
    # Settings borrowed from:
    # http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt
    # https://github.com/rocker-org/r-devel-san/blob/master/Dockerfile
    export CC="clang -fsanitize=address,undefined -fno-sanitize=float-divide-by-zero -fno-sanitize=alignment -fno-omit-frame-pointer"
    export CXX="clang++ -fsanitize=address,undefined -fno-sanitize=float-divide-by-zero -fno-sanitize=alignment -fno-omit-frame-pointer -frtti"
    export CFLAGS="-g -gdwarf-4 -Wno-c11-extensions -O0 -Wall -pedantic"
    export FFLAGS="-g -gdwarf-4 -Wno-c11-extensions -O0"
    export CXXFLAGS="-g -gdwarf-4 -Wno-c11-extensions -O0 -Wall -pedantic"
    export MAIN_LD="clang++ -fsanitize=undefined,address"

    # Did not copy over ~/.R/Makevars from BDR's page because other R
    # installations would also read that file, and packages built for those
    # other R installations would inherit settings meant for this build.

elif [[ "$1" = "strictbarrier" ]]; then
    suffix="strictbarrier"
    configure_flags="--enable-strict-barrier --without-recommended-packages"

elif [[ "$1" = "threadcheck" ]]; then
    suffix="threadcheck"
    export CFLAGS="${CFLAGS} -DTHREADCHECK"
    export CXXFLAGS="${CXXFLAGS} -DTHREADCHECK"
    configure_flags="--without-recommended-packages"
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
rm -f src/library/Recommended/Makefile


## Set Renviron to first use this version of R's site-library/, then library/,
## then use "vanilla" RD installation's library/. This makes it so we don't
## have to install recommended packages for every single flavor of R-devel.
echo "R_LIBS_SITE=\${R_LIBS_SITE-'/usr/local/${dirname}/lib/R/site-library:/usr/local/${dirname}/lib/R/library:/usr/local/RD/lib/R/library'}
R_LIBS_USER=~/${dirname}
MAKEFLAGS='--jobs=4'" \
    >> /usr/local/${dirname}/lib/R/etc/Renviron

# Create the site-library dir; packages installed after this point will go
# there.
mkdir "/usr/local/${dirname}/lib/R/site-library"


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
