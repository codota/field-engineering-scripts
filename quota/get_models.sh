#!/usr/bin/env bash

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required] [optional]\n"
  echo -e "    Required:"
  echo -e "      --id-token <string>          ID token        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV..."
  echo -e "      --url <string>               Server URL      example: https://tabnine.com\n"
  echo -e "    Optional:"
  echo -e "      --active                     Show only active models\n"
  exit 0
}

if ! command -v curl &> /dev/null; then
  error_handler "Please install curl - https://curl.se/download.html"
elif ! command -v yq &> /dev/null; then
  error_handler "Please install yq >= 1.7 - https://github.com/mikefarah/yq"
elif [ $# -lt 1 ]; then
  show_help
fi

while [ $# -gt 0 ]; do
  case $1 in
    --active )
      active=true
      shift
      ;;
    --help )
      show_help
      ;;
    --id-token )
      id_token=$2
      shift; shift
      ;;
    --url )
      url=${2%/}
      shift; shift
      ;;
    * )
      echo -e "\n  Invalid Parameter:  $1\n"
      exit
      ;;
  esac
done

set -e

if [ -z "${id_token}" ]; then
  error_handler "Please specify an id token:  --id-token <string>"
elif [ -z "${url}" ]; then
  error_handler "Please specify a url:  --url <string>"
fi

if [ -n "${active}" ]; then
  query_param="?isActive=true"
fi

curl -s "${url}/backoffice/quota/models/price${query_param}" -H "Authorization: Bearer ${id_token}" | jq '.data.models'

exit 0