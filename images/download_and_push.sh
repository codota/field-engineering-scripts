#!/usr/bin/env bash

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required] [options]\n"
  echo -e "    Required:"
  echo -e "      --registry <string>                    Target registry hostname                example: docker.io\n"
  echo -e "    Options:"
  echo -e "      --all                                  All container images"
  echo -e "      --attribution-chart <file|path|url>    Helm chart location                     default: oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"
  echo -e "      --attribution-lookup                   Enable local attribution lookup"
  echo -e "      --attribution-values <file>            Helm chart values file                  example: ./values.yaml"
  echo -e "      --chart <file|path|url>                Helm chart location                     default: oci://registry.tabnine.com/self-hosted/tabnine-cloud"
  echo -e "      --cleanup                              Delete downloaded images"
  echo -e "      --dry-run                              Print docker commands"
  echo -e "      --ecr                                  Print ECR repository names"
  echo -e "      --external-chat                        External chat models only"
  echo -e "      --list <file>                          List of images"
  echo -e "      --repo <string>                        Target registry repository for --list   default: tabnine"
  echo -e "      --values <file>                        Helm chart values file"
  echo -e "      --version <string>                     Helm chart version                      default: latest\n"
  exit 0
}

function display_handler () {
  echo -e "\n  ${1}\n"
}

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

if ! command -v docker &> /dev/null; then
  error_hadler "Please install Docker - https://docs.docker.com/engine/install/"
elif ! command -v helm &> /dev/null; then
  error_handler "Please install Helm - https://helm.sh/docs/intro/install/"
elif ! command -v yq &> /dev/null; then
  error_handler "Please install yq >= 1.7 - https://github.com/mikefarah/yq"
elif [ $# -lt 2 ]; then
  show_help
fi

while [ $# -gt 0 ]; do
  case $1 in
    --all )
      all=true
      shift
      ;;
    --attribution-chart )
      attribution_chart=${2%/}
      shift; shift
      ;;
    --attribution-lookup )
      attribution_lookup=true
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
    --external-chat )
      external_chat=true
      shift
      ;;
    --ecr )
      ecr=true
      shift
      ;;
    --help )
      show_help
      ;;
    --list )
      list=${2%/}
      shift; shift
      ;;
    --registry )
      registry=$2
      shift; shift
      ;;
    --repo )
      repo=$2
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
      error_handler "Invalid Parameter  $1"
      ;;
  esac
done

if [ -z "${registry}" ]; then
  error_handler "Please specify a registry:  --registry <hostname>"
elif [ ! -f "${values}" ] && [ ! -f "${list}" ]; then
  error_handler "Please specify a Helm chart values file or list of images:  --values <file> or --list <file>"
elif [ -n "${attribution_lookup}" ] && [ ! -f "${attribution_values}" ]; then
  error_handler "Please specify a Helm Chart values file:  --attribution-values <file>"
elif [ -n "${output}" ] && [ ! -d "${output}" ]; then
  error_handler "Please specify an output directory:  --output <path>"
fi

set -e

attribution_chart=${attribution_chart:-"oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"}
chart=${chart:-"oci://registry.tabnine.com/self-hosted/tabnine-cloud"}
ecr_repos=()
registry=$(echo ${registry} | sed 's/\//\\\//g')
repo=${repo:-tabnine}

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
  if [ -z "${all}" ]; then
    helm template tabnine ${chart} \
      --namespace tabnine \
      --set global.image.baseRepo=public \
      --set global.image.privateRepo=private \
      --set global.image.registry=registry.tabnine.com \
      --set logs-aggregation.extraContainers[0].image=registry.tabnine.com/public/blacklabelops/logrotate:1.3 \
      --set nats-io.container.image.registry=registry.tabnine.com/public \
      --set nats-io.natsBox.container.image.registry=registry.tabnine.com/public \
      --set nats-io.promExporter.image.registry=registry.tabnine.com/public \
      --set nats-io.reloader.image.registry=registry.tabnine.com/public \
      --set prometheus-blackbox-exporter.global.imageRegistry=registry.tabnine.com/public \
      --skip-tests \
      --values "${values}" \
      --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u > images.tmp
    
    if [ -n "${attribution_lookup}" ]; then
      helm template tabnine ${attribution_chart} \
        --namespace tabnine \
        --set global.image.baseRepo=public \
        --set global.image.privateRepo=private \
        --set global.image.registry=registry.tabnine.com \
        --skip-tests \
        --values "${attribution_values}" \
        --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u >> images.tmp
    fi
    
    if [ -n "${external_chat}" ]; then
      images=($(cat images.tmp))
      for i in ${!images[@]}; do
        if [[ "${images[i]}" != *"chat:"* ]]; then
          temp+=(${images[i]})
        fi
      done
      printf "%s\n" "${temp[@]}" > images.tmp
    fi
    
    sort -o images.tmp images.tmp
    images_list=$(cat images.tmp)
    rm -rf images.tmp
  else
    helm template tabnine ${chart} \
      --namespace tabnine \
      --set analytics.ScheduledCsvEmailReporting.enabled=true \
      --set attribution.enabled=true \
      --set auth.teamSync.cronjob.enabled=true \
      --set backup.enabled=true \
      --set clickhouse.enabled=true \
      --set coaching.enabled=true \
      --set global.image.baseRepo=public \
      --set global.image.privateRepo=private \
      --set global.image.registry=registry.tabnine.com \
      --set global.monitoring.enabled=true \
      --set global.telemetry.enabled=true \
      --set indexer.enabled=true \
      --set logs-aggregation.enabled=true \
      --set logs-aggregation.extraContainers[0].image=registry.tabnine.com/public/blacklabelops/logrotate:1.3 \
      --set logs-collection.enabled=true \
      --set nats-io.enabled=true \
      --set nats-io.container.image.registry=registry.tabnine.com/public \
      --set nats-io.natsBox.container.image.registry=registry.tabnine.com/public \
      --set nats-io.promExporter.image.registry=registry.tabnine.com/public \
      --set nats-io.reloader.image.registry=registry.tabnine.com/public \
      --set postgresql.enabled=true \
      --set prometheus-blackbox-exporter.global.imageRegistry=registry.tabnine.com/public \
      --set scim.enabled=true \
      --set redis.enabled=true \
      --set reranker.enabled=true \
      --skip-tests \
      --values "${values}" \
      --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u > images.tmp
    
    helm template tabnine ${attribution_chart} \
      --namespace tabnine \
      --set global.image.baseRepo=public \
      --set global.image.privateRepo=private \
      --set global.image.registry=registry.tabnine.com \
      --skip-tests \
      --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u >> images.tmp
    
    sort -o images.tmp images.tmp
    images_list=$(cat images.tmp)
    rm -rf images.tmp
  fi
fi

if [ -n "${ecr}" ]; then
  for image in ${images_list[@]}; do
    ecr_repos+=($(echo ${image} | \
      sed -e "s/registry.tabnine.com\/private/${registry}\/${private_repo}/g" | \
      sed -e "s/registry.tabnine.com\/public/${registry}\/${base_repo}/g" | \
      sed -e "s/quay.io/${registry}\/${base_repo}/g" | \
      sed 's|:.*||'))
  done
  
  clear
  display_handler "Please create the following AWS ECR repositories before continuing:"
  for name in ${ecr_repos[@]}; do
    echo -e "    ${name}"
  done
  
  display_handler "AWS CLI commands:"
  for name in ${ecr_repos[@]}; do
    echo -e "    aws ecr create-repository --repository-name ${name}"
  done
  echo
  
  read -p "  Continue?  (yes/no) " continue
  if [ "${continue}" != "y" ] && [ "${continue}" != "yes" ]; then
    exit 0
  fi
  echo
fi

for image in ${images_list[@]}; do
  target=$(echo ${image} | \
    sed -e "s/registry.tabnine.com\/private/${registry}\/${private_repo}/g" | \
    sed -e "s/registry.tabnine.com\/public/${registry}\/${base_repo}/g" | \
    sed -e "s/quay.io/${registry}\/${base_repo}/g")
  
  if [ -z "${dry_run}" ]; then
    docker pull --platform=linux/amd64 ${image}
    docker tag ${image} ${target}
    docker push ${target}
    docker rmi ${target}
    
    if [ -n "${cleanup}" ]; then
      docker rmi ${image}
    fi
  else
    echo "docker pull --platform=linux/amd64 ${image}"
    echo "docker tag ${image} ${target}"
    echo "docker push ${target}"
    echo "docker rmi ${target}"
    
    if [ -n "${cleanup}" ]; then
      echo "docker rmi ${image}"
    fi
  fi
  echo
done

exit 0