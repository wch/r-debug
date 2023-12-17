#!/usr/bin/env sh

export CRAN_RSYNC='cran.r-project.org::CRAN'
export version='4.4.0'

rsync -rcIzv --timeout=60 --verbose --delete --include="*.tar.gz" \
    --exclude=Makefile.in --exclude=Makefile.win --exclude=Makefile --exclude=".svn" \
    --exclude="CVS*" --exclude=.cvsignore --exclude="*.tgz" \
    "${CRAN_RSYNC}"/src/contrib/${version}/Recommended/ ./Recommended || \
    { echo "*** rsync failed to update Recommended files ***" && exit 1; }

