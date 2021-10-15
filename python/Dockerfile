# syntax=docker/dockerfile:experimental
FROM public.ecr.aws/yblew/y-python-master:latest

# Copy app files
COPY . ${LAMBDA_TASK_ROOT}

# Install requirements
RUN --mount=type=ssh pip install -r requirements.txt