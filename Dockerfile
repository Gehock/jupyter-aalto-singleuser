FROM jupyter/scipy-notebook:8d22c86ed4d7


USER root

# Debian package
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
           less \
           && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# add tzdata

RUN touch /.nbgrader.log && chmod 777 /.nbgrader.log
# sed -r -i 's/^(UMASK.*)022/\1002/' /etc/login.defs

COPY start.sh /usr/local/bin/
COPY disable_formgrader.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/disable_formgrader.sh


# JupyterHub says we can use any exsting jupyter image, as long as we properly pin the JupyterHub version
# https://github.com/jupyterhub/jupyterhub/tree/master/singleuser
RUN pip install jupyterhub==0.9.1 && \
           fix-permissions $CONDA_DIR /home/$NB_USER

# Custom installations
# igraph: complex networks (general)
# librarosa: datasci2018
# networkx: complex networks (general)
# nose: mlbp2018
# scikit-learn: mlbp2018
# plotchecker: for nbgrader, mlbp2018
RUN conda install \
           networkx \
           nose \
           scikit-learn && \
    conda install -c conda-forge \
           igraph \
           librosa && \
    pip install \
           plotchecker && \
    conda clean -tipsy && \
    fix-permissions $CONDA_DIR /home/$NB_USER

# Custom extension installations
RUN conda install -c conda-forge \
           ipywidgets \
           jupyter_contrib_nbextensions && \
    jupyter contrib nbextension install --sys-prefix && \
    conda upgrade jupyterlab && \
    pip install \
           jupyterlab-git \
           nbdime && \
    jupyter serverextension enable --py nbdime --sys-prefix && \
    jupyter nbextension install --py nbdime --sys-prefix && \
    jupyter nbextension enable --py nbdime --sys-prefix && \
    jupyter serverextension enable --py jupyterlab_git && \
    jupyter labextension install @jupyterlab/hub-extension \
                                 @jupyter-widgets/jupyterlab-manager \
                                 @jupyterlab/google-drive \
                                 @jupyterlab/git \
                                 nbdime-jupyterlab && \
    jupyter labextension disable @jupyterlab/google-drive && \
    nbdime config-git --enable --system && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    conda clean -tipsy && \
    npm cache clean --force && \
    fix-permissions $CONDA_DIR /home/$NB_USER && \
    rm -rf /opt/conda/pkgs/cache/ && \
    ln -s /notebooks /home/jovyan/notebooks && \
    rm --dir /home/jovyan/work
#                                jupyterlab_voyager \

# @jupyterlab/google-drive disabled by default until the app can be
# verified.  To enable, use "jupyter labextension enable
# @jupyterlab/google-drive". or remove the line above.


#COPY drive.jupyterlab-settings /opt/conda/share/jupyter/lab/settings/@jupyterlab/google-drive/drive.jupyterlab-settings
#COPY drive.jupyterlab-settings /home/jovyan/.jupyter/lab/user-settings/@jupyterlab/google-drive/drive.jupyterlab-settings
RUN sed -i s/625147942732-t30t8vnn43fl5mvg1qde5pl84603dr6s.apps.googleusercontent.com/939684114235-busmrp8omdh9f0jdkrer6o4r85mare4f.apps.googleusercontent.com/ \
     /opt/conda/share/jupyter/lab/static/vendors~main.31dfb7671a395e03169c.js* \
     /opt/conda/share/jupyter/lab/staging/build/vendors~main.31dfb7671a395e03169c.js* \
     /opt/conda/share/jupyter/lab/staging/node_modules/@jupyterlab/google-drive/lib/gapi*


RUN pip install git+https://github.com/rkdarst/nbgrader@2d562bd && \
    jupyter nbextension install --sys-prefix --py nbgrader --overwrite && \
    jupyter nbextension enable --sys-prefix --py nbgrader && \
    jupyter serverextension enable --sys-prefix --py nbgrader && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR /home/$NB_USER

USER $NB_UID


# In the Jupyter image, the default start command is
# start-notebook.sh.  If the env var JPY_API_TOKEN is defined, it will
# thun run start-singleuser.sh which then starts the single-user
# server properly.  It starts the singleuser server by calling
# start.sh with the right arguments.  If start.sh runs as root, it
# will use some env vars like NB_USER, NB_UID, NB_GID,
# GRANT_SUDO[=yes] to do various manipulations inside to set
# permissions to this particular user before running sudo to NB_USER
# to start the single-user image.  So thus, we need to do our initial
# setup and then call this.

# Note: put hooks in /usr/local/bin/start-notebook.d/ and start.sh
# will run these (source if end in .sh, run if +x).

#CMD " && start-notebook.sh"
