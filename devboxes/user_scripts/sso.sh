#!/usr/bin/env bash

set -e

script_folder="$1"
script_folder_name="$(echo $1 | cut -d/ -f6)"

add-aws-config()
{
  count=`jq '.aws_roles | length' "${script_folder_name}.code-workspace"`
  for ((i=0; i<$count; i++)); do
      profile=`jq -r '.aws_roles['$i'].profile // empty' "${script_folder_name}.code-workspace"`
      output=`jq -r '.aws_roles['$i'].output // empty' "${script_folder_name}.code-workspace"`
      region=`jq -r '.aws_roles['$i'].region // empty' "${script_folder_name}.code-workspace"`
      role_name=`jq -r '.aws_roles['$i'].role_name // empty' "${script_folder_name}.code-workspace"`
      role_account_id=`jq -r '.aws_roles['$i'].role_account_id // empty' "${script_folder_name}.code-workspace"`
      source_profile=`jq -r '.aws_roles['$i'].source_profile // empty' "${script_folder_name}.code-workspace"`
      sso_start_name=`jq -r '.aws_roles['$i'].sso_start_name // empty' "${script_folder_name}.code-workspace"`
      sso_role_name=`jq -r '.aws_roles['$i'].sso_role_name // empty' "${script_folder_name}.code-workspace"`
      sso_account_id=`jq -r '.aws_roles['$i'].sso_account_id // empty' "${script_folder_name}.code-workspace"`
      
      if grep -qxF "[profile $profile]" ~/.aws/config
      then
        continue
      fi
      
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

  done
}


if [ -f "${script_folder}/${script_folder_name}.code-workspace" ]; then

   cd "${script_folder}"

  # add aws configs to file
  aws_roles="$(jq -cr '.aws_roles // empty' "${script_folder_name}.code-workspace")"
  if [ ! -z "$aws_roles" ]; then
      echo "> Processing aws configs"
      touch $USER_WORKSPACE/configs/aws/config
      add-aws-config
      echo "> Finished processing aws configs"
      echo ""
      echo ""
  fi
fi
