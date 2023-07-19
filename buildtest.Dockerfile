FROM ubuntu:jammy

RUN echo cache busting 2

COPY --chmod=0700 hooks/ scripts/ /usr/local/bin/

# Prevent fix-permissions from touching targets of links again and again
RUN \
    touch /usr/local/bin/fix-permissions && \
    chmod +x /usr/local/bin/fix-permissions && \
    sed -i 's/-exec chgrp/-exec chgrp -h/' /usr/local/bin/fix-permissions

RUN \
    echo "Install start" && \
    sleep 5 && \
    echo "Sleep done"

ADD --chmod=644 file /tmp/file

# COPY scripts/clean-layer.sh /usr/local/bin/

RUN apt-get update && apt-get install -y cowsay

RUN \
    echo "Install done" && \
    sleep 5 && \
    echo "Sleep done"
