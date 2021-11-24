ARG VER_BASE
FROM aaltoscienceit/notebook-server-base:${VER_BASE}

USER root

ARG ENVIRONMENT_NAME
ARG ENVIRONMENT_VERSION
ARG ENVIRONMENT_HASH
ENV JUPYTER_SOFTWARE_IMAGE=${ENVIRONMENT_NAME}_${ENVIRONMENT_VERSION}_${ENVIRONMENT_HASH}

ADD conda/${JUPYTER_SOFTWARE_IMAGE}.tar.gz /opt/software

# Custom installations
#RUN apt-get update && \
#    apt-get install -y --no-install-recommends \
#           ... \
#           && \
#    clean-layer.sh

# # Update nbgrader
# RUN \
#     pip install --force --no-deps --upgrade --no-cache-dir \
#         git+https://github.com/AaltoSciComp/nbgrader@live-2020 \
#         'nbconvert<6' && \
#     clean-layer.sh

# requires bdaaccounting collection in the builder
# RUN \
#     echo [FreeTDS] >> /etc/odbcinst.ini && \
#     echo Description=FreeTDS Driver >> /etc/odbcinst.ini && \
#     echo Driver=/opt/conda/lib/libtdsodbc.so >> /etc/odbcinst.ini && \
#     echo Setup=/opt/conda/lib/libtdsS.so >> /etc/odbcinst.ini && \
#     clean-layer.sh

# ========================================

RUN /opt/software/bin/python -m ipykernel install --prefix=/opt/conda --display-name="Python 3"

ENV CC=clang CXX=clang++


# Duplicate of base, but hooks can update frequently and are small so
# put them last.
COPY hooks/ scripts/ /usr/local/bin/
RUN chmod a+rx /usr/local/bin/*.sh

USER $NB_UID
