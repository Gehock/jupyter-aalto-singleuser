ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root

# Based on https://github.com/almond-sh/almond/blob/187b206/Dockerfile

RUN apt-get -y update && \
    apt-get install --no-install-recommends -y \
      curl \
      openjdk-8-jre-headless \
      ca-certificates-java && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -Lo /usr/local/bin/coursier https://github.com/coursier/coursier/releases/download/v2.0.0-RC3-2/coursier && \
    chmod +x /usr/local/bin/coursier

RUN \
    /opt/conda/bin/pip install --no-cache-dir \
        numpy \
        # For tests
        nbconvert \
        # A buggy dependency, pinning to a version so that our patch works
        nbformat==5.8.0 \
        && \
    clean-layer.sh

# during tests, nbconvert calls nbformat, which doesn't seem to behave well with the almond kernel
COPY --chmod=555 scala-scripts/nbformat.diff /tmp
RUN \
    patch /opt/conda/lib/python3.10/site-packages/nbformat/v4/nbbase.py < /tmp/nbformat.diff && \
    rm /tmp/nbformat.diff

# USER $NB_UID

# ensure the JAR of the CLI is in the coursier cache, in the image
RUN /usr/local/bin/coursier --help

# Version from https://repo1.maven.org/maven2/sh/almond/scala-kernel_3.3.3/0.14.0-RC15/
ARG ALMOND_VERSION=0.14.0-RC15
# Set to a single Scala version string or list of Scala versions separated by a space.
# i.e SCALA_VERSIONS="2.12.19 2.13.11"
ARG SCALA_VERSIONS="3.3.3"

COPY --chmod=555 scala-scripts/install-kernels.sh .
RUN \
    ./install-kernels.sh && \
    rm install-kernels.sh && \
    rm -rf .ivy2

RUN coursier fetch --default --sources org.scalameta:munit_3:1.0.2

# ========================================

# USER root

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
    echo GIT_DESCRIBE=${GIT_DESCRIBE} >> /etc/cs-jupyter-release


USER $NB_UID
