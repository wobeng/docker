#!/usr/bin/env bash

set -e

repo_name=$2
folder=$(echo $repo_name | cut -d/ -f2)
target="$USER_WORKSPACE/repos/$folder"

echo "==================== START DEVBOX ===================="
echo ""
echo ""

if ! grep -qxF "ENVIRONMENT=develop" $USER_WORKSPACE/configs/envs/dev
then
    echo "ENVIRONMENT=develop" >> $USER_WORKSPACE/configs/envs/dev
fi
if ! grep -qxF "IS_LOCAL=true" $USER_WORKSPACE/configs/envs/dev
then
    echo "IS_LOCAL=true" >> $USER_WORKSPACE/configs/envs/dev
fi

if [ ! -d "$USER_WORKSPACE/extras/virenv" ]; then
    output=`python3 -m venv $USER_WORKSPACE/extras/virenv 2>&1` || echo $output
    output=`$USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pip 2>&1` || echo $output
    output=`$USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade ruff 2>&1` || echo $output
    output=`$USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pytest 2>&1` || echo $output
    output=`$USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pre-commit 2>&1` || echo $output

fi

man () {
     echo "Oops, Something went wrong"
     echo ""
     echo "Command format: devbox setup <org>/<username>"
     echo ""
     echo "Ensure your public key below (~/.ssh/id_ed25519.pub) is added to your $USER_EMAIL github account settings https://github.com/settings/keys"
     echo ""
     cat $HOME/.ssh/id_ed25519.pub
     echo ""
     exit 1
}

open_target() {
    if [ -f "$target/$folder.code-workspace" ]; then
    code "$target/$folder.code-workspace"
  else
      code $target
  fi
  exit 0
}


if [ -z "$repo_name" ]; then
  man
fi


if [ ! -d  "$target" ] ; then

  output=`git clone "git@github.com:$repo_name.git" "$target" 2>&1` || man

fi

# set up sso config
/usr/local/bin/sso.sh "$target"
# clone and install requirements
/usr/local/bin/setup.sh "$target"
echo ""
echo ""
echo "==================== END DEVBOX ======================"

open_target

