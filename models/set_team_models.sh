#!/usr/bin/env bash

models=( 
  "644ab648-a9df-4ffd-875d-ddd67fd2cb8b"
  "31df793f-dd67-4cb9-8ba3-21e8d922ecac"
  "ab10f730-caa3-46ee-8ab2-81667a46650e"
  "24bb7462-1e18-4145-a2cb-81c428b72177"
  "8661d015-da2c-4d8c-bc44-a570635c560b"
  "d24e7445-9ddf-43e1-bd13-92245b3fe5a8"
  "564172fb-5d9d-49ba-b592-d5ac3a70b39e"
  "e1392fff-9ef8-48cc-baad-9b8a6235696d"
  "48bf942b-1914-4506-9cd9-7f0d17dfa104"
)

function getModels() {
  local model_id=($(echo ${1} | tr ',' ' '))
  local model_uuid=""
  
  for id in "${model_id[@]}"; do
    if [ -n "${model_uuid}" ]; then
      model_uuid+=","
    fi
    model_uuid+="\"${models[id]}\""
  done
  
  echo "[${model_uuid[@]}]"
}

function getTeamId() {
  local id_token=$1
  local team_name=$2
  local url=$3
  local team_id=$(curl -s "${url}/organization/teams" -H "Accept: application/json" -H "Authorization: Bearer ${id_token}" \
    | jq -c --arg n ${team_name} '.data[] | {id,name} | select(.name==$n)')
  echo ${team_id} | jq -r '.id'
}

function getTeamModels() {
  local id_token=$1
  local url=$2
  local team_models=$(curl -s "${url}/organization/settings" -H "Accept: application/json" -H "Authorization: Bearer ${id_token}" \
    | jq -c '.settings.teamChatModels')
  echo ${team_models}
}

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required]\n"
  echo -e "    Required:"
  echo -e "      --id-token <string>          ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV..."
  echo -e "      --model-id <string>          Model IDs, comma separated      example: 1,2,3\n"
  echo -e "          Name                       ID"
  echo -e "          -----------------------------"
  echo -e "          Claude 3.5 Sonnet          0"
  echo -e "          Claude 3.5 Sonnet (v2)     1"
  echo -e "          GPT-3.5 Turbo              2"
  echo -e "          GPT-4 Turbo                3"
  echo -e "          GPT-4o                     4"
  echo -e "          Llama 3.1 405B             5"
  echo -e "          Llama 3.1 70B              6"
  echo -e "          Mistral 7B                 7"
  echo -e "          Tabnine Protected          8\n"
  echo -e "      --team-name <string>         Team name                       example: Tabnine Team (case sensitive)"
  echo -e "                                                                      note: Use \"default\" for the default team\n"
  echo -e "      --url <string>               Server URL                      example: https://tabnine.com\n"
  exit 0
}

if [ -z "$(which curl)" ]; then
  echo -e "\n  Please install Helm - https://curl.se/download.html\n"
  exit 1
elif [ -z "$(which yq)" ]; then
  echo -e "\n  Please install yq - https://github.com/mikefarah/yq\n"
  exit 1
elif [ $# -lt 8 ]; then
  show_help
fi

while [ $# -gt 0 ]; do
  case $1 in
    --help )
      show_help
      ;;
    --id-token )
      id_token=$2
      shift; shift
      ;;
    --model-id )
      model_id=$2
      shift; shift
      ;;
    --team-name )
      team_name=$2
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

if [ -z "${id_token}" ]; then
  echo -e "\n  Please specify an id token:  --id-token <string>\n"
  exit 1
elif [ -z "${model_id}" ]; then
  echo -e "\n  Please specify a model id:  --model-id <string>\n"
  exit 1
elif [ -z "${team_name}" ]; then
  echo -e "\n  Please specify a team id:  --team-name <string>\n"
  exit 1
fi

set -e

if [ "${team_name}" != "default" ]; then
  team_id=$(getTeamId ${id_token} ${team_name} ${url})
else
  team_id="defaultTeam"
fi

if [ -z "${team_id}" ]; then
  echo -e "\n  Invalid team name:  ${team_name}\n"
  exit 1
else
  models=$(getModels ${model_id[@]})
  team_models=$(getTeamModels ${id_token} ${url})
  
  if [ "${team_models}" == "null" ]; then
    body=$(jq -cn --arg m ${models[8]} '{"teamChatModels":{"defaultTeam":{"models":[$m]}}}')
    curl -s -X PATCH "${url}/organization/settings" -H "Authorization: Bearer ${id_token}" -H "Content-Type: application/json" -d "${body}"
  fi
  
  team_models=$(jq -cn --argjson m ${team_models} '{"teamChatModels":$m}')
  body=$(echo ${team_models} | jq -c --arg i ${team_id} --argjson m ${models} '.teamChatModels += {$i:{"models":$m}}')
  curl -s -X PATCH "${url}/organization/settings" -H "Authorization: Bearer ${id_token}" -H "Content-Type: application/json" -d "${body}" \
    | jq '.settings.teamChatModels'
fi

exit 0
