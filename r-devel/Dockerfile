# To build from the parent directory:
#   docker build -t wch1/r-devel r-devel
#
# To run:
#   docker run --rm -ti --name rd wch1/r-devel

# Use a very recent version of Ubuntu to get the latest GCC, which we need for
# some of options used for ASAN builds.
FROM ubuntu:22.04

MAINTAINER Winston Chang "winston@rstudio.com"

# =====================================================================
# R
# =====================================================================

# Don't print "debconf: unable to initialize frontend: Dialog" messages
ARG DEBIAN_FRONTEND=noninteractive

# Need this to add R repo
RUN apt-get update && apt-get install -y software-properties-common wget dirmngr

# LLVM-15
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN add-apt-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-15 main"

# Add R apt repository
RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
RUN add-apt-repository "deb http://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

# Install basic stuff, R, and other packages that are useful for compiling R
# and R packages.
RUN apt-get update && apt-get install -y \
    sudo \
    locales \
    git \
    vim \
    less \
    wget \
    r-base \
    r-base-dev \
    r-recommended \
    automake \
    libtool \
    fonts-texgyre \
    gdebi-core \
    pandoc \
    pandoc-citeproc \
    libcurl4-openssl-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libxt-dev \
    libssl-dev \
    libgit2-dev \
    libxml2-dev \
    texinfo \
    rsync \
    default-jdk \
    bison \
    libtiff5-dev \
    tcl8.6-dev \
    tk8.6-dev \
    xfonts-base \
    xvfb \
    gcc-12 \
    g++-12 \
    gdb \
    valgrind \
    clang-15 \
    lldb-15 \
    devscripts

RUN locale-gen en_US.utf8 \
    && /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 800 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-12

RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 800 \
    --slave /usr/bin/clang++ clang++ /usr/bin/clang++-15 \
    --slave /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-15


RUN echo 'options(\n\
  repos = c(CRAN = "https://cloud.r-project.org/"),\n\
  download.file.method = "libcurl",\n\
  # Detect number of physical cores\n\
  Ncpus = parallel::detectCores(logical=FALSE)\n\
)' >> /etc/R/Rprofile.site


# Install TinyTeX (subset of TeXLive)
# From FAQ 5 and 6 here: https://yihui.name/tinytex/faq/
# Also install ae, parskip, and listings packages to build R vignettes
RUN wget -qO- \
    "https://yihui.org/gh/tinytex/tools/install-unx.sh" | \
    sh -s - --admin --no-path \
    && ~/.TinyTeX/bin/*/tlmgr path add \
    && tlmgr install metafont mfware inconsolata tex ae parskip listings xcolor \
             epstopdf-pkg pdftexcmds kvoptions texlive-scripts grfext \
    && tlmgr path add \
    && Rscript -e "install.packages('tinytex'); tinytex::r_texmf()"


# =====================================================================
# Install various versions of R-devel
# =====================================================================

# Environment variables from http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt
ENV ASAN_OPTIONS 'detect_leaks=0:detect_odr_violation=0'
ENV UBSAN_OPTIONS 'print_stacktrace=1'
ENV RJAVA_JVM_STACK_WORKAROUND 0
ENV RGL_USE_NULL true
ENV R_DONT_USE_TK true


# Clone R-devel and download recommended packages
RUN cd /tmp \
    && git clone --depth 1 https://github.com/wch/r-source.git \
    && r-source/tools/rsync-recommended

COPY buildR.sh /tmp

# RD: Install normal R-devel.
#
# This R installation is slightly different from the ones that follow. It is
# configured with the recommended packages, and has those packages installed
# packages to library/ (not site-library/). These packages will be shared with
# the other RD* installations that follow. For all the RD* installations
# (including this one), all packages installed after buildR.sh runs will be
# installed to each installation's site-library/.
#
# I've set it up this way because the "recommended" packages take a long time
# to compile and in most cases aren't involved in debugging the low-level
# problems that this Dockerfile is for, so it's OK to compile them once and
# share them. Other packages, like those installed by the user and Rcpp
# (*especially* Rcpp), are often of interest -- they are installed for each
# RD* installation, and code is compiled with whatever compiler settings are
# used for each RD* installation.
RUN /tmp/buildR.sh

# Install some commonly-used packages to a location used by all the RD*
# installations. These packages do not have compiled code and do not depend on
# packages that have compiled code.
RUN RD -q -e 'install.packages("pak", repos = sprintf("https://r-lib.github.io/p/pak/stable/%s/%s/%s", .Platform$pkgType, R.Version()$os, R.Version()$arch), "/usr/local/RD/lib/R/library")'
RUN RD -q -e 'pak::pkg_install(c("BH", "R6", "magrittr"), "/usr/local/RD/lib/R/library")'

# Finally, install some common packages specific to this build of R.
RUN RD -q -e 'pak::pkg_install(c("devtools", "Rcpp", "cpp11", "decor", "roxygen2", "testthat", "memoise", "rmarkdown"))'
