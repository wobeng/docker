#!/bin/bash

if [[ -z "${AWS_EXECUTION_ENV}" ]]; then
  gunicorn --worker-tmp-dir /dev/shm  --workers $(( 2 * `cat /proc/cpuinfo | grep 'core id' | wc -l` )) --bind 0.0.0.0:$PORT main:app
else
  source /lambda-entrypoint.sh "$@"
fi