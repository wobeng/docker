# syntax=docker/dockerfile:experimental
FROM public.ecr.aws/codebuild/amazonlinux2-x86_64-standard:3.0

# Install dependencies
RUN yum update -y
RUN yum install -y gcc gcc-c++ make wget yum-utils groupinstall development
RUN yum install -y zlib-devel libffi-devel python-devel openssl-devel git zip unzip
RUN yum install -y jq which gettext epel-release tar dbus-glib amazon-efs-utils
RUN yum install -y dotnet-sdk-3.1 libunwind rsync


# Activate npm and install packages
RUN npm config set strict-ssl false
RUN npm config set unsafe-perm=true
RUN npm install -g @angular/cli
RUN npm install -g angular-gettext-cli
RUN npm install --prefix /tmp @biesbjerg/ngx-translate-extract @angular/compiler typescript tslib@^1.10.0 braces --save-dev

# Install pip
RUN pip3 install wheel

# Install virtualenv
RUN pip install virtualenv
RUN python3 -m venv /tmp/venv3
RUN python3 -m venv /tmp/venv3-scripts

# Install virtualenv packages
RUN /tmp/venv3/bin/pip install --upgrade pip
RUN /tmp/venv3-scripts/bin/pip install --upgrade pip
RUN /tmp/venv3/bin/pip install --upgrade wheel
RUN /tmp/venv3-scripts/bin/pip install --upgrade wheel

# Set Locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Add scripts
ADD init.sh /tmp/init.sh
RUN chmod u+x /tmp/init.sh