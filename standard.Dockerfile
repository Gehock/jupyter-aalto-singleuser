ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root

# Create software environment.
COPY --chmod=644 environment.yml /opt/environment.yml
RUN \
    /opt/conda/bin/conda config --system --set channel_priority flexible && \
    /opt/conda/bin/mamba env create \
        -f /opt/environment.yml \
        -p /opt/software && \
    /opt/conda/bin/conda config --system --set channel_priority strict && \
    clean-layer.sh

# ========================================

RUN \
    # The software package that's imported as a tar includes an incorrect
    # condarc file, using a modified version of the jupyter default instead
    echo -n > /opt/software/.condarc && \
    /opt/software/bin/conda config --system --append channels pytorch && \
    /opt/software/bin/conda config --system --append channels conda-forge && \
    /opt/software/bin/conda config --system --set auto_update_conda false && \
    /opt/software/bin/conda config --system --set show_channel_urls true && \
    /opt/software/bin/conda config --system --set channel_priority flexible && \
    /opt/software/bin/conda config --system --set ssl_verify /etc/ssl/certs/ca-certificates.crt && \
    /opt/software/bin/conda config --system --set allow_softlinks false

# ========================================

RUN /opt/software/bin/python -m ipykernel install --prefix=/opt/conda --display-name="Python 3"

ENV CC=clang CXX=clang++

RUN echo "import os ; os.environ['PATH'] = '/opt/software/bin:'+os.environ['PATH']" >> /etc/jupyter/jupyter_notebook_config.py
RUN echo "import os ; os.environ['PATH'] = '/opt/software/bin:'+os.environ['PATH']" >> /etc/jupyter/jupyter_server_config.py

ENV PATH=/opt/software/bin:${PATH}
ENV CONDA_DIR=/opt/software
# Make sure curl uses the correct system certificates from the ca-certificates
# package
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# ========================================

# requires bdaaccounting collection in the builder
RUN \
    echo [FreeTDS] >> /etc/odbcinst.ini && \
    echo Description=FreeTDS Driver >> /etc/odbcinst.ini && \
    echo Driver=/opt/software/lib/libtdsodbc.so >> /etc/odbcinst.ini && \
    echo Setup=/opt/software/lib/libtdsS.so >> /etc/odbcinst.ini

# ========================================

# Uncomment when ca-certificates requires an update
# RUN \
#     apt-get update && apt-get install -y --no-install-recommends \
#         ca-certificates \
#         && \
#     pip install --no-cache-dir \
#         'certifi>2021.10.8' \
#         && \
#     clean-layer.sh

# ========================================

#
# TODO: Last-added packages, move to builder when doing a full rebuild
#
# # coursecode, RT#00000
# RUN \
#     apt-get update && apt-get install -y --no-install-recommends \
#         packagename \
#         && \
#     /opt/software/bin/mamba install -p /opt/software -y --freeze-installed \
#         packagename \
#         && \
#     /opt/software/bin/pip install --no-cache-dir \
#         packagename \
#         && \
#     clean-layer.sh

# This is needed by `make test-standard`, can also be useful for users
RUN \
    /opt/software/bin/mamba install -p /opt/software -y --freeze-installed \
        pytest \
        && \
    clean-layer.sh

# koit2024, RT#24848
RUN \
    /opt/software/bin/mamba install -p /opt/software -y --freeze-installed \
        torchaudio \
        && \
    clean-layer.sh

# Uncomment when nbgrader needs to be updated
# RUN \
#     # Use the full path to pip to be more explicit about which environment
#     # we're installing to
#     /opt/conda/bin/pip uninstall nbgrader -y && \
#     /opt/conda/bin/pip install --no-cache-dir \
#         git+https://github.com/AaltoSciComp/nbgrader@v0.8.4.dev501 && \
#     clean-layer.sh

# TODO: Remove this when upgrading base to jupyterlab>=4 and jupyter_server>=2
RUN \
    /opt/conda/bin/pip uninstall jupyter_server_terminals -y && \
    clean-layer.sh

# This is currently already installed in the base image, but is required here
# as well, so that it's accessible when running pytest in /opt/software.
RUN \
    /opt/software/bin/mamba install -p /opt/software -y --freeze-installed \
        nbval \
        && \
    clean-layer.sh

# mlca2024, RT#25045
RUN \
    /opt/software/bin/mamba install -p /opt/software -y --freeze-installed \
        openeo \
        imgaug \
        ipyleaflet \
        && \
    /opt/software/bin/pip install --no-cache-dir \
        fusets \
        && \
    clean-layer.sh

# mlca2024, RT#25045
RUN \
    /opt/software/bin/mamba install -p /opt/software -y --freeze-installed \
        sentinelhub \
        eo-learn \
        && \
    clean-layer.sh

# valueanalytics2024, RT#25231
RUN \
    # NOTE: No --freeze-installed flag because couldn't install the package with it
    /opt/software/bin/mamba install -p /opt/software -y \
        'openai>=1.10' \
        && \
    clean-layer.sh

# css2024, RT#25415
RUN \
    /opt/software/bin/pip install --no-cache-dir \
        detoxify \
        && \
    clean-layer.sh

# gausproc2024, RT#25611
RUN \
    /opt/software/bin/mamba install -p /opt/software -y --freeze-installed \
        'tensorflow-probability>=0.22.0' \
        && \
    /opt/software/bin/pip install --no-cache-dir \
        'gpflow>=2.9.0' \
        && \
    clean-layer.sh

# quantuminfo2024, RT#25838
RUN \
    # NOTE: No --freeze-installed flag because couldn't install the package with it
    /opt/software/bin/mamba uninstall -p /opt/software -y \
        qiskit-terra \
        && \
    /opt/software/bin/mamba install -p /opt/software -y \
        'qiskit>=1' \
        qiskit-aer \
        && \
    clean-layer.sh

# RT#25980
# TODO: remove when base updates
RUN \
    apt-get update && apt-get install -y --no-install-recommends \
        # For exporting notebooks containing SVGs using nbconvert
        inkscape \
        && \
    clean-layer.sh

# RT#23949
RUN \
    /opt/software/bin/mamba install -y -c conda-forge\
        sage \
        && \
    clean-layer.sh

# ========================================

# Duplicate of base, but hooks can update frequently and are small so
# put them last.
COPY --chmod=0755 hooks/ scripts/ /usr/local/bin/

# Save version information within the image
ARG IMAGE_VERSION
ARG BASE_IMAGE
ARG JUPYTER_SOFTWARE_IMAGE
ARG GIT_DESCRIBE
RUN \
    truncate --size 0 /etc/cs-jupyter-release && \
    echo IMAGE_VERSION=${IMAGE_VERSION} >> /etc/cs-jupyter-release && \
    echo BASE_IMAGE=${BASE_IMAGE} >> /etc/cs-jupyter-release && \
    prefix=$(grep prefix: /opt/environment.yml | cut -d' ' -f2) && \
    echo JUPYTER_SOFTWARE_VERSION=${prefix} >> /etc/cs-jupyter-release && \
    echo GIT_DESCRIBE=${GIT_DESCRIBE} >> /etc/cs-jupyter-release


USER $NB_UID
