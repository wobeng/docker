#! /bin/bash

# Run workspace-one-time-setup if configured and terminal is interactive
if [ -t 1 ] && [[ "${TERM_PROGRAM}" = "vscode" || "${TERM_PROGRAM}" = "codespaces" ]] && [ ! -f "$HOME/.config/vscode-dev-containers/workspace-one-time-startup-success" ]; then

    mkdir -p /workspace/repos
    mkdir -p /home/vscode/.aws
    mkdir -p /workspace/configs/envs
    mkdir -p /var/log/exported

    ln -s /home/vscode/.aws /workspace/configs/aws

    touch /workspace/configs/aws/config
    touch /workspace/configs/envs/dev

    sudo chmod 777 /var/log/exported
    chown vscode:vscode -R /workspace


    echo "ENVIRONMENT=develop" >> /workspace/configs/envs/dev
    echo "IS_LOCAL=true" >> /workspace/configs/envs/dev

    # set up virenv and packages
    python -m venv/workspace/configs/virenv
   /workspace/configs/virenv/bin/python -m pip install --upgrade pip
   /workspace/configs/virenv/bin/python -m pip install --upgrade pylint
   /workspace/configs/virenv/bin/python -m pip install --upgrade autopep8
   /workspace/configs/virenv/bin/python -m pip install --upgrade black
   /workspace/configs/virenv/bin/python -m pip install --upgrade isort
   /workspace/configs/virenv/bin/python -m pip install --upgrade flake8
   /workspace/configs/virenv/bin/python -m pip install --upgrade pyflakes
   /workspace/configs/virenv/bin/python -m pip install --upgrade pre-commit


    mkdir -p "$HOME/.config/vscode-dev-containers"
    touch "$HOME/.config/vscode-dev-containers/workspace-one-time-startup-success"
fi
