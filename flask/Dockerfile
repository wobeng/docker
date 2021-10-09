# syntax=docker/dockerfile:experimental
FROM public.ecr.aws/lambda/python:latest

# install packages
RUN yum update -y
RUN yum install -y git

# install requirements
RUN pip3 install gunicorn
RUN mkdir -p -m 0600 ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts

# Copy app files
COPY . ${LAMBDA_TASK_ROOT}

# Install requirements
RUN --mount=type=ssh pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

#start app
ADD init.sh /var/task/init.sh
RUN chmod u+x /var/task/init.sh
ENTRYPOINT [ "/var/task/init.sh" ]