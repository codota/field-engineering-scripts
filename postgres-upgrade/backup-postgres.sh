#!/usr/bin/env bash
set -euo pipefail

: "${HELM_RELEASE}:?HELM_RELEASE env variable is required}"
: "${NAMESPACE:?NAMESPACE env variable is required}"

BACKUP_FILE="${BACKUP_FILE:-pg15-backup-$(date +%Y%m%d-%H%M%S).sql}"

echo "==> Creating backup pod in namespace: $NAMESPACE"
echo "==> Output file: $BACKUP_FILE"

IMAGE=$(kubectl get sts -n $NAMESPACE $HELM_RELEASE-postgresql -o jsonpath='{range .spec.template.spec.containers[*]}{.image}{"\n"}{end}' | grep postgresql)

kubectl run pg-backup --restart=Never \
  -n "$NAMESPACE" \
  --image="$IMAGE" \
  --overrides="{
    \"spec\": {
      \"containers\": [{
        \"name\": \"pg-backup\",
        \"image\": \"$IMAGE\",
        \"command\": [\"sh\", \"-c\", \"pg_dumpall -h tabnine-postgresql -U postgres -f /tmp/dump.sql && echo done && sleep 3600\"],
        \"env\": [{
          \"name\": \"PGPASSWORD\",
          \"valueFrom\": {\"secretKeyRef\": {\"name\": \"tabnine-database\", \"key\": \"postgres-password\"}}
        }]
      }]
    }
  }"

echo "==> Waiting for pod to be ready..."
kubectl wait pod pg-backup -n "$NAMESPACE" --for=condition=Ready --timeout=60s

echo "==> Waiting for dump to finish..."
until kubectl logs -n "$NAMESPACE" pg-backup 2>/dev/null | grep -q "^done$"; do
  sleep 2
done

echo "==> Copying backup from pod..."
kubectl cp "$NAMESPACE/pg-backup:/tmp/dump.sql" "$BACKUP_FILE"
kubectl delete pod pg-backup -n "$NAMESPACE" --ignore-not-found

echo "==> Backup saved to: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

DB_COUNT=$(grep -c "CREATE DATABASE" "$BACKUP_FILE" || true)
if [[ "$DB_COUNT" -gt 0 ]]; then
  echo "==> Backup contains $DB_COUNT database(s) — OK"
else
  echo "ERROR: Backup file contains no CREATE DATABASE statements — backup may be invalid!"
  exit 1
fi
