#! /bin/bash

set -e

script_folder="$1"
script_folder_name="$(echo $1 | cut -d/ -f6)"
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
  for i in $(jq -cr '.folders[] | (.repo) // empty' "${script_folder}/main.code-workspace"); do
       if [ ! -z "$i" ]; then
        clone-repo "$i" > /dev/null 2>&1 ||  echo "Error cloning $i, ensure your email $USER_EMAIL has access to it"
      fi
  done


  #install pip requirements
  if [[ ! -f "${setup_installs}/_${script_folder_name}_install_pip_success" ]]; then

    for i in $(jq -cr '.folders[] | (.repo) // empty' "${script_folder}/main.code-workspace"); do
        if [ ! -z "$i" ]; then
          install-requires  "$i" > /dev/null 2>&1 ||  continue
        fi
    done

    touch "${setup_installs}/_${script_folder_name}_install_pip_success"
   else
      echo "Already installed pip requirements"
   fi

  #install editable pip requirements
  if [[ ! -f "${setup_installs}/_${script_folder_name}_install_editable_pip_success" ]]; then

    for i in $(jq -cr '.folders[] | (.repo) // empty' "${script_folder}/main.code-workspace"); do

        if [ ! -z "$i" ]; then
             target="$repos_folder/$(echo $i | cut -d/ -f2)"
            if [[ -f "$target/setup.py" ]]; then
              echo "Installing package as pip local $target"
              $USER_WORKSPACE/configs/virenv/bin/python -m pip install -e $target
            fi 
        fi
        
    done

    touch "${setup_installs}/_${script_folder_name}_install_editable_pip_success"
   else
      echo "Already installed editable pip requirements"
   fi

else
  install-requires ${script_folder}
fi
