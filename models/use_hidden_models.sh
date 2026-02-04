#!/usr/bin/env bash

# e5ff943b-972a-45e7-9242-a3367c907076    Claude 4.5 Opus
# 3556bbc0-0a70-4cf0-bbea-bcae6f9a18e4    DeepSeek
# f773a0f9-ed11-4a5c-9f5c-729be13b3025    Devstral 24B
# f773a0f9-ed11-4a5c-9f5c-729be13b3024    MiniMax M2 230B

models=(
  "e5ff943b-972a-45e7-9242-a3367c907076"
  "3556bbc0-0a70-4cf0-bbea-bcae6f9a18e4"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3025"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3024"
)

declare -A modelSettings=(
  [e5ff943b-972a-45e7-9242-a3367c907076]='{"id":"e5ff943b-972a-45e7-9242-a3367c907076","name":"Claude 4.5 Opus","icons":["6392aa91-3b8c-42e5-bfcf-4f0a607e46a4"],"badges":[],"provider":{"id":"e53b77f6-302f-4036-b745-23faf39072a0","name":"Azure Foundry","config":[[{"id":"token","type":"password","label":"Key","isRequired":true,"placeholder":"Enter API Key"},{"id":"deploymentName","type":"text","label":"Deployment Name","isRequired":false,"placeholder":"Enter Azure Deployment Name"}],[{"id":"foundryUrl","type":"text","label":"Foundry URL","isRequired":true,"placeholder":"Enter Azure Foundry URL"}],[{"id":"apiVersion","type":"text","label":"API Version","isRequired":false,"placeholder":"Enter Azure API Version"}],[{"id":"maxTokensPerRequest","type":"number","label":"Max Tokens Per Request","isRequired":false,"placeholder":"Total tokens for input+output"}],[{"id":"maxResponseTokens","type":"number","label":"Max Response Tokens","isRequired":false,"placeholder":"Maximum tokens for response"}]]},"capabilities":["vision","apply.patch","apply.range","edit","agent","generate.patch","anthropic-thinking"],"isRecommended":false},{"id":"e5ff943b-972a-45e7-9242-a3367c907076","name":"Claude 4.5 Opus","icons":["6392aa91-3b8c-42e5-bfcf-4f0a607e46a4"],"badges":[],"provider":{"id":"8320f632-bc54-4816-9b9d-51dbc00dba3f","name":"Bedrock","config":[[{"id":"region","type":"text","label":"Region","isRequired":true,"placeholder":"Bedrock region"}],[{"id":"crossRegion","type":"text","label":"Cross Region","isRequired":true,"placeholder":"cross-region like us. | eu. | ap."}],[{"id":"endpoint","type":"text","label":"Endpoint","isRequired":false,"placeholder":"Bedrock endpoint URL"}],[{"id":"accessKeyId","type":"text","label":"Access Key ID","isRequired":true,"placeholder":"Bedrock Access Key ID"}],[{"id":"secretAccessKey","type":"password","label":"Secret Access Key","isRequired":true,"placeholder":"Bedrock Secret Access Key"}]]},"capabilities":["vision","apply.patch","apply.range","edit","agent","generate.patch","anthropic-thinking"],"isRecommended":false},{"id":"e5ff943b-972a-45e7-9242-a3367c907076","name":"Claude 4.5 Opus","icons":["6392aa91-3b8c-42e5-bfcf-4f0a607e46a4"],"badges":[],"provider":{"id":"3ca20368-310c-490e-934e-7af934f98386","name":"GCP Vertex AI","config":[[{"id":"region","type":"text","label":"Region","isRequired":true,"placeholder":"Google Cloud region"}],[{"id":"projectId","type":"text","label":"Project ID","isRequired":true,"placeholder":"Google Cloud project identifier"}],[{"id":"serviceAccount","type":"text","label":"Service account","isRequired":true,"placeholder":"Vertex AI Credentials JSON (Base64-encoded)"}]]},"capabilities":["vision","apply.patch","apply.range","edit","agent","generate.patch","anthropic-thinking"],"isRecommended":false}'
  [3556bbc0-0a70-4cf0-bbea-bcae6f9a18e4]='{"id":"3556bbc0-0a70-4cf0-bbea-bcae6f9a18e4","name":"DeepSeek","icons":["763eab6f-24a7-4546-a0d0-4b9afdbfae1c"],"badges":[],"provider":{"id":"c01e063c-0a72-4980-ac30-4965deaa48da","name":"OpenAI Compatible","config":[[{"id":"endpoint","type":"text","isRequired":true,"label":"Endpoint","placeholder":"Endpoint URL"}],[{"id":"token","type":"password","isRequired":false,"label":"Key","placeholder":"API Key"}],[{"id":"modelName","type":"text","isRequired":false,"label":"OpenAICompatible Model name","placeholder":"Model name"}],[{"id":"ca","type":"text-area","isRequired":false,"label":"Certificate Authority","placeholder":""},{"id":"ignoreSelfSignedCertificate","type":"checkbox","isRequired":false,"label":"Ignore Self Signed Certificate"}],[{"id":"maxTokensPerRequest","type":"number","isRequired":false,"label":"Max Tokens Per Request","placeholder":"Total tokens for input+output"}],[{"id":"maxResponseTokens","type":"number","isRequired":false,"label":"Max Response Tokens","placeholder":"Maximum tokens for response"}],[{"id":"maxContextLength","type":"number","isRequired":false,"label":"Max Context Length","placeholder":"Maximum context window size"}]]},"capabilities":["apply.range","apply.patch","apply.merge","edit"],"isRecommended":false}'
  [f773a0f9-ed11-4a5c-9f5c-729be13b3025]='{"id":"f773a0f9-ed11-4a5c-9f5c-729be13b3025","name":"Devstral 24B","icons":["cac41a2f-ca44-43c6-a9f8-9ddd7921b42e"],"badges":[],"provider":{"id":"c01e063c-0a72-4980-ac30-4965deaa48da","name":"OpenAI Compatible","config":[[{"id":"endpoint","type":"text","isRequired":true,"label":"Endpoint","placeholder":"Endpoint URL"}],[{"id":"token","type":"password","isRequired":false,"label":"Key","placeholder":"API Key"}],[{"id":"modelName","type":"text","isRequired":false,"label":"OpenAICompatible Model name","placeholder":"Model name"}],[{"id":"ca","type":"text-area","isRequired":false,"label":"Certificate Authority","placeholder":""},{"id":"ignoreSelfSignedCertificate","type":"checkbox","isRequired":false,"label":"Ignore Self Signed Certificate"}],[{"id":"maxTokensPerRequest","type":"number","isRequired":false,"label":"Max Tokens Per Request","placeholder":"Total tokens for input+output"}],[{"id":"maxResponseTokens","type":"number","isRequired":false,"label":"Max Response Tokens","placeholder":"Maximum tokens for response"}],[{"id":"maxContextLength","type":"number","isRequired":false,"label":"Max Context Length","placeholder":"Maximum context window size"}]]},"capabilities":["vision","apply.patch","apply.range","edit","agent","generate.patch"],"isRecommended":false}'
  [f773a0f9-ed11-4a5c-9f5c-729be13b3024]='{"id":"f773a0f9-ed11-4a5c-9f5c-729be13b3024","name":"Minimax M2 230B","icons":[],"badges":[],"provider":{"id":"c01e063c-0a72-4980-ac30-4965deaa48da","name":"OpenAI Compatible","config":[[{"id":"endpoint","type":"text","isRequired":true,"label":"Endpoint","placeholder":"Endpoint URL"}],[{"id":"token","type":"password","isRequired":false,"label":"Key","placeholder":"API Key"}],[{"id":"modelName","type":"text","isRequired":false,"label":"OpenAICompatible Model name","placeholder":"Model name"}],[{"id":"ca","type":"text-area","isRequired":false,"label":"Certificate Authority","placeholder":""},{"id":"ignoreSelfSignedCertificate","type":"checkbox","isRequired":false,"label":"Ignore Self Signed Certificate"}],[{"id":"maxTokensPerRequest","type":"number","isRequired":false,"label":"Max Tokens Per Request","placeholder":"Total tokens for input+output"}],[{"id":"maxResponseTokens","type":"number","isRequired":false,"label":"Max Response Tokens","placeholder":"Maximum tokens for response"}],[{"id":"maxContextLength","type":"number","isRequired":false,"label":"Max Context Length","placeholder":"Maximum context window size"}]]},"capabilities":["vision","apply.patch","apply.range","edit","agent","generate.patch"],"isRecommended":false}'
)

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

function getModels() {
  local model_id=($(echo ${1} | tr ',' ' '))
  local model_uuid=()
  
  for id in "${model_id[@]}"; do
    model_uuid+=("${models[id]}")
  done
  
  echo "${model_uuid[@]}"
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
  echo -e "          Claude 4.5 Opus            0"
  echo -e "          DeepSeek                   1"
  echo -e "          Devstral 24B               2"
  echo -e "          MiniMax M2 230B            3\n"
  echo -e "      --url <string>               Server URL                      example: https://tabnine.com\n"
  echo -e "    Optional:"
  echo -e "      --reset                      Reset hidden models\n"
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
  fi
  
  model_uuids=($(getModels ${model_id[@]}))
  
  for id in "${model_uuids[@]}"; do
    model_settings+=("${modelSettings[${id}]}")
  done
  
  model_settings=$(printf "%s," "${model_settings[@]}")
  model_settings="${model_settings%,}"

  curl -s -X PATCH "${url}/organization/settings/admin-ui-added-models" -H "Authorization: Bearer ${id_token}" \
    -H "Content-Type: application/json" -d "{\"models\":[${model_settings}]}" | jq '.settings.adminUiAddedModels'
else
  curl -s -X DELETE "${url}/organization/settings/adminUiAddedModels" -H "Authorization: Bearer ${id_token}"
  curl -s "${url}/organization/settings" -H "Authorization: Bearer ${id_token}" | jq '.settings.adminUiAddedModels'
fi

exit 0