#!/usr/bin/env bash

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

function show_help() {
  echo -e "\n  Usage: ${0##*/} [options]\n"
  echo -e "    Options:"
  echo -e "      --attribution-chart <file|path|url>    Helm chart location             default: oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"
  echo -e "      --attribution-enabled                  Enable local attribution"
  echo -e "      --attribution-values <file>            Helm chart values file          example: ./values.yaml"
  echo -e "      --chart <file|path|url>                Helm chart location             default: oci://registry.tabnine.com/self-hosted/tabnine-cloud"
  echo -e "      --cleanup                              Delete downloaded images"
  echo -e "      --dry-run                              Print docker commands"
  echo -e "      --list <file>                          List of images                  example: ./images.txt"
  echo -e "      --output <path>                        Write images to specifc path    default: ./"
  echo -e "      --values <file>                        Helm chart values file          example: ./values.yaml"
  echo -e "      --version <string>                     Helm chart version              default: latest\n"
  exit 0
}

if ! command -v docker &> /dev/null; then
  error_handler "Please install docker - https://docs.docker.com/engine/install/"
elif ! command -v helm &> /dev/null; then
  error_handler "Please install helm - https://helm.sh/docs/intro/install/"
elif ! command -v jq &> /dev/null; then
  error_handler "Please install yq >= 1.7 - https://github.com/mikefarah/yq"
elif [ $# -lt 2 ]; then
  show_help
fi

while [ $# -gt 0 ]; do
  case $1 in
    --attribution-chart )
      attribution_chart=${2%/}
      shift; shift
      ;;
    --attribution-enabled )
      attribution_enabled=true
      shift;
      ;;
    --attribution-values )
      attribution_values=${2%/}
      shift; shift
      ;;
    --chart )
      chart=${2%/}
      shift; shift
      ;;
    --cleanup )
      cleanup=true
      shift
      ;;
    --dry-run )
      dry_run=true
      shift
      ;;
    --help )
      show_help
      ;;
    --list )
      list=${2%/}
      shift; shift
      ;;
    --output )
      output=${2%/}
      shift; shift
      ;;
    --values )
      values=${2%/}
      shift; shift
      ;;
    --version )
      version=$2
      shift; shift
      ;;
    * )
      error_handler "Invalid Parameter:  $1"
      ;;
  esac
done

if [ ! -f "${values}" ] && [ ! -f "${list}" ]; then
  error_handler "Please specify a Helm chart values file or list of images:  --values <file> or --list <file>"
elif [ -n "${attribution_enabled}" ] && [ ! -f "${attribution_values}" ]; then
  error_handler "Please specify a Helm Chart values file:  --attribution-values <file>"
elif [ -n "${output}" ] && [ ! -d "${output}" ]; then
  error_handler "Please specify an output directory:  --output <path>"
fi

set -e

attribution_chart=${attribution_chart:-"oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"}
chart=${chart:-"oci://registry.tabnine.com/self-hosted/tabnine-cloud"}
output=${output:-$(pwd)}

if [ -f "${list}" ]; then
  base_repo=$(echo ${repo} | sed 's/\//\\\//g')
  private_repo=$(echo ${repo} | sed 's/\//\\\//g')
else
  base_repo=$(cat ${values} | yq '.global.image.baseRepo' | sed 's/\//\\\//g')
  private_repo=$(cat ${values} | yq '.global.image.privateRepo' | sed 's/\//\\\//g')
fi

if [ -f "${list}" ]; then
  images_list=$(cat ${list})
else
  helm template tabnine ${chart} \
    --namespace tabnine \
    --set global.image.baseRepo=public \
    --set global.image.privateRepo=private \
    --set global.image.registry=registry.tabnine.com \
    --set inference.nats.container.image.registry=registry.tabnine.com/public \
    --set inference.nats.natsBox.container.image.registry=registry.tabnine.com/public \
    --set inference.nats.promExporter.image.registry=registry.tabnine.com/public \
    --set inference.nats.reloader.image.registry=registry.tabnine.com/public \
    --set logs-aggregation.extraContainers[0].image=registry.tabnine.com/public/blacklabelops/logrotate:1.3 \
    --set nats-io.container.image.registry=registry.tabnine.com/public \
    --set nats-io.natsBox.container.image.registry=registry.tabnine.com/public \
    --set nats-io.promExporter.image.registry=registry.tabnine.com/public \
    --set nats-io.reloader.image.registry=registry.tabnine.com/public \
    --set prometheus-blackbox-exporter.global.imageRegistry=registry.tabnine.com/public \
    --set qdrant2.image.repository=registry.tabnine.com/public/qdrant/qdrant \
    --skip-tests \
    --values "${values}" \
    --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u > ${output}/images.tmp
  
  if [ -n "${attribution_enabled}" ]; then
    helm template tabnine ${attribution_chart} \
      --namespace tabnine \
      --set global.image.baseRepo=public \
      --set global.image.privateRepo=private \
      --set global.image.registry=registry.tabnine.com \
      --skip-tests \
      --values "${attribution_values}" \
      --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u >> ${output}/images.tmp
  fi
  
  sort -o ${output}/images.tmp ${output}/images.tmp
  images_list=$(cat ${output}/images.tmp)
  rm -rf ${output}/images.tmp
fi

for image in ${images_list[@]}; do
  if [ -z "${dry_run}" ]; then
    docker pull ${image}
    docker save ${image} > ${output}/$(echo ${image} | awk -F'/' '{split($NF, a, ":"); print a[1] "-" a[2] ".tar"}')
    
    if [ -n "${cleanup}" ]; then
      docker rmi ${image}
    fi
  else
    filename=${output}/$(echo ${image} | awk -F'/' '{split($NF, a, ":"); print a[1] "-" a[2] ".tar"}')
    echo "docker pull ${image}"
    echo "docker save ${image} > ${filename}"
    
    if [ -n "${cleanup}" ]; then
      echo "docker rmi ${image}"
    fi
  fi
  echo
done

exit 0
