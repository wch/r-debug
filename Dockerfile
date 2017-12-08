# To build, cd to this directory, then:
#   docker build -t r-debug .
#
# To run:
#   docker run --rm -ti --name rd r-debug

# Use a very recent version of Ubuntu to get the latest GCC, which we need for
# some of options used for ASAN builds.
FROM ubuntu:17.10

MAINTAINER Winston Chang "winston@rstudio.com"

# =====================================================================
# R
# =====================================================================

# Don't print "debconf: unable to initialize frontend: Dialog" messages
ARG DEBIAN_FRONTED=noninteractive

# Need this to add R repo
RUN apt-get update && apt-get install -y software-properties-common

# Add R apt repository
RUN add-apt-repository "deb http://cran.r-project.org/bin/linux/ubuntu $(lsb_release -cs)/"
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9

# Install basic stuff, R, and other packages that are useful for compiling R
# and R packages.
RUN apt-get update && apt-get install -y \
    sudo \
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
    gdb \
    valgrind


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
    && tlmgr install metafont mfware inconsolata tex ae parskip listings \
    && tlmgr path add \
    && Rscript -e "source('https://install-github.me/yihui/tinytex'); tinytex::r_texmf()"
    

# =====================================================================
# Install various versions of R-devel
# =====================================================================

# Clone R-devel and download recommended packages
RUN cd /tmp \
    && git clone --depth 30 https://github.com/wch/r-source.git \
    && (cd r-source && git checkout 5f86e82f26f7066d25732ca11b48bd95ef95e63c) \
    && r-source/tools/rsync-recommended

COPY buildR.sh /tmp

# RD: Install normal R-devel
RUN /tmp/buildR.sh
RUN RD -e 'install.packages(c("devtools", "Rcpp"))'

# RDvalgrind2: Install R-devel with valgrind level 2 instrumentation
RUN /tmp/buildR.sh valgrind2
RUN RDvalgrind2 -e 'install.packages(c("devtools", "Rcpp"))'

# RDsan: R-devel with address sanitizer (ASAN) and undefined behavior sanitizer (UBSAN)
# Entry copied from Prof Ripley's setup described at http://www.stats.ox.ac.uk/pub/bdr/memtests/README.txt
# Also increase malloc_context_size to a depth of 200 calls.
ENV ASAN_OPTIONS 'alloc_dealloc_mismatch=0:detect_leaks=0:detect_odr_violation=0:malloc_context_size=200'
RUN /tmp/buildR.sh san
RUN RDsan -e 'install.packages(c("devtools", "Rcpp"))'

# RDstrictbarrier: Make sure that R objects are protected properly.
RUN /tmp/buildR.sh strictbarrier
RUN RDstrictbarrier -e 'install.packages(c("devtools", "Rcpp"))'

# RDassertthread: Make sure that R's memory management functions are called
# only from the main R thread.
COPY assertthread.patch /tmp/r-source
RUN (cd /tmp/r-source && patch -p0 < assertthread.patch)
RUN /tmp/buildR.sh assertthread
RUN RDassertthread -e 'install.packages(c("devtools", "Rcpp"))'
