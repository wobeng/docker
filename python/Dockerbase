# syntax=docker/dockerfile:experimental
FROM public.ecr.aws/lambda/python:3.8

# install packages
RUN yum update -y
RUN yum install -y git
RUN yum install -y libffi-devel xmlsec1 xmlsec1-openssl

# install requirements
RUN pip3 install wheel
RUN pip3 install gunicorn
RUN pip3 install --upgrade pip
RUN mkdir -p -m 0600 ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts

# entry
RUN printf "#!/bin/bash\n \
\nif [[ -n \"\${AWS_BATCH_JQ_NAME}\" ]]; then\n \
    python -m main\n \
elif [[ -n \"\${AWS_EXECUTION_ENV}\" && -z \"\${PORT}\" ]]; then\n \
    source /lambda-entrypoint.sh main.handler \"\$@\"\n \
elif [[ -n \"\${AWS_EXECUTION_ENV}\" && -n \"\${PORT}\" ]]; then\n \
    echo \"Running on port \${PORT}\"\n \
    gunicorn --worker-tmp-dir /dev/shm --workers \$(( 2 * \`cat /proc/cpuinfo | grep 'core id' | wc -l\` )) --bind 0.0.0.0:\${PORT} --timeout 120 main:app\n \
else\n \
    exec \"\$@\"\n \
fi\n" > init.sh

RUN chmod +x /var/task/init.sh
ENTRYPOINT ["/var/task/init.sh" ]