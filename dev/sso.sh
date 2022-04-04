#!/bin/bash -i

if [ -z "$BASH_VERSION" ]
then
    exec bash "$0" "$@"
fi


script_folder=`pwd`
workspaces_folder="$(cd "${script_folder}/.." && pwd)"

add-aws-config()
{
  rm  -rf ~/.aws/config
  count=`jq '.aws_roles | length' main.code-workspace`
  mkdir -p ~/.aws
  touch ~/.aws/config
  for ((i=0; i<$count; i++)); do
      profile=`jq -r '.aws_roles['$i'].profile // empty' main.code-workspace`
      output=`jq -r '.aws_roles['$i'].output // empty' main.code-workspace`
      region=`jq -r '.aws_roles['$i'].region // empty' main.code-workspace`
      role_name=`jq -r '.aws_roles['$i'].role_name // empty' main.code-workspace`
      role_account_id=`jq -r '.aws_roles['$i'].role_account_id // empty' main.code-workspace`
      source_profile=`jq -r '.aws_roles['$i'].source_profile // empty' main.code-workspace`
      sso_start_name=`jq -r '.aws_roles['$i'].sso_start_name // empty' main.code-workspace`
      sso_role_name=`jq -r '.aws_roles['$i'].sso_role_name // empty' main.code-workspace`
      sso_account_id=`jq -r '.aws_roles['$i'].sso_account_id // empty' main.code-workspace`
      {
          echo "[profile $profile]"
      } >> ~/.aws/config

      if [ ! -z "$role_name" ]; then
        {
          echo "role_arn=arn:aws:iam::$role_account_id:role/$role_name"
        } >> ~/.aws/config
      fi
      if [ ! -z "$source_profile" ]; then
        {
          echo "source_profile=$source_profile"
        } >> ~/.aws/config
      fi
      if [ ! -z "$sso_role_name" ]; then
        {
          echo "sso_start_url = https://$sso_start_name.awsapps.com/start"
          echo "sso_region=$region"
          echo "sso_account_id=$sso_account_id"
          echo "sso_role_name=$sso_role_name"
          trigger_sso_signin=$profile
        } >> ~/.aws/config
      fi
      {
          echo "output=$output"
          echo "region=$region"
          echo ""
      } >> ~/.aws/config
      if [ ! -z "$trigger_sso_signin" ]; then
        aws sso login --profile $trigger_sso_signin
      fi
  done
}


if [ -f "${script_folder}/main.code-workspace" ]; then

   cd "${script_folder}"

  # login aws
  aws_roles="$(jq -cr '.aws_roles // empty' main.code-workspace)"
  if [ ! -z "$aws_roles" ]; then
      add-aws-config
  fi
fi
