#!/usr/bin/env bash

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required]\n"
  echo -e "    Required:"
  echo -e "      --organization-id <string>     Organization ID     example: ee4b8bd9-1cd4-4c7b-89b0-e1e9a00cf320"
  echo -e "      --password <string>            Password            example: Tabnine!23"
  echo -e "      --url <string>                 Server URL          example: https://tabnine.com"
  echo -e "      --username <string>            Username            example: admin@tabnine.com\n"
  exit 0
}

if [ -z "$(which jq)" ]; then
  echo -e "\n  Please install jq >= 1.7 - https://jqlang.org/download/\n"
  exit 1
elif [ $# -lt 8 ]; then
  show_help
fi

while [ $# -gt 0 ]; do
  case $1 in
    --help )
      show_help
      ;;
    --organization-id )
      organization_id=$2
      shift; shift
      ;;
    --password )
      password=$2
      shift; shift
      ;;
    --url )
      url=${2%/}
      shift; shift
      ;;
    --username )
      username=$2
      shift; shift;
      ;;
    * )
      echo -e "\n  Invalid Parameter:  $1\n"
      exit
      ;;
  esac
done

if [ -z "${organization_id}" ]; then
  echo -e "\n  Please specify an organization id:  --organization-id <string>\n"
  exit 1
elif [ -z "${password}" ]; then
  echo -e "\n  Please specify a password:  --password <string>\n"
  exit 1
elif [ -z "${url}" ]; then
  echo -e "\n  Please specify a url:  --url <string>\n"
  exit 1
elif [ -z "${username}" ]; then
  echo -e "\n  Please specify a username:  --username <string>\n"
  exit 1
fi

set -e

curl -s -X POST "${url}/auth/sign-in/username-password" \
  -H "Content-Type: application/json" \
  -d $(jq -cn --arg o "${organization_id}" --arg p "${password}" --arg u "${username}" '{"organizationId": $o, "password": $p, "username": $u}') \
  | jq -r '.idToken'

exit 0
