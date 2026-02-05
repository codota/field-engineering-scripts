#!/usr/bin/env bash

# e5ff943b-972a-45e7-9242-a3367c907076    Claude 4.5 Opus
# f773a0f9-ed11-4a5c-9f5c-729be13b3025    Devstral 24B
# f773a0f9-ed11-4a5c-9f5c-729be13b3024    MiniMax M2 230B

model_ids=( 
  "e5ff943b-972a-45e7-9242-a3367c907076"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3025"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3024"
)

declare -A model_names=(
  [e5ff943b-972a-45e7-9242-a3367c907076]="Claude 4.5 Opus"
  [f773a0f9-ed11-4a5c-9f5c-729be13b3025]="Devstral 24B"
  [f773a0f9-ed11-4a5c-9f5c-729be13b3024]="MiniMax M2 230B"
)

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required] [optional]\n"
  echo -e "    Required:"
  echo -e "      --cache-read-cost <float>      Cache read cost per token       example: 0.0000005"
  echo -e "      --cache-write-cost <float>     Cache write cost per token      example: 0.00001"
  echo -e "      --id-token <string>            ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV..."
  echo -e "      --input-cost <float>           Input cost per token            example: 0.000005"
  echo -e "      --model-id <int>               Model ID                        example: 0\n"
  echo -e "          Name                 ID"
  echo -e "          -----------------------"
  echo -e "          Claude 4.5 Opus      0"
  echo -e "          Devstral 24B         1"
  echo -e "          MiniMax M2 230B      2\n"
  echo -e "      --output-cost                  Output cost per token           example: 0.000025"
  echo -e "      --url <string>                 Server URL                      example: https://tabnine.com\n"
  echo -e "    Optional:"
  echo -e "      --is-active <bool>             true or false                   default: true\n"
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
    --cache-read-cost )
      cache_read_cost=$2
      shift; shift
      ;;
    --cache-write-cost )
      cache_write_cost=$2
      shift; shift
      ;;
    --help )
      show_help
      ;;
    --id-token )
      id_token=$2
      shift; shift
      ;;
    --input-cost )
      input_cost=$2
      shift; shift
      ;;
    --is-active )
      is_active=$2
      shift; shift
      ;;
    --model-id )
      model_id=$2
      shift; shift
      ;;
    --output-cost )
      output_cost=$2
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

is_active=${is_active:-true}

set -e

if [ -z "${cache_read_cost}" ]; then
  error_handler "Please specify a cache read cost:  --cache-read-cost <float>"
elif [ -z "${cache_write_cost}" ]; then
  error_handler "Please specify a cache write cost:  --cache-write-cost <float>"
elif [ -z "${id_token}" ]; then
  error_handler "Please specify an id token:  --id-token <string>"
elif [ -z "${input_cost}" ]; then
  error_handler "Please specify an input cost:  --input-cost <float>"
elif [ -z "${model_id}" ]; then
  error_handler "Please specify a model id:  --model-id <int>"
elif [ -z "${output_cost}" ]; then
  error_handler "Please specify an output cost:  --output-cost <float>"
elif [ -z "${url}" ]; then
  error_handler "Please specify a url:  --url <string>"
elif [ "${model_id}" -gt 2 ]; then
  error_handler "Please specify a valid model id: --model-id <int>"
fi

template='{"cacheReadCost":"","cacheWriteCost":"","creditRatio":1,"id":"","inputCost":"","isActive":"","isFallback":false,"modelName":"","outputCost":""}'

body=$(echo ${template} | jq -c \
  --argjson crc ${cache_read_cost} \
  --argjson cwc ${cache_write_cost} \
  --arg id ${model_ids[${model_id}]} \
  --argjson ic ${input_cost} \
  --argjson ia ${is_active} \
  --arg mn "${model_names[${model_ids[${model_id}]}]}" \
  --argjson oc ${output_cost} \
  '.cacheReadCost = $crc | .cacheWriteCost = $cwc | .id = $id | .inputCost = $ic | .isActive = $ia | .modelName = $mn | .outputCost = $oc'
)

echo ${body} | jq

curl -s -X POST "${url}/backoffice/quota/models/price" \
  -H "Authorization: Bearer ${id_token}" \
  -H "Content-Type: application/json" \
  -d "${body}" | jq

exit 0