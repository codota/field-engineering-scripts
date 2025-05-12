#!/usr/bin/env bash

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required] [options]\n"
  echo -e "    Required:"
  echo -e "      --values <file>                        Helm Chart values file              example: ./values.yaml\n"
  echo -e "    Options:"
  echo -e "      --all                                  All container images"
  echo -e "      --attribution-chart <file|path|url>    Helm Chart location                 default: oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"
  echo -e "      --attribution-lookup                   Enable local attribution lookup"
  echo -e "      --attribution-values <file>            Helm Chart values file              example: ./values.yaml"
  echo -e "      --chart <file|path|url>                Helm Chart location                 default: oci://registry.tabnine.com/self-hosted/tabnine-cloud"
  echo -e "      --external-chat                        External chat models only"  
  echo -e "      --output <file>                        Write output to a file              default: ./images.list"
  echo -e "      --version <string>                     Helm Chart version                  default: latest\n"
  exit 0
}

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

if ! command -v helm &> /dev/null; then
  error_handler "Please install Helm - https://helm.sh/docs/intro/install"
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
      shift
      ;;
    --attribution-values )
      attribution_values=${2%/}
      shift; shift
      ;;
    --chart )
      chart=${2%/}
      shift; shift
      ;;
    --external-chat )
      external_chat=true
      shift
      ;;
    --help )
      show_help
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

if [ ! -f "${values}" ]; then
  error_handler "Please specify a Helm Chart values file:  --values <file>"
elif [ -n "${attribution_lookup}" ] && [ ! -f "${attribution_values}" ]; then
  error_handler "Please specify a Helm Chart values file:  --attribution-values <file>"
fi

set -e

attribution_chart=${attribution_chart:-"oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"}
chart=${chart:-"oci://registry.tabnine.com/self-hosted/tabnine-cloud"}
output=${output:-images.list}

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
    --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u > ${output}
  
  if [ -n "${attribution_lookup}" ]; then
    helm template tabnine ${attribution_chart} \
      --namespace tabnine \
      --set global.image.baseRepo=public \
      --set global.image.privateRepo=private \
      --set global.image.registry=registry.tabnine.com \
      --skip-tests \
      --values ${attribution_values} \
      --version ${version} | yq --no-doc '.. | .image? | select(.)' | sort -u >> ${output}
  fi
  
  if [ -n "${external_chat}" ]; then
    images=($(cat ${output}))
    for i in ${!images[@]}; do
      if [[ "${images[i]}" != *"chat:"* ]]; then
        temp+=(${images[i]})
      fi
    done
    printf "%s\n" "${temp[@]}" > ${output}
  fi
  
  sort -o ${output} ${output}
else
  helm template tabnine ${chart} \
    --namespace tabnine \
    --set analytics.ScheduledCsvEmailReporting.enabled=true \
    --set apply.enabled=true \
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
    --set nonEvictionRedis.enabled=true \
    --set postgresql.enabled=true \
    --set prometheus-blackbox-exporter.global.imageRegistry=registry.tabnine.com/public \
    --set scim.enabled=true \
    --set redis.enabled=true \
    --set reranker.enabled=true \
    --skip-tests \
    --values "${values}" \
    --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u > ${output}
  
  helm template tabnine ${attribution_chart} \
    --namespace tabnine \
    --set global.image.baseRepo=public \
    --set global.image.privateRepo=private \
    --set global.image.registry=registry.tabnine.com \
    --skip-tests \
    --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u >> ${output}
  
  sort -o ${output} ${output}
fi

exit 0