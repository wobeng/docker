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
       git clone "git@github.com:$1.git" "$target" > /dev/null 2>&1
       echo "  Finished cloning $1"
    else 
        echo "  Already cloned $1"
    fi
}

install-requires()
{
    target="$repos_folder/$(echo $1 | cut -d/ -f2)"
    cd "$target"

    if [[ -f "package.json" ]]; then
      echo "  Installing npm packages in $1"
      yes | npm --prefix . install . > /dev/null 2>&1
      echo "  Finished installing npm packages in $1"
    fi 

    if [[ -f "requirements.txt" ]]; then
      echo "  Installing pip packages in $1"
       $USER_WORKSPACE/configs/virenv/bin/python -m pip install -r requirements.txt > /dev/null 2>&1
      echo "  Finished installing pip packages in $1"
    fi

}

install-local-requires()
{
    target="$repos_folder/$(echo $1 | cut -d/ -f2)"
    cd "$target"

    if [[ -f "setup.py" ]]; then
      echo "  Installing local pip packages in $1"
       $USER_WORKSPACE/configs/virenv/bin/python -m pip install -e $target > /dev/null 2>&1
      echo "  Finished installing local pip packages in $1"
    fi

}


workspace_file="${script_folder}/${script_folder_name}.code-workspace"

# set up workspace
if [ -f "${workspace_file}" ]; then

  echo "> Cloning repos"
  # clone repos
  for i in $(jq -cr '.folders[] | (.repo) // empty' "${workspace_file}"); do
       if [ ! -z "$i" ]; then
        clone-repo "$i" ||  echo "  Error cloning $i, ensure your email $USER_EMAIL has access to it"
      fi
  done
  echo "> Finished cloning repos"
  echo ""
  echo ""


  echo "> Installing npm and pip requirements"
  #install npm and pip requirements
  if [[ ! -f "${setup_installs}/_${script_folder_name}_install_pip_success" ]]; then

    for i in $(jq -cr '.folders[] | (.repo) // empty' "${workspace_file}"); do
        if [ ! -z "$i" ]; then
          install-requires  "$i"  ||  echo "  Error installing requirements for $i, if any"
        fi
    done

    touch "${setup_installs}/_${script_folder_name}_install_pip_success"
   else
      echo "  Already installed pip requirements"
   fi
  echo "> Finished installing npm and pip requirements"
  echo ""
  echo ""

  echo "> Installing pip editable requirements"
  #install editable pip requirements
  if [[ ! -f "${setup_installs}/_${script_folder_name}_install_editable_pip_success" ]]; then

    for i in $(jq -cr '.folders[] | (.repo) // empty' "${workspace_file}"); do

        if [ ! -z "$i" ]; then
          install-local-requires  "$i" ||  echo "  Error installing editable requirements for $i, if any"
        fi
        
    done

    touch "${setup_installs}/_${script_folder_name}_install_editable_pip_success"
   else
      echo "  Already installed editable pip requirements"
   fi
  echo "> Finished installing pip editable requirements"

else
  echo "> Installing npm and pip requirements"
  install-requires ${script_folder}
  echo "> Finished installing npm and pip requirements"
fi
