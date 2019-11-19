ARG VER_BASE
FROM aaltoscienceit/notebook-server-base:${VER_BASE}

## R support

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        clang \
        ed \
        fonts-dejavu \
        tzdata \
        gfortran \
        gzip \
        libblas-dev \
        libgit2-dev \
        libssl-dev \
        libopenblas-dev \
        liblapack-dev \
        r-base && \
    update-alternatives --set cc  /usr/bin/clang && \
    update-alternatives --set c++ /usr/bin/clang++ && \
    update-alternatives --set c89 /usr/bin/clang && \
    update-alternatives --set c99 /usr/bin/clang && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#libnlopt-dev --> NO, not compatible

#libprce2-dev
#libbz2-dev
#liblzma-dev

ARG CRAN_URL

RUN \
    echo "install.packages(c(" \
            "'repr', " \
            "'IRdisplay'," \
            "'evaluate'," \
            "'crayon',"\
            "'pbdZMQ',"\
            "'devtools',"\
            "'uuid',"\
            "'digest'"\
        "), repos='${CRAN_URL}', clean=TRUE)" | Rscript - && \
    Rscript -e "devtools::install_github('IRkernel/IRkernel')" && \
    Rscript -e 'IRkernel::installspec(user = FALSE)'
RUN jupyter kernelspec remove -f python3

# Packages from jupyter r-notebook
RUN \
    echo "install.packages(c(" \
            "'plyr', "\
            "'devtools', "\
            "'tidyverse', "\
            "'shiny', "\
            "'markdown', "\
            "'forecast', "\
            "'RSQLite', "\
            "'reshape2', "\
            "'nycflights13', "\
            "'caret', "\
            "'RCurl', "\
            "'crayon', "\
            "'randomForest', "\
            "'htmltools', "\
            "'sparklyr', "\
            "'htmlwidgets', "\
            "'hexbin', "\
            "'caTools' " \
        "), repos='${CRAN_URL}', clean=TRUE)" | Rscript - && \
    fix-permissions /usr/local/lib/R/site-library

#
# Course setup
#

# Packages needed for bayesian macheine learning course
RUN \
    Rscript -e "install.packages(c('nloptr', 'bayesplot', 'rstan', 'rstanarm', 'shinystan', 'loo', 'brms', 'GGally', 'MASS', 'coda', 'gridBase', 'gridExtra', 'here', 'projpred'), repos='${CRAN_URL}', clean=TRUE)" && \
    fix-permissions /usr/local/lib/R/site-library

# Try to disable Python kernel
# https://github.com/jupyter/jupyter_client/issues/144
RUN rm -r /home/$NB_USER/.local/ && \
    echo >> /etc/jupyter/jupyter_notebook_config.py && \
    echo 'c.NotebookApp.iopub_data_rate_limit = .8*2**20' >> /etc/jupyter/jupyter_notebook_config.py && \
    echo 'c.LabApp.iopub_data_rate_limit = .8*2**20' >> /etc/jupyter/jupyter_notebook_config.py && \
    echo "c.KernelSpecManager.whitelist={'ir', 'bash'}" >> /etc/jupyter/jupyter_notebook_config.py

# Set default R compiler to clang to save memory.
RUN echo "CC=clang"     >> /usr/lib/R/etc/Makevars && \
    echo "CXX=clang++"  >> /usr/lib/R/etc/Makevars && \
    sed -i  -e "s/= gcc/= clang -flto=thin/g"  -e "s/= g++/= clang++/g"  /usr/lib/R/etc/Makeconf

ENV R_MAKEVARS_SITE /usr/lib/R/etc/Makevars

#
# Rstudio
#
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libclang-dev \
        libapparmor1 \
        libedit2 \
        libssl1.0.0 \
        lsb-release \
        psmisc \
        && \
        clean-layer.sh


ENV RSTUDIO_PKG=rstudio-server-1.2.5001-amd64.deb
# https://github.com/jupyterhub/nbrsessionproxy
# Download url: https://www.rstudio.com/products/rstudio/download-server/
RUN wget -q https://download2.rstudio.org/server/bionic/amd64/${RSTUDIO_PKG} && \
    test "$(md5sum < ${RSTUDIO_PKG})" = "d33881b9ab786c09556c410e7dc477de  -" && \
    dpkg -i ${RSTUDIO_PKG} && \
    rm ${RSTUDIO_PKG}

# Rstudio for jupyterlab
#   Viasat/nbrsessionproxy is not compatible with JL 1.0
RUN set -x && pip install --no-cache-dir jupyter-rsession-proxy && \
    # The npm version of jupyterlab-server-proxy is not yet compatible
    # with JupyterLab 1.0 -> using git version.
    # See https://github.com/jupyterhub/jupyter-server-proxy/issues/139#issuecomment-516665020
    # jupyter labextension install jupyterlab-server-proxy && \
    cd /usr/local/src/ && \
    git clone https://github.com/jupyterhub/jupyter-server-proxy && \
    cd jupyter-server-proxy/jupyterlab-server-proxy && \
    git checkout daeb5aa08074758bf7922f6ca5b557f713feb4dd && \
    npm install && npm run build && jupyter labextension link . && \
    npm run build && jupyter lab build && \
    cd /usr/local/src && rm -r /usr/local/src/* && \
    ln -s /usr/lib/rstudio-server/bin/rserver /usr/local/bin/ && \
    fix-permissions /usr/local/lib/R/site-library && \
    clean-layer.sh


# Last-added packages, move to above
RUN \
    Rscript -e "install.packages(c('RUnit', 'markmyassignment'), repos='${CRAN_URL}', clean=TRUE)" && \
    fix-permissions /usr/local/lib/R/site-library


# openjdk-11-jre-headless: htbioinformatics2019, for fastcq
# python-htseq:            htbioinformatics2019, https://htseq.readthedocs.io/en/release_0.11.1/install.html
# libbz2-dev:              dependency for samtools
# libncurses5-dev:         dependency for samtools
# liblzma-dev:             dependency for samtools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libbz2-dev \
	libncurses5-dev \
	liblzma-dev \
        openjdk-11-jre-headless \
	python-htseq \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    pip install --no-cache-dir \
        htseq \
	&& \
    clean-layer.sh

RUN cd /opt && \
    mkdir fastcq && \
    wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.8.zip && \
    unzip fastqc_v0.11.8.zip && \
    rm fastqc_v0.11.8.zip && \
    chmod a+x ./FastQC/fastqc && \
    ln -s $PWD/FastQC/fastqc /usr/local/bin/ && \
    fix-permissions /opt/fastcq /usr/local/bin


# htbioinformatics2019, RT#15527
# http://bowtie-bio.sourceforge.net/bowtie2/manual.shtml#obtaining-bowtie-2
RUN conda config --append channels bioconda && \
    conda install \
        bowtie2 \
        && \
    clean-layer.sh

# htbioinformatics2019
# https://ccb.jhu.edu/software/tophat/tutorial.shtml
RUN cd /opt && \
    wget https://ccb.jhu.edu/software/tophat/downloads/tophat-2.1.1.Linux_x86_64.tar.gz && \
    tar xf tophat-2.1.1.Linux_x86_64.tar.gz && \
    sed -i 's@/usr/bin/env python@/usr/bin/python@' tophat-2.1.1.Linux_x86_64/tophat && \
    ln -s $PWD/tophat-2.1.1.Linux_x86_64/tophat2 /usr/local/bin/ && \
    fix-permissions /opt/fastcq /usr/local/bin


# Bioconductor
# edgeR, GenomicRanges, rtracklayer: htbioinformatics

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libomp-dev r-cran-xml && \
    echo 'if (!requireNamespace("BiocManager", quietly = TRUE)) '\
            'install.packages("BiocManager") ; ' \
            'BiocManager::install()' \
        | Rscript - && \
    echo 'BiocManager::install(c('\
            '"edgeR", ' \
            '"GenomicRanges", ' \
            '"rtracklayer" ' \
            '"BSgenome.Hsapiens.NCBI.GRCh38" ' \
        '))' | Rscript - && \
    fix-permissions /usr/local/lib/R/site-library && \
    clean-layer.sh

# samtools: htbioinformatics, http://www.htslib.org/download/
# pysam:    same --^
# macs2:    "
RUN \
    mkdir /opt/samtools && \
    cd /opt/samtools && \
    wget https://github.com/samtools/samtools/releases/download/1.9/samtools-1.9.tar.bz2 && \
    tar xf samtools-1.9.tar.bz2 && \
    cd samtools-1.9 && \
    ./configure --prefix=/opt/samtools/install/ --bindir=/usr/local/bin/ && \
    make && \
    make install && \
    pip install --no-cache-dir \
        pysam \
        macs2 \
	&& \
    clean-layer.sh


ENV CC=clang CXX=clang++
ENV BINPREF=PATH
# Duplicate of base, but hooks can update frequently and are small so
# put them last.
COPY hooks/ scripts/ /usr/local/bin/
RUN chmod a+x /usr/local/bin/*.sh

USER $NB_UID
