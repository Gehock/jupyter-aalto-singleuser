ARG UPSTREAM_MINIMAL_NOTEBOOK_VER
FROM jupyter/minimal-notebook:${UPSTREAM_MINIMAL_NOTEBOOK_VER}

USER root

ADD scripts/clean-layer.sh /usr/local/bin/

## Debian packages
# These are from scipy-notebook and needed for matplotlib/latex:
#  ffmpeg dvipng cm-super
# See https://github.com/jupyter/docker-stacks/blob/master/scipy-notebook/Dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        clang \
        cm-super \
        dvipng \
        ed \
        ffmpeg \
        file \
        git-annex \
        git-lfs \
        git-svn \
        graphviz \
        gzip \
        less \
        lsb-release \
        man-db \
        psmisc \
        && \
    clean-layer.sh

#RUN touch /.nbgrader.log && chmod 777 /.nbgrader.log
# sed -r -i 's/^(UMASK.*)022/\1002/' /etc/login.defs

# JupyterHub 1.0.0 is included in the current scipy-notebook image
# JupyterHub says we can use any existing jupyter image, as long as we properly
# pin the JupyterHub version
# https://github.com/jupyterhub/jupyterhub/tree/master/singleuser
RUN mamba install jupyterhub==1.1.0 && \
    clean-layer.sh


# Custom extension installations
#   importnb allows pytest to test ipynb
RUN \
    #conda config --prepend channels conda-forge && \
    # TODO: is this set already?
    conda config --system --set channel_priority strict && \
    mamba install \
        bash_kernel \
        conda-tree \
        importnb \
        inotify_simple \
        ipywidgets \
        jupyter_contrib_nbextensions \
        nbval \
        pipdeptree \
        pytest \
        # Requires nbgrader>6
        # voila \
        && \
    pip install --no-cache-dir \
        envkernel \
	&& \
    jupyter contrib nbextension install --sys-prefix && \
    python -m bash_kernel.install --sys-prefix && \
    ln -s /notebooks /home/jovyan/notebooks && \
    rm --dir /home/jovyan/work && \
    clean-layer.sh

RUN \
    #mamba install jupyterlab==2.* && \
    mamba install \
        jupyterlab-git \
        nbdime \
        nbgitpuller \
        nbstripout \
        && \
    jupyter labextension install \
                                # Deprecated, hub is now a built-in
                                #  @jupyterlab/hub-extension \
                                 @jupyter-widgets/jupyterlab-manager \
                                 @jupyterlab/git \
                                # Incompatible with jupyterlab 3.*
                                 #@fissio/hub-top-buttons \
                                # Incompatible with jupyterlab 1.0.2
                                 nbdime-jupyterlab \
                                 # https://github.com/lckr/jupyterlab-variableInspector/issues/232
                                 #@lckr/jupyterlab_variableinspector \
                                jupyter-matplotlib \
                                && \
    nbdime config-git --enable --system && \
    jupyter serverextension enable nbgitpuller --sys-prefix && \
    git config --system core.editor nano && \
    clean-layer.sh

#    jupyter serverextension enable --py nbdime --sys-prefix && \
#    jupyter nbextension install --py nbdime --sys-prefix && \
#    jupyter nbextension enable --py nbdime --sys-prefix && \
#    jupyter nbextension enable varInspector/main --sys-prefix && \
#    jupyter serverextension enable --py --sys-prefix jupyterlab_git && \
#    jupyter serverextension enable --py nbzip --sys-prefix && \
#    jupyter nbextension install --py nbzip && \
#    jupyter nbextension enable --py nbzip && \



# Nbgrader
RUN pip install --no-cache-dir git+https://github.com/AaltoSciComp/nbgrader@live-2020 && \
    # nbconvert 6 changed a lot, and nbgrader needs updating
    # old PR/discussion: https://github.com/jupyter/nbgrader/pull/1405
    # current PR: https://github.com/jupyter/nbgrader/pull/1421
    # this remains a major problem.
    mamba install 'nbconvert<6' && \
    jupyter nbextension install --sys-prefix --py nbgrader --overwrite && \
    jupyter nbextension enable --sys-prefix --py nbgrader && \
    jupyter serverextension enable --sys-prefix --py nbgrader && \
    jupyter nbextension disable --sys-prefix formgrader/main --section=tree && \
    jupyter serverextension disable --sys-prefix nbgrader.server_extensions.formgrader && \
    jupyter nbextension disable --sys-prefix create_assignment/main && \
    jupyter nbextension disable --sys-prefix course_list/main --section=tree && \
    jupyter serverextension disable --sys-prefix nbgrader.server_extensions.course_list && \
    #sed -i "s@assert '0600' ==.*@assert stat.S_IMODE(os.stat(fname).st_mode) \& 0o77 == 0@" \
    #    /opt/conda/lib/python3.8/site-packages/jupyter_client/connect.py && \
    clean-layer.sh


# Hooks and scrips are also copied at the end of other Dockerfiles because they
# might update frequently
COPY hooks/ scripts/ /usr/local/bin/
RUN chmod a+rx /usr/local/bin/*.sh

USER $NB_UID
