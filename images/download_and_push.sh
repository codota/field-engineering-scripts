#!/usr/bin/env bash

function display_help() {
  echo -e "\n  Usage: ${0##*/} [required] [optional]\n"
  echo -e "    Required:"
  echo -e "      --registry <string>        Target registry hostname            example: docker.io"
  echo -e "      --values <path>            Helm Chart values file              example: ./values.yaml\n"
  echo -e "    Optional:"
  echo -e "      --attribution              Enable Attribution"
  echo -e "      --chart <path|url>         Path to Helm Chart                  default: oci://registry.tabnine.com/self-hosted/tabnine-cloud"
  echo -e "      --cleanup                  Delete downloaded images"
  echo -e "      --dry-run                  Print docker commands"
  echo -e "      --help                     Display help"
  echo -e "      --keda                     Enable KEDA"
  echo -e "      --version <string>         Helm chart version                  default: latest"
  echo -e "      --vllm                     Enable vLLM"
  echo -e "      --vllm-online <bool>       vLLM Internet access enabled        default: false\n"
  exit 0
}

function error_handler() {
  echo -e "\n  ${1}\n"
  exit 1
}

if ! command -v docker &> /dev/null; then
  error_handler "Please install docker - https://docs.docker.com/engine/install/"
elif ! command -v helm &> /dev/null; then
  error_handler "Please install helm - https://helm.sh/docs/intro/install/"
elif ! command -v yq &> /dev/null; then
  error_handler "Please install yq >= 1.7 - https://github.com/mikefarah/yq"
elif [ $# -lt 4 ]; then
  display_help
fi

while [ $# -gt 0 ]; do
  case $1 in
    --attribution )
      attribution=true
      shift
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
      display_help
      ;;
    --keda )
      keda=true
      shift
      ;;
    --registry )
      registry=$2
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
    --vllm )
      vllm=true
      shift
      ;;
    --vllm-online )
      vllm_online=$2
      shift; shift
      ;;
    * )
      error_handler "Invalid Parameter  $1"
      ;;
  esac
done

if [ ! -f "${values}" ]; then
  error_handler "Please specify a Helm Chart values file:  --values <path>"
elif [ -z "${registry}" ]; then
  error_handler "Please specify a registry:  --registry <string>"
fi

set -e

attribution_chart=${attribution_chart:-"oci://registry.tabnine.com/self-hosted/tabnine-attribution-db"}
keda_chart="oci://registry.tabnine.com/self-hosted/keda"
registry=$(echo ${registry} | sed 's/\//\\\//g')
tabnine_chart=${tabnine_chart:-"oci://registry.tabnine.com/self-hosted/tabnine-cloud"}
vllm_chart="oci://registry.tabnine.com/self-hosted/vllm"
vllm_online=${vllm_online:-false}

base_repo=$(cat ${values} | yq '.global.image.baseRepo' | sed 's/\//\\\//g')
private_repo=$(cat ${values} | yq '.global.image.privateRepo' | sed 's/\//\\\//g')

# tabnine-cloud helm chart
helm template tabnine ${tabnine_chart} \
  --namespace tabnine \
  --set clickhouse.image.registry=registry.tabnine.com/public \
  --set clickhouse.image.repository=bitnami/clickhouse \
  --set dbt.busyboxImage.repository=registry.tabnine.com/public/busybox \
  --set global.image.baseRepo=public \
  --set global.image.privateRepo=private \
  --set global.image.registry=registry.tabnine.com \
  --set global.monitoring.enabled=true \
  --set indexer.contextEngine.sidecar.image.repository=registry.tabnine.com/private/sidecar-proxy \
  --set inference.gateway.redisInit.image.registry=registry.tabnine.com \
  --set inference.gateway.redisInit.image.repository=bitnamisecure/redis \
  --set inference.gateway.redisInit.image.tag=8.6.2 \
  --set inference.nats.container.image.registry=registry.tabnine.com/public \
  --set inference.nats.natsBox.container.image.registry=registry.tabnine.com/public \
  --set inference.nats.promExporter.image.registry=registry.tabnine.com/public \
  --set inference.nats.reloader.image.registry=registry.tabnine.com/public \
  --set logs-aggregation.extraContainers[0].image=registry.tabnine.com/public/blacklabelops/logrotate:1.3 \
  --set nonEvictionRedis.image.registry=registry.tabnine.com \
  --set nonEvictionRedis.image.repository=public/bitnamisecure/redis \
  --set nonEvictionRedis.metrics.enabled=true \
  --set nonEvictionRedis.metrics.image.registry=registry.tabnine.com \
  --set nonEvictionRedis.metrics.image.repository=public/bitnamisecure/redis-exporter \
  --set nonEvictionRedis.metrics.image.tag=1.86.0 \
  --set postgresql.image.registry=registry.tabnine.com \
  --set postgresql.image.repository=public/bitnamisecure/postgresql \
  --set postgresql.metrics.enabled=true \
  --set postgresql.metrics.image.registry=registry.tabnine.com \
  --set postgresql.metrics.image.repository=public/bitnamisecure/postgres-exporter \
  --set postgresql.metrics.image.tag=0.16.0 \
  --set postgresql.upgrade.busyboxImage.repository=registry.tabnine.com/public/busybox \
  --set postgresql.upgrade.image.repository=registry.tabnine.com/public/pgautoupgrade \
  --set prometheus-blackbox-exporter.global.imageRegistry=registry.tabnine.com/public \
  --set qdrant2.image.repository=registry.tabnine.com/public/qdrant/qdrant \
  --set redis.image.registry=registry.tabnine.com \
  --set redis.image.repository=public/bitnamisecure/redis \
  --set redis.metrics.enabled=true \
  --set redis.metrics.image.registry=registry.tabnine.com \
  --set redis.metrics.image.repository=public/bitnamisecure/redis-exporter \
  --set redis.metrics.image.tag=1.86.0 \
  --skip-tests \
  --values "${values}" \
  --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u > images.tmp

# keda helm chart
if [ -n "${keda}" ]; then
  helm template keda ${keda_chart} \
    --namespace keda \
    --set image.keda.registry=registry.tabnine.com \
    --set image.keda.repository=public/kedacore/keda \
    --set image.metricsApiServer.registry=registry.tabnine.com \
    --set image.metricsApiServer.repository=public/kedacore/keda-metrics-apiserver \
    --set image.webhooks.registry=registry.tabnine.com \
    --set image.webhooks.repository=public/kedacore/keda-admission-webhooks \
    --skip-tests | yq --no-doc 'select(.kind == "Deployment") | .. | .image? | select(.)' | sort -u >> images.tmp
fi

# tabnine-attribution-db helm chart
if [ -n "${attribution}" ]; then
  helm template attribution ${attribution_chart} \
    --namespace tabnine \
    --set global.image.baseRepo=public \
    --set global.image.privateRepo=private \
    --set global.image.registry=registry.tabnine.com \
    --skip-tests \
    --version "${version}" | yq --no-doc '.. | .image? | select(.)' | sort -u >> images.tmp
fi
  
# vllm helm chart
if [ -n "${vllm}" ]; then
  helm template vllm ${vllm_chart} \
    --namespace vlm \
    --set online=${vllm_online} \
    --skip-tests | yq --no-doc '.. | .image? | select(.)' | sort -u >> images.tmp
fi

sort -o images.tmp images.tmp
images_list=$(cat images.tmp)
rm -rf images.tmp

for image in ${images_list[@]}; do
  target=$(echo ${image} | \
    sed -e "s/registry.tabnine.com\/private/${registry}\/${private_repo}/g" | \
    sed -e "s/registry.tabnine.com\/public/${registry}\/${base_repo}/g" | \
    sed -e "s/quay.io/${registry}\/${base_repo}/g")
  
  if [ -z "${dry_run}" ]; then
    docker pull ${image} --platform=linux/amd64
    docker tag ${image} ${target}
    docker push ${target}
    docker rmi ${target}
    
    if [ -n "${cleanup}" ]; then
      docker rmi ${image}
    fi
  else
    echo "docker pull ${image} --platform=linux/amd64"
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
