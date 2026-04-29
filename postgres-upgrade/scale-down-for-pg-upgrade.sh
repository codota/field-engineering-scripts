#!/usr/bin/env bash
set -euo pipefail

: "${HELM_RELEASE:?HELM_RELEASE env variable is required}"
: "${NAMESPACE:?NAMESPACE env variable is required}"

echo "==> Suspending cronjobs in namespace: $NAMESPACE"
kubectl patch cronjob $HELM_RELEASE-tabnine-cloud-indexer-cronjob -n "$NAMESPACE" -p '{"spec":{"suspend":true}}'
kubectl patch cronjob $HELM_RELEASE-tabnine-cloud-quota-cronjob   -n "$NAMESPACE" -p '{"spec":{"suspend":true}}'

echo "==> Scaling down all deployments to 0..."
set +e
set -u
set -o pipefail
kubectl scale deployment -n "$NAMESPACE" --replicas=0 \
  $HELM_RELEASE-tabnine-cloud-analytics \
  $HELM_RELEASE-tabnine-cloud-analytics-consumer \
  $HELM_RELEASE-tabnine-cloud-app \
  $HELM_RELEASE-tabnine-cloud-auth \
  $HELM_RELEASE-tabnine-cloud-chat-frontend \
  $HELM_RELEASE-tabnine-cloud-coaching-reviewservice \
  $HELM_RELEASE-tabnine-cloud-coaching-server \
  $HELM_RELEASE-tabnine-cloud-coaching-worker \
  $HELM_RELEASE-tabnine-cloud-completions \
  $HELM_RELEASE-tabnine-cloud-diagnostics-service \
  $HELM_RELEASE-tabnine-cloud-embedding \
  $HELM_RELEASE-tabnine-cloud-indexer \
  $HELM_RELEASE-tabnine-cloud-portkey-gateway \
  $HELM_RELEASE-tabnine-cloud-quota \
  $HELM_RELEASE-tabnine-cloud-update \
  $HELM_RELEASE-tabnine-cloud-verification
set -euo pipefail

if [[ -z "${KEEP_POSTGRES_RUNNING:-}" ]]; then
  echo "==> Scaling down PostgreSQL StatefulSet to 0..."
  kubectl scale statefulset $HELM_RELEASE-postgresql -n "$NAMESPACE" --replicas=0
fi

echo "==> Waiting for all pods to terminate..."
kubectl wait pod \
  --for=delete \
  --selector=app.kubernetes.io/instance=$HELM_RELEASE \
  --namespace="$NAMESPACE" \
  --timeout=120s 2>/dev/null || true

echo ""
if [[ -z "${KEEP_POSTGRES_RUNNING:-}" ]]; then
  echo "All services and PostgreSQL are down."
  echo "You can now run: helm upgrade tabnine ... --set postgresql.upgrade.enabled=true"
else
  echo "All services are down. PostgreSQL is still running."
  echo "You can now run: ./scripts/backup-postgres.sh"
fi
