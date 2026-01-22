#!/usr/bin/env bash

# 644ab648-a9df-4ffd-875d-ddd67fd2cb8b    Claude 3.5 Sonnet
# 31df793f-dd67-4cb9-8ba3-21e8d922ecac    Claude 3.5 Sonnet v2
# b5ff943b-972a-45e7-9242-a3367c907072    Claude 3.7 Sonnet
# b5ff943b-972a-45e7-9242-a3367c907073    Claude 4 Sonnet
# d5ff943b-972a-45e7-9242-a3367c907075    Claude 4.5 Haiku
# e5ff943b-972a-45e7-9242-a3367c907076    Claude 4.5 Opus
# c5ff943b-972a-45e7-9242-a3367c907074    Claude 4.5 Sonnet
# 3556bbc0-0a70-4cf0-bbea-bcae6f9a18e4    DeepSeek
# f773a0f9-ed11-4a5c-9f5c-729be13b3025    Devstral 24B
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a3    Gemini 2.0 Flash
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a5    Gemini 2.5 Flash
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a4    Gemini 2.5 Pro
# d7078896-bbaa-485e-87db-0c37f1631f6e    Gemini 3 Pro
# 1fffc46f-af37-41cb-88e5-b180e753b93f    Gemma 3 27B
# 24bb7462-1e18-4145-a2cb-81c428b72177    GPT-4
# 8661d015-da2c-4d8c-bc44-a570635c560c    GPT-4.1
# 8661d015-da2c-4d8c-bc44-a570635c560b    GPT-4o
# ee0de710-8023-4a22-b644-e3afa64997cf    GPT-4o mini
# 8661d015-da2c-4d8c-bc44-a570635c560d    GPT-5
# 01a524ea-36d3-4ebd-a78a-ff5ed37b1530    GPT-5.2
# a773a0f9-ed11-4a5c-9f5c-729be13b3023    GPT-OSS
# d24e7445-9ddf-43e1-bd13-92245b3fe5a8    Llama 3.1 405B
# 564172fb-5d9d-49ba-b592-d5ac3a70b39e    Llama 3.1 70B
# 701d243d-5e11-4ba4-9f35-4e7982544262    Llama 3.3 70B
# f773a0f9-ed11-4a5c-9f5c-729be13b3024    MiniMax M2 230B
# e1392fff-9ef8-48cc-baad-9b8a6235696d    Mistral 7B
# 3556bbc0-0a70-4cf0-bbea-bcae6f9a18e3    Qwen
# e556bbc0-0a70-4cf0-bbea-bcae6f9a18e3    Qwen Coder 3 30B
# 48bf942b-1914-4506-9cd9-7f0d17dfa104    Tabnine Protected

models=( 
  "644ab648-a9df-4ffd-875d-ddd67fd2cb8b"
  "31df793f-dd67-4cb9-8ba3-21e8d922ecac"
  "b5ff943b-972a-45e7-9242-a3367c907072"
  "b5ff943b-972a-45e7-9242-a3367c907073"
  "d5ff943b-972a-45e7-9242-a3367c907075"
  "e5ff943b-972a-45e7-9242-a3367c907076"
  "c5ff943b-972a-45e7-9242-a3367c907074"
  "3556bbc0-0a70-4cf0-bbea-bcae6f9a18e4"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3025"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a3"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a5"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a4"
  "d7078896-bbaa-485e-87db-0c37f1631f6e"
  "1fffc46f-af37-41cb-88e5-b180e753b93f"
  "24bb7462-1e18-4145-a2cb-81c428b72177"
  "8661d015-da2c-4d8c-bc44-a570635c560c"
  "8661d015-da2c-4d8c-bc44-a570635c560b"
  "ee0de710-8023-4a22-b644-e3afa64997cf"
  "8661d015-da2c-4d8c-bc44-a570635c560d"
  "01a524ea-36d3-4ebd-a78a-ff5ed37b1530"
  "a773a0f9-ed11-4a5c-9f5c-729be13b3023"
  "d24e7445-9ddf-43e1-bd13-92245b3fe5a8"
  "564172fb-5d9d-49ba-b592-d5ac3a70b39e"
  "701d243d-5e11-4ba4-9f35-4e7982544262"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3024"
  "e1392fff-9ef8-48cc-baad-9b8a6235696d"
  "3556bbc0-0a70-4cf0-bbea-bcae6f9a18e3"
  "e556bbc0-0a70-4cf0-bbea-bcae6f9a18e3"
  "48bf942b-1914-4506-9cd9-7f0d17dfa104"
)

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

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
  echo -e "          Claude 3.5 Sonnet v2       1"
  echo -e "          Claude 3.7 Sonnet          2"
  echo -e "          Claude 4 Sonnet            3"
  echo -e "          Claude 4.5 Haiku           4"
  echo -e "          Claude 4.5 Opus            5"
  echo -e "          Claude 4.5 Sonnet          6"
  echo -e "          DeepSeek                   7"
  echo -e "          Devstral 24B               8"
  echo -e "          Gemini 2.0 Flash           9"
  echo -e "          Gemini 2.5 Flash           10"
  echo -e "          Gemini 2.5 Pro             11"
  echo -e "          Gemini 3 Pro               12"
  echo -e "          Gemma 3 27B                13"
  echo -e "          GPT-4                      14"
  echo -e "          GPT-4.1                    15"
  echo -e "          GPT-4o                     16"
  echo -e "          GPT-4o mini                17"
  echo -e "          GPT-5                      18"
  echo -e "          GPT-5.2                    19"
  echo -e "          GPT-OSS                    20"
  echo -e "          Llama 3.1 405B             21"
  echo -e "          Llama 3.1 70B              22"
  echo -e "          Llama 3.3 70B              23"
  echo -e "          MiniMax M2 230B            24"
  echo -e "          Mistral 7B                 25"
  echo -e "          Qwen                       26"
  echo -e "          Qwen Coder 3 30B           27"
  echo -e "          Tabnine Protected          28\n"
  echo -e "      --team-name <string>         Team name                       example: Tabnine Team (case sensitive)"
  echo -e "                                                                            Use \"default\" for the default team\n"
  echo -e "      --url <string>               Server URL                      example: https://tabnine.com\n"
  echo -e "    Optional:"
  echo -e "      --reset                                                      reset team models\n"
  exit 0
}

if ! command -v curl &> /dev/null; then
  error_handler "Please install curl - https://curl.se/download.html"
elif ! command -v yq &> /dev/null; then
  error_handler "Please install yq >= 1.7 - https://github.com/mikefarah/yq"
elif [ $# -lt 4 ]; then
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

set -e

if [ -z "${id_token}" ]; then
  error_handler "Please specify an id token:  --id-token <string>"
elif [ -z "${url}" ]; then
  error_handler "Please specify a url:  --url <string>"
fi

if [ -z "${reset}" ]; then
  if [ -z "${model_id}" ]; then
    error_handler "Please specify a model id:  --model-id <string>"
  elif [ -z "${team_name}" ]; then
    error_handler "Please specify a team id:  --team-name <string>"
  fi
  
  if [ "${team_name}" != "default" ]; then
    team_id=$(getTeamId ${id_token} "${team_name}" ${url})
  else
    team_id="defaultTeam"
  fi
  
  if [ -z "${team_id}" ]; then
    error_handler "Invalid team name:  ${team_name}"
  else
    models=$(getModels ${model_id[@]})
    team_models=$(getTeamModels ${id_token} ${url})
    
    if [ "${team_models}" == "null" ]; then
      body=$(jq -cn --arg m ${models[26]} '{"teamChatModels":{"defaultTeam":{"models":[$m]}}}')
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
