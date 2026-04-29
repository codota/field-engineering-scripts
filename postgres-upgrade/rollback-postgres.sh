#!/usr/bin/env bash
set -euo pipefail

: "${NAMESPACE:?NAMESPACE env variable is required}"
: "${BACKUP_FILE:?BACKUP_FILE env variable is required}"
: "${VALUES_FILE:?VALUES_FILE env variable is required}"

HELM_RELEASE="${HELM_RELEASE:-tabnine}"
CHART_PATH="${CHART_PATH:-./charts/tabnine-cloud}"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "ERROR: backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "==> Rolling back PostgreSQL in namespace: $NAMESPACE"
echo "==> Backup file: $BACKUP_FILE"
echo "==> Values file: $VALUES_FILE"

echo "==> Scaling down all deployments..."
kubectl scale deployment -n "$NAMESPACE" --all --replicas=0
kubectl scale statefulset tabnine-postgresql -n "$NAMESPACE" --replicas=0

echo "==> Waiting for pods to terminate..."
kubectl wait pod \
  --for=delete \
  --selector=app.kubernetes.io/instance="$HELM_RELEASE" \
  --namespace="$NAMESPACE" \
  --timeout=120s 2>/dev/null || true

echo "==> Deleting PostgreSQL PVC..."
kubectl delete pvc "data-${HELM_RELEASE}-postgresql-0" -n "$NAMESPACE"

echo "==> Deploying PostgreSQL 15 via helm..."
helm upgrade "$HELM_RELEASE" "$CHART_PATH" \
  -n "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait --timeout 10m

echo "==> Waiting for PostgreSQL pod to be ready..."
kubectl wait pod tabnine-postgresql-0 \
  --for=condition=Ready \
  --namespace="$NAMESPACE" \
  --timeout=120s

echo "==> Copying backup file to PostgreSQL pod..."
kubectl cp "$BACKUP_FILE" "$NAMESPACE/tabnine-postgresql-0:/tmp/restore.sql"

echo "==> Restoring data..."
PGPASSWORD=$(kubectl get secret -n "$NAMESPACE" tabnine-database -o jsonpath='{.data.postgres-password}' | base64 -d)
kubectl exec -n "$NAMESPACE" tabnine-postgresql-0 \
  -- bash -c "PGPASSWORD='$PGPASSWORD' psql -U postgres -f /tmp/restore.sql"

echo ""
echo "==> Rollback complete. Verify data before scaling services back up:"
echo "    kubectl exec -n $NAMESPACE tabnine-postgresql-0 -- psql -U postgres -l"
