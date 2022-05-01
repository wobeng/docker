#! /bin/bash

repo_name=$2
folder=$(echo $repo_name | cut -d/ -f2)
target="$USER_WORKSPACE/repos/$folder"

man () {
     echo "Oops, Something went wrong"
     echo "Command format: devbox setup <org>/<username>"
     echo "Ensure your public key ~/.ssh/id_ed25519.pub is attached to $USER_EMAIL github https://github.com/settings/keys"
     exit 1
}

open_target() {
    if [ -f "$target/main.code-workspace" ]; then
    code "$target/main.code-workspace"
  else
      code -r $target
  fi
  exit 0
}


if [ -z "$repo_name" ]; then
  man
fi


if [ -d  "$target" ] ; then

    echo "$folder already exist, skip cloning..."

else

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

open_target