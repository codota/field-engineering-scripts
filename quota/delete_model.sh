#!/usr/bin/env bash

# b5ff943b-972a-45e7-9242-a3367c907072    Claude 3.7 Sonnet
# b5ff943b-972a-45e7-9242-a3367c907073    Claude 4 Sonnet
# d5ff943b-972a-45e7-9242-a3367c907075    Claude 4.5 Haiku
# e5ff943b-972a-45e7-9242-a3367c907076    Claude 4.5 Opus
# c5ff943b-972a-45e7-9242-a3367c907074    Claude 4.5 Sonnet
# f773a0f9-ed11-4a5c-9f5c-729be13b3025    Devstral 24B
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a5    Gemini 2.5 Flash
# 6e47b0ae-7c50-4d25-9b8b-236ea0f368a4    Gemini 2.5 Pro
# d7078896-bbaa-485e-87db-0c37f1631f6e    Gemini 3 Pro
# 8661d015-da2c-4d8c-bc44-a570635c560c    GPT-4.1
# 8661d015-da2c-4d8c-bc44-a570635c560b    GPT-4o
# 8661d015-da2c-4d8c-bc44-a570635c560d    GPT-5
# 01a524ea-36d3-4ebd-a78a-ff5ed37b1530    GPT-5.2
# a773a0f9-ed11-4a5c-9f5c-729be13b3023    GPT-OSS
# f773a0f9-ed11-4a5c-9f5c-729be13b3024    MiniMax M2 230B

model_ids=( 
  "b5ff943b-972a-45e7-9242-a3367c907072"
  "b5ff943b-972a-45e7-9242-a3367c907073"
  "d5ff943b-972a-45e7-9242-a3367c907075"
  "e5ff943b-972a-45e7-9242-a3367c907076"
  "c5ff943b-972a-45e7-9242-a3367c907074"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3025"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a5"
  "6e47b0ae-7c50-4d25-9b8b-236ea0f368a4"
  "d7078896-bbaa-485e-87db-0c37f1631f6e"
  "8661d015-da2c-4d8c-bc44-a570635c560c"
  "8661d015-da2c-4d8c-bc44-a570635c560b"
  "8661d015-da2c-4d8c-bc44-a570635c560d"
  "01a524ea-36d3-4ebd-a78a-ff5ed37b1530"
  "a773a0f9-ed11-4a5c-9f5c-729be13b3023"
  "f773a0f9-ed11-4a5c-9f5c-729be13b3024"
)

declare -A model_names=(
  [b5ff943b-972a-45e7-9242-a3367c907072]="Claude 3.7 Sonnet"
  [b5ff943b-972a-45e7-9242-a3367c907073]="Claude 4 Sonnet"
  [d5ff943b-972a-45e7-9242-a3367c907075]="Claude 4.5 Haiku"
  [e5ff943b-972a-45e7-9242-a3367c907076]="Claude 4.5 Opus"
  [c5ff943b-972a-45e7-9242-a3367c907074]="Claude 4.5 Sonnet"
  [f773a0f9-ed11-4a5c-9f5c-729be13b3025]="Devstral 24B"
  [6e47b0ae-7c50-4d25-9b8b-236ea0f368a5]="Gemini 2.5 Flash"
  [6e47b0ae-7c50-4d25-9b8b-236ea0f368a4]="Gemini 2.5 Pro"
  [d7078896-bbaa-485e-87db-0c37f1631f6e]="Gemini 3 Pro"
  [8661d015-da2c-4d8c-bc44-a570635c560c]="GPT-4.1"
  [8661d015-da2c-4d8c-bc44-a570635c560b]="GPT-4o"
  [8661d015-da2c-4d8c-bc44-a570635c560d]="GPT-5"
  [01a524ea-36d3-4ebd-a78a-ff5ed37b1530]="GPT-5.2"
  [a773a0f9-ed11-4a5c-9f5c-729be13b3023]="GPT-OSS"
  [f773a0f9-ed11-4a5c-9f5c-729be13b3024]="MiniMax M2 230B"
)

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required]\n"
  echo -e "    Required:"
  echo -e "      --id-token <string>            ID token                        example: eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXV..."
  echo -e "      --model-id <int>               Model ID                        example: 3\n"
  echo -e "          Name                 ID"
  echo -e "          -----------------------"
  echo -e "          Claude 3.7 Sonnet    0"
  echo -e "          Claude 4 Sonnet      1"
  echo -e "          Claude 4.5 Haiku     2"
  echo -e "          Claude 4.5 Opus      3"
  echo -e "          Claude 4.5 Sonnet    4"
  echo -e "          Devstral 24B         5"
  echo -e "          Gemini 2.5 Flash     6"
  echo -e "          Gemini 2.5 Pro       7"
  echo -e "          Gemini 3 Pro         8"
  echo -e "          GPT-4.1              9"
  echo -e "          GPT-4o               10"
  echo -e "          GPT-5                11"
  echo -e "          GPT-5.2              12"
  echo -e "          GPT-OSS              13"
  echo -e "          MiniMax M2 230B      14\n"
  echo -e "      --url <string>                 Server URL                      example: https://tabnine.com\n"
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
elif [ -z "${model_id}" ]; then
  error_handler "Please specify a model id:  --model-id <int>"
elif [ -z "${url}" ]; then
  error_handler "Please specify a url:  --url <string>"
elif [ "${model_id}" -gt 14 ]; then
  error_handler "Please specify a valid model id: --model-id <int>"
fi

curl -s -X DELETE "${url}/backoffice/quota/models/price/${model_ids[${model_id}]}" \
  -H "Authorization: Bearer ${id_token}" | jq

exit 0