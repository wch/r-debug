# To build from the parent directory:
#   docker build -t wch1/r-devel r-devel
#
# To run:
#   docker run --rm -ti --name rd wch1/r-devel

# Use a very recent version of Ubuntu to get the latest GCC, which we need for
# some of options used for ASAN builds.
FROM ubuntu:18.04

MAINTAINER Winston Chang "winston@rstudio.com"

# =====================================================================
# R
# =====================================================================

# Don't print "debconf: unable to initialize frontend: Dialog" messages
ARG DEBIAN_FRONTEND=noninteractive

# Need this to add R repo
RUN apt-get update && apt-get install -y software-properties-common

# Add R apt repository
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
RUN add-apt-repository "deb http://cran.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran35/"

# Install basic stuff, R, and other packages that are useful for compiling R
# and R packages.
RUN apt-get update && apt-get install -y \
    sudo \
    locales \
    git \
    vim-tiny \
    less \
    wget \
    r-base \
    r-base-dev \
    r-recommended \
    fonts-texgyre \
    gdebi-core \
    pandoc \
    pandoc-citeproc \
    libcurl4-openssl-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libxt-dev \
    libssl-dev \
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
    gcc-8 \
    g++-8 \
    gdb \
    valgrind \
    clang-7 \
    lldb-7

RUN locale-gen en_US.utf8 \
    && /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-8

RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-7 800 \
    --slave /usr/bin/clang++ clang++ /usr/bin/clang++-7


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
    "https://github.com/yihui/tinytex/raw/master/tools/install-unx.sh" | \
    sh -s - --admin --no-path \
    && ~/.TinyTeX/bin/*/tlmgr path add \
    && tlmgr install metafont mfware inconsolata tex ae parskip listings xcolor \
    && tlmgr path add \
    && Rscript -e "source('https://install-github.me/yihui/tinytex'); tinytex::r_texmf()"


# =====================================================================
# Install various versions of R-devel
# =====================================================================

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
RUN RD -q -e 'install.packages(c("BH", "R6", "magrittr", "memoise"), "/usr/local/RD/lib/R/library")'

# Finally, install some common packages specific to this build of R.
RUN RD -q -e 'install.packages(c("devtools", "Rcpp", "roxygen2", "testthat"))'
