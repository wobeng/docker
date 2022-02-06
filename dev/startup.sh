# Run workspace-one-time-setup if configured and terminal is interactive

if [ -t 1 ] && [[ "${TERM_PROGRAM}" = "vscode" || "${TERM_PROGRAM}" = "codespaces" ]] && [ ! -f "$HOME/.config/vscode-dev-containers/workspace-one-time-startup-success" ]; then
    if [ -f "/usr/local/bin/workspace-one-time-setup.sh" ]; then
        bash "/usr/local/bin/workspace-one-time-setup.sh"
    fi
    mkdir -p "$HOME/.config/vscode-dev-containers"
    # Mark first run notice as displayed after 10s to avoid problems with fast terminal refreshes hiding it
    ((sleep 10s; touch "$HOME/.config/vscode-dev-containers/workspace-one-time-startup-success") &)
fi