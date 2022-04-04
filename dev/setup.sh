#!/bin/bash -i

if [ -z "$BASH_VERSION" ]
then
    exec bash "$0" "$@"
fi

add-ssh-key()
{
if [[ -z "${GH_SSH_KEY}" ]]; then
  AUTH=""
else
  echo "Setting auth to ssh"
  AUTH="ssh"
  mkdir -p ~/.ssh
  echo -e "${GH_SSH_KEY}" >>~/.ssh/id_rsa
  touch ~/.ssh/config
  {
    echo "Host github.com"
    echo " IdentityFile ~/.ssh/id_rsa"
    echo " StrictHostKeyChecking no"
  } >>~/.ssh/config
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/id_rsa
  chmod 600 ~/.ssh/config
fi
}

script_folder=`pwd`
workspaces_folder="$(cd "${script_folder}/.." && pwd)"

clone-repo()
{
    directory="$(basename "$1")"
    cd "${workspaces_folder}"

    if [ ! -d "$directory" ]; then

        if [ "$AUTH" = "ssh" ]; then
            git clone "git@github.com:$1.git"
        else
            git clone "https://github.com/$1"
        fi
    else 
        echo "Already cloned $1"
    fi
}

install-requires()
{
    cd "${1}"

    if [[ -f "package.json" ]]; then
      yes | npm --prefix . install .
    fi 

    if [[ -f "requirements.txt" ]]; then
       /workspaces/virenv/bin/python -m pip install -r requirements.txt
    fi

}

  # create envs dir
mkdir -p /workspaces/envs
touch /workspaces/envs/dev
sudo mkdir -p /var/log/exported
sudo chmod 777 /var/log/exported

echo "ENVIRONMENT=develop" >> /workspaces/envs/dev
echo "IS_LOCAL=true" >> /workspaces/envs/dev

# set up virenv and packages
python -m venv /workspaces/virenv
/workspaces/virenv/bin/python -m pip install --upgrade pip
/workspaces/virenv/bin/python -m pip install --upgrade pylint
/workspaces/virenv/bin/python -m pip install --upgrade autopep8
/workspaces/virenv/bin/python -m pip install --upgrade black
/workspaces/virenv/bin/python -m pip install --upgrade isort
/workspaces/virenv/bin/python -m pip install --upgrade flake8
/workspaces/virenv/bin/python -m pip install --upgrade pyflakes
/workspaces/virenv/bin/python -m pip install --upgrade pre-commit

# set up workspace
if [ -f "${script_folder}/main.code-workspace" ]; then

  # set up ssh keys if any
  add-ssh-key

  # clone repos
  for i in $(jq -cr '.folders[] | (.repo) // empty' main.code-workspace); do
       if [ ! -z "$i" ]; then
        clone-repo "$i"
      fi
  done
  cd "${script_folder}"

  #install pip requirements
  if [[ ! -f "${workspaces_folder}/_install_pip_success" ]]; then

    for directory in ${workspaces_folder}/*; do
      if [ -d "$directory" ]; then
        install-requires "$directory"
      fi
    done
    touch "${workspaces_folder}/_install_pip_success"
   else
      echo "Already installed pip requirements"
   fi
   cd "${script_folder}"


  #install editable pip requirements
  if [[ ! -f "${workspaces_folder}/_install_editable_pip_success" ]]; then

    for directory in ${workspaces_folder}/*; do
      if [ -d "$directory" ]; then
        if [[ -f "$directory/setup.py" ]]; then
          echo "Installing package as pip local $directory"
          /workspaces/virenv/bin/python -m pip install -e $directory
        fi 
      fi
    done
    touch "${workspaces_folder}/_install_editable_pip_success"
   else
      echo "Already installed editable pip requirements"
   fi

 sudo cp /usr/local/bin/setup.sh ${workspaces_folder}/setup.sh
 sudo cp /usr/local/bin/sso.sh ${workspaces_folder}/sso.sh
 sudo chmod +x ${workspaces_folder}/setup.sh
 sudo chmod +x ${workspaces_folder}/sso.sh

else
  install-requires ${script_folder}
fi
