#! /bin/bash

set -e

# Run workspace-one-time-setup if configured and terminal is interactive
if [ ! -f "$USER_WORKSPACE/configs/installs/_install_workspace_onetime_startup_success" ]; then

    mkdir -p "$USER_WORKSPACE/repos"
    mkdir -p "$USER_WORKSPACE/configs/envs"
    ln -s "$HOME/.aws" $USER_WORKSPACE/configs/aws
    ln -s "$HOME/.gcloud" $USER_WORKSPACE/configs/gcloud

    touch $USER_WORKSPACE/configs/envs/dev
    echo "ENVIRONMENT=develop" >> $USER_WORKSPACE/configs/envs/dev
    echo "IS_LOCAL=true" >> $USER_WORKSPACE/configs/envs/dev

    # set up virenv and packages
   python3 -m venv $USER_WORKSPACE/configs/virenv
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade pip
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade pylint
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade autopep8
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade black
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade isort
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade flake8
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade pyflakes
   $USER_WORKSPACE/configs/virenv/bin/python -m pip install --upgrade pre-commit


    mkdir -p "$USER_WORKSPACE/configs/installs"
    touch "$USER_WORKSPACE/configs/installs/_install_workspace_onetime_startup_success"
fi


# make containers
if [ ! -f "$HOME/containers/.devcontainer/devcontainer.json" ]; then
    /bin/cp "/tmp/docker-master/devboxes/devcontainer.json" "$HOME/containers/.devcontainer/devcontainer.json"
fi
