#!/usr/bin/env bash

# 644ab648-a9df-4ffd-875d-ddd67fd2cb8b    Claude 3.5 Sonnet
# b5ff943b-972a-45e7-9242-a3367c907072    Claude 3.7 Sonnet
# b5ff943b-972a-45e7-9242-a3367c907073    Claude 4 Sonnet
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a3    Gemini 2.0 Flash
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a5    Gemini 2.5 Flash
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a4    Gemini 2.5 Pro
# 8661d015-da2c-4d8c-bc44-a570635c560c    GPT-4.1
# 8661d015-da2c-4d8c-bc44-a570635c560b    GPT-4o
# d24e7445-9ddf-43e1-bd13-92245b3fe5a8    Llama 3.1 405B
# 564172fb-5d9d-49ba-b592-d5ac3a70b39e    Llama 3.1 70B
# e1392fff-9ef8-48cc-baad-9b8a6235696d    Mistral 7B
# 3556bbc0-0a70-4cf0-bbea-bcae6f9a18e3    Qwen2.5-32B-Instruct
# 48bf942b-1914-4506-9cd9-7f0d17dfa104    Tabnine Protected

models=( 
  "644ab648-a9df-4ffd-875d-ddd67fd2cb8b"
  "b5ff943b-972a-45e7-9242-a3367c907072"
  "b5ff943b-972a-45e7-9242-a3367c907073"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a3"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a5"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a4"
  "8661d015-da2c-4d8c-bc44-a570635c560c"
  "8661d015-da2c-4d8c-bc44-a570635c560b"
  "d24e7445-9ddf-43e1-bd13-92245b3fe5a8"
  "564172fb-5d9d-49ba-b592-d5ac3a70b39e"
  "e1392fff-9ef8-48cc-baad-9b8a6235696d"
  "3556bbc0-0a70-4cf0-bbea-bcae6f9a18e3"
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
    | jq -c --arg n "${team_name}" '.data[] | {id,name} | select(.name==$n)')
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
  echo -e "\n  Usage: ${0##*/} [required] [optional]\n"
  echo -e "    Required:"
  echo -e "      --id-token <string>          ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV..."
  echo -e "      --model-id <string>          Model IDs, comma separated      example: 1,2,3\n"
  echo -e "          Name                       ID"
  echo -e "          -----------------------------"
  echo -e "          Claude 3.5 Sonnet          0"
  echo -e "          Claude 3.7 Sonnet          1"
  echo -e "          Claude 4 Sonnet            2"
  echo -e "          Gemini 2.0 Flash           3"
  echo -e "          Gemini 2.5 Flash           4"
  echo -e "          Gemini 2.5 Pro             5"
  echo -e "          GPT-4.1                    6"
  echo -e "          GPT-4o                     7"
  echo -e "          Llama 3.1 405B             8"
  echo -e "          Llama 3.1 70B              9"
  echo -e "          Mistral 7B                 10"
  echo -e "          Qwen2.5-32B-Instruct       11"
  echo -e "          Tabnine Protected          12\n"
  echo -e "      --team-name <string>         Team name                       example: Tabnine Team (case sensitive)"
  echo -e "                                                                            Use \"default\" for the default team\n"
  echo -e "      --url <string>               Server URL                      example: https://tabnine.com\n"
  echo -e "    Optional:"
  echo -e "      --reset                                                      reset team models\n"
  exit 0
}

if [ -z "$(which curl)" ]; then
  echo -e "\n  Please install Helm - https://curl.se/download.html\n"
  exit 1
elif [ -z "$(which jq)" ]; then
  echo -e "\n  Please install jq >= 1.7 - https://jqlang.org/download/\n"
  exit 1
elif [ $# -lt 1 ]; then
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
    --reset )
      reset=true
      shift
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

if [ -z "${reset}" ]; then
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
fi

set -e

if [ -z "${reset}" ]; then
  if [ "${team_name}" != "default" ]; then
    team_id=$(getTeamId ${id_token} "${team_name}" ${url})
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
      body=$(jq -cn --arg m ${models[12]} '{"teamChatModels":{"defaultTeam":{"models":[$m]}}}')
      curl -s -X PATCH "${url}/organization/settings" -H "Authorization: Bearer ${id_token}" -H "Content-Type: application/json" -d "${body}"
    fi
    
    team_models=$(jq -cn --argjson m ${team_models} '{"teamChatModels":$m}')
    body=$(echo ${team_models} | jq -c --arg i ${team_id} --argjson m ${models} '.teamChatModels += {$i:{"models":$m}}')
    curl -s -X PATCH "${url}/organization/settings" -H "Authorization: Bearer ${id_token}" -H "Content-Type: application/json" -d "${body}" \
      | jq '.settings.teamChatModels'
  fi
else
  curl -s -X DELETE "${url}/organization/settings/teamChatModels" -H "Authorization: Bearer ${id_token}"
  curl -s "${url}/organization/settings" -H "Authorization: Bearer ${id_token}" | jq '.settings.teamChatModels'
fi

exit 0