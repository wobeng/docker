#!/bin/sh
# this script ensure ssh is available for github and to start the user ssh agent automatically


if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    /usr/bin/touch "$HOME/.ssh/config"
    /usr/bin/touch "$HOME/.ssh/known_hosts"
    /usr/bin/ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519" -C "$USER" <<<y >/dev/null 2>&1
    {
        /usr/bin/echo "Host *"
        /usr/bin/echo " AddKeysToAgent yes"
        /usr/bin/echo " ForwardAgent yes"
        /usr/bin/echo " IdentityFile $HOME/.ssh/id_ed25519"
    } >> "$HOME/.ssh/config"
    
    /usr/bin/ssh-keyscan github.com >> $HOME/.ssh/known_hosts
        
    /usr/bin/chmod 600 "$HOME/.ssh/config"
    /usr/bin/chmod 600 "$HOME/.ssh/id_ed25519"
    /usr/bin/chmod 600 "$HOME/.ssh/known_hosts"
    /usr/bin/chown "$USER":"$USER" -R "$HOME/.ssh"
fi

SSH_ENV="$HOME/.ssh/agent-environment"

function start_agent {
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add;
}

# Source SSH settings, if applicable
if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    #ps ${SSH_AGENT_PID} doesn't work under cywgin
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent;
    }
else
    start_agent;
fi
