#! /bin/bash

# setup <org>/<username>

set -e

folder=$(echo $1 | cut -d/ -f2)
target="/workspace/repos/$folder"

if [ -z "$1" ]; then
  echo "command: devbox setup <org>/<username>"
  exit 0
fi

if [ -d  "$target" ] ; then
  echo "$folder already exist"
  code -n "$target"
  exit 0
fi

git clone "git@github.com:$1.git" "$target" > /dev/null 2>&1 || echo "Ensure your public key is attached to github and you have access to this repo"

# set up sso config
/usr/local/bin/sso.sh "$target"
# clone and install requirements
/usr/local/bin/setup.sh "$target"

if [ -f "$target/main.code-workspace" ]; then

   code "$target/main.code-workspace"
else
    code -r $target
fi
