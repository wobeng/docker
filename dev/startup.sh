# Run workspace-one-time-setup if configured and terminal is interactive
if [ -t 1 ] && [[ "${TERM_PROGRAM}" = "vscode" || "${TERM_PROGRAM}" = "codespaces" ]] && [ ! -f "$HOME/.config/vscode-dev-containers/workspace-one-time-startup-success" ]; then
    if [ -f "/workspaces/setup.sh" ]; then
        bash "/workspaces/setup.sh"
    fi
    mkdir -p "$HOME/.config/vscode-dev-containers"
    touch "$HOME/.config/vscode-dev-containers/workspace-one-time-startup-success"
fi
