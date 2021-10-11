# syntax=docker/dockerfile:experimental
FROM public.ecr.aws/yblew/y-python-master:latest

# Copy app files
COPY . ${LAMBDA_TASK_ROOT}

# Install requirements
RUN --mount=type=ssh pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"