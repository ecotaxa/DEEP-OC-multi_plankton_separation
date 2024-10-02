# Dockerfile may have following Arguments:
# tag - tag for the Base image, (e.g. 2.9.1 for tensorflow)
# branch - user repository branch to clone (default: master, another option: test)
# jlab - if to insall JupyterLab (true) or not (false)
#
# To build the image:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> --build-arg arg=value .
# or using default args:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> .
#
# [!] Note: For the Jenkins CI/CD pipeline, input args are defined inside the
# Jenkinsfile, not here!

ARG tag=2.1.0-cuda12.1-cudnn8-runtime

# Base image, e.g. tensorflow/tensorflow:2.9.1
FROM pytorch/pytorch:${tag}

LABEL maintainer='Jean-Olivier Irisson'
LABEL version='0.0.2'
# Automatic separation of objects in images containing multiple plankton organisms

# What user branch to clone [!]
ARG branch=master

# If to install JupyterLab
ARG jlab=true

# Install Ubuntu packages
# - gcc is needed in Pytorch images because deepaas installation might break otherwise (see docs) (it is already installed in tensorflow images)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        git \
        curl \
        nano \
    && rm -rf /var/lib/apt/lists/*

# Update python packages
# [!] Remember: DEEP API V2 only works with python>=3.6
RUN python3 --version && \
    pip3 install --no-cache-dir --upgrade pip "setuptools<60.0.0" wheel

# TODO: remove setuptools version requirement when [1] is fixed
# [1]: https://github.com/pypa/setuptools/issues/3301

# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone (needed if syncing with NextCloud for training; otherwise remove)
# RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
#    dpkg -i rclone-current-linux-amd64.deb && \
#    apt install -f && \
#    mkdir /srv/.rclone/ && \
#    touch /srv/.rclone/rclone.conf && \
#    rm rclone-current-linux-amd64.deb && \
#    rm -rf /var/lib/apt/lists/*
#
# ENV RCLONE_CONFIG=/srv/.rclone/rclone.conf

# Initialization scripts
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start && \
    ln -s /srv/.deep-start/run_jupyter.sh /usr/local/bin/run_jupyter

# Install JupyterLab
ENV JUPYTER_CONFIG_DIR /srv/.deep-start/
# Necessary for the Jupyter Lab terminal
ENV SHELL /bin/bash
RUN if [ "$jlab" = true ]; then \
       # by default has to work (1.2.0 wrongly required nodejs and npm)
       pip3 install --no-cache-dir jupyterlab ; \
    else echo "[INFO] Skip JupyterLab installation!"; fi

# Install user app
RUN git clone -b $branch https://github.com/ecotaxa/multi_plankton_separation && \
    cd  multi_plankton_separation && \
    pip3 install --no-cache-dir -e . && \
    cd ..

RUN pip3 install matplotlib scikit-image transformers

ADD https://github.com/ecotaxa/multi_plankton_separation/releases/download/v1.0.0-alpha/default_mask_multi_plankton.pt multi_plankton_separation/models/default_mask_multi_plankton.pt
ADD https://github.com/ecotaxa/multi_plankton_separation/releases/download/v1.0.1-alpha/learn_placton_pano_plus5000_8epoch.zip multi_plankton_separation/models/learn_placton_pano_plus5000_8epoch.zip

# Open ports: DEEPaaS (5000), Monitoring (6006), Jupyter (8888)
EXPOSE 5000 6006 8888

# Launch deepaas
CMD ["deepaas-run", "--listen-ip", "0.0.0.0", "--listen-port", "5000"]
