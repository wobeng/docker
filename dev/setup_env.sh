#!/bin/bash
set -e

folder=$(echo $1 | cut -d/ -f2)
target="$HOME/workspaces/repos/$folder"

if [ -z "$1" ]; then
  echo "command: setup.sh <org>/<username>"
  exit 0
fi

if [ -d  "$target" ] ; then
  echo "$folder already exist"
  code -n "$target"
  exit 0
fi

mkdir -p "$HOME/workspaces/repos"
mkdir -p "$HOME/workspaces/configs/env"

git clone "git@github.com:$1.git" "$target" > /dev/null 2>&1 || echo "Ensure your public key is attached to github and you have access to this repo"