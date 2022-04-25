ARG VARIANT="3.10"
FROM mcr.microsoft.com/vscode/devcontainers/python:0-${VARIANT}

# [Choice] Node.js version: none, lts/*, 16, 14, 12, 10
ARG NODE_VERSION="14"
RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
     && apt-get -y install --no-install-recommends make g++
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN sudo ./aws/install

# [Optional] Uncomment this line to install global node packages.
RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g --silent @angular/cli" 2>&1

ADD setup.sh /usr/local/bin/setup.sh
ADD sso.sh /usr/local/bin/sso.sh
ADD devbox.sh /usr/local/bin/devbox
ADD startup.sh /usr/local/bin/workspace-one-time-startup.sh

RUN mkdir -p /var/log/exported

RUN mkdir /workspace  && chown vscode:vscode /workspace
RUN chmod 777 /var/log/exported
RUN chmod +x /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/sso.sh
RUN chmod +x /usr/local/bin/devbox
RUN chmod +x /usr/local/bin/workspace-one-time-startup.sh

RUN echo '' >> /etc/bash.bashrc
RUN echo 'bash /usr/local/bin/workspace-one-time-startup.sh' >> /etc/bash.bashrc