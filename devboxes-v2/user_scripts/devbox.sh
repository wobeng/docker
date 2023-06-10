#!/usr/bin/env bash

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
    python3 -m venv $USER_WORKSPACE/extras/virenv
    $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pip
    $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade ruff
    $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pytest
    $USER_WORKSPACE/extras/virenv/bin/python -m pip install --upgrade pre-commit

fi

man () {
     echo "Oops, Something went wrong"
     echo "Command format: devbox setup <org>/<username>"
     echo "Ensure your public key below (~/.ssh/id_ed25519.pub) is added to your $USER_EMAIL github account settings https://github.com/settings/keys"
     echo ""
     cat $HOME/.ssh/id_ed25519.pub
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

  git clone "git@github.com:$repo_name.git" "$target" > /dev/null 2>&1
  prev_exit="${?}"
  if [ "${prev_exit}" -ne 0 ] ; then
    man 
  fi

fi

set -e

# set up sso config
/usr/local/bin/sso.sh "$target"
# clone and install requirements
/usr/local/bin/setup.sh "$target"
echo ""
echo ""
echo "==================== END DEVBOX ======================"

open_target

