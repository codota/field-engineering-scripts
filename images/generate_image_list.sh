#!/usr/bin/env bash

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

function show_help() {
  echo -e "\n  Usage: ${0##*/} [required] [options]\n"
  echo -e "    Required:"
  echo -e "      --values <file>                        Helm Chart values file      example: ./values.yaml\n"
  echo -e "    Options:"
  echo -e "      --attribution-chart <file|path|url>    Helm Chart location         default: oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"
  echo -e "      --attribution-enabled                  Enable local attribution"
  echo -e "      --attribution-values <file>            Helm Chart values file      example: ./values.yaml"
  echo -e "      --chart <file|path|url>                Helm Chart location         default: oci://registry.tabnine.com/self-hosted/tabnine-cloud"
  echo -e "      --output <file>                        Write output to a file      default: ./images.list"
  echo -e "      --version <string>                     Helm Chart version          default: latest\n"
  exit 0
}

if ! command -v helm &> /dev/null; then
  error_handler "Please install helm - https://helm.sh/docs/intro/install"
elif ! command -v yq &> /dev/null; then
  error_handler "Please install yq >= 1.7 - https://github.com/mikefarah/yq"
elif [ $# -lt 1 ]; then
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
elif [ -n "${attribution_enabled}" ] && [ ! -f "${attribution_values}" ]; then
  error_handler "Please specify a Helm Chart values file:  --attribution-values <file>"
fi

set -e

attribution_chart=${attribution_chart:-"oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"}
chart=${chart:-"oci://registry.tabnine.com/self-hosted/tabnine-cloud"}
output=${output:-images.list}

helm template tabnine ${chart} \
  --namespace tabnine \
  --set global.image.baseRepo=public \
  --set global.image.privateRepo=private \
  --set global.image.registry=registry.tabnine.com \
  --set clickhouse.image.registry=registry.tabnine.com/public \
  --set clickhouse.image.repository=bitnami/clickhouse \
  --set inference.nats.container.image.registry=registry.tabnine.com/public \
  --set inference.nats.natsBox.container.image.registry=registry.tabnine.com/public \
  --set inference.nats.promExporter.image.registry=registry.tabnine.com/public \
  --set inference.nats.reloader.image.registry=registry.tabnine.com/public \
  --set logs-aggregation.extraContainers[0].image=registry.tabnine.com/public/blacklabelops/logrotate:1.3 \
  --set prometheus-blackbox-exporter.global.imageRegistry=registry.tabnine.com/public \
  --set qdrant2.image.repository=registry.tabnine.com/public/qdrant/qdrant \
  --skip-tests \
  --values "${values}" \
  --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u > ${output}

if [ -n "${attribution_enabled}" ]; then
  helm template tabnine ${attribution_chart} \
    --namespace tabnine \
    --set global.image.baseRepo=public \
    --set global.image.privateRepo=private \
    --set global.image.registry=registry.tabnine.com \
    --skip-tests \
    --values "${attribution_values}" \
    --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u >> ${output}
fi

sort -o ${output} ${output}

exit 0
