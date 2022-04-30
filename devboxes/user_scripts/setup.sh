#! /bin/bash

if [ -z "$BASH_VERSION" ]
then
    exec bash "$0" "$@"
fi

script_folder="$1"
repos_folder="$USER_WORKSPACE/repos"
setup_installs="$USER_WORKSPACE/configs/installs"

clone-repo()
{
    target="$repos_folder/$(echo $1 | cut -d/ -f2)"

    if [ ! -d "$target" ]; then
      git clone "git@github.com:$1.git" "$target"
    else 
        echo "Already cloned $1"
    fi
}

install-requires()
{
    target="$repos_folder/$(echo $1 | cut -d/ -f2)"
    cd "$target"

    if [[ -f "package.json" ]]; then
      yes | npm --prefix . install .
    fi 

    if [[ -f "requirements.txt" ]]; then
       $USER_WORKSPACE/configs/virenv/bin/python -m pip install -r requirements.txt
    fi

}


# set up workspace
if [ -f "${script_folder}/main.code-workspace" ]; then

  # clone repos
  for i in $(jq -cr '.folders[] | (.repo) // empty' main.code-workspace); do
       if [ ! -z "$i" ]; then
        clone-repo "$i"
      fi
  done


  #install pip requirements
  if [[ ! -f "${setup_installs}/_install_pip_success" ]]; then

    for directory in ${repos_folder}/*; do
      if [ -d "$directory" ]; then
        install-requires "$directory"
      fi
    done
    touch "${setup_installs}/_install_pip_success"
   else
      echo "Already installed pip requirements"
   fi

  #install editable pip requirements
  if [[ ! -f "${setup_installs}/_install_editable_pip_success" ]]; then

    for directory in ${repos_folder}/*; do
      if [ -d "$directory" ]; then
        if [[ -f "$directory/setup.py" ]]; then
          echo "Installing package as pip local $directory"
          $USER_WORKSPACE/configs/virenv/bin/python -m pip install -e $directory
        fi 
      fi
    done
    touch "${setup_installs}/_install_editable_pip_success"
   else
      echo "Already installed editable pip requirements"
   fi

else
  install-requires ${script_folder}
fi
