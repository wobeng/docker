#!/usr/bin/env bash

set -e

# Run workspace-one-time-setup if configured and terminal is interactive
if [ ! -f "$USER_WORKSPACE/configs/installs/_install_workspace_onetime_startup_success" ]; then

    mkdir -p "$USER_WORKSPACE/repos"
    mkdir -p "$USER_WORKSPACE/extras"
    mkdir -p "$USER_WORKSPACE/configs/envs"
    ln -s "$HOME/.aws" $USER_WORKSPACE/configs/aws
    ln -s "$HOME/.gcloud" $USER_WORKSPACE/configs/gcloud
    touch $USER_WORKSPACE/configs/envs/dev
    
    if ! grep -qxF "ENVIRONMENT=develop" $USER_WORKSPACE/configs/envs/dev
    then
        echo "ENVIRONMENT=develop" >> $USER_WORKSPACE/configs/envs/dev
    fi
    if ! grep -qxF "IS_LOCAL=true" $USER_WORKSPACE/configs/envs/dev
    then
        echo "IS_LOCAL=true" >> $USER_WORKSPACE/configs/envs/dev
    fi

    # set up virenv and packages

    if [ ! -d "$USER_WORKSPACE/extras/virenv" ]; then
        python3 -m venv $USER_WORKSPACE/extras/virenv
        $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pip
        $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade ruff
        $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pytest
        $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pre-commit

    fi


    mkdir -p "$USER_WORKSPACE/configs/installs"
    touch "$USER_WORKSPACE/configs/installs/_install_workspace_onetime_startup_success"
fi


# make containers
#if [ ! -f "$HOME/containers/.devcontainer/devcontainer.json" ]; then
#    /bin/cp "/tmp/docker-master/devboxes/devcontainer.json" "$HOME/containers/.devcontainer/devcontainer.json"
#fi
