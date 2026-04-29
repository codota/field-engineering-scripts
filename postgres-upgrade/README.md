# PostgreSQL Upgrade Scripts

This directory contains scripts for upgrading PostgreSQL in a tabnine-cloud deployment.

## PostgreSQL 15 → 18 In-Place Upgrade

The recommended upgrade path uses `pg_upgrade` via a Helm-managed Job (`postgresql.upgrade.enabled=true`).
It upgrades the data directory in-place — **no data export/import is needed**, but a backup is strongly recommended first.

### Pre-requisites

- `kubectl` configured with access to the cluster
- `helm` v3+
- Sufficient disk space (pg_upgrade with `--link` requires minimal extra space, but allow at least 20% headroom)
- A backup of the PostgreSQL data (see [Backup](#backup) below)

---

### Upgrade Steps

#### 1. Scale down services (keep PostgreSQL running)

Stop all application services while keeping PostgreSQL up for the backup:

```bash
HELM_RELEASE=tabnine NAMESPACE=tabnine KEEP_POSTGRES_RUNNING=true ./scripts/scale-down-for-pg-upgrade.sh
```

This script:
- Suspends the indexer and quota CronJobs
- Scales all application Deployments to 0 replicas
- Waits for all pods to terminate

#### 2. Back up your data

Dump all databases while PostgreSQL is still running:

```bash
HELM_RELEASE=tabnine NAMESPACE=tabnine ./scripts/backup-postgres.sh
# or with explicit output path:
HELM_RELEASE=tabnine NAMESPACE=tabnine BACKUP_FILE=/backups/pg15-production.sql ./scripts/backup-postgres.sh
```

> **CRITICAL**: Do not proceed until you have verified the backup file is complete and readable.

#### 3. Scale down PostgreSQL

Now shut down PostgreSQL so the upgrade Job can get exclusive access to the PVC:

```bash
HELM_RELEASE=tabnine NAMESPACE=tabnine ./scripts/scale-down-for-pg-upgrade.sh
```

This scales down the PostgreSQL StatefulSet and waits for the pod to terminate.

#### 4. Run the upgrade

```bash
helm upgrade -n <namespace> <release_name> \
  oci://registry.tabnine.com/self-hosted/tabnine-cloud \
  --version 6.1.x \
  --values your-values.yaml \
  --set postgresql.upgrade.enabled=true \
  --wait --timeout=3600s
```

The `postgresql-upgrade-job` is a `pre-upgrade` Helm hook, so it runs **before** the rest of the chart is applied:
1. pg_upgrade upgrades the data directory from PostgreSQL 15 to 18 in-place
2. Helm then reconciles all deployments and the StatefulSet — PostgreSQL and all services come back up automatically

Monitor the upgrade Job while it runs:

```bash
kubectl logs -n tabnine -f job/tabnine-postgresql-upgrade
```

Verify PostgreSQL 18 is running once helm completes:

```bash
kubectl exec -n tabnine tabnine-postgresql-0 -- psql -U postgres -c "SELECT version();"
```

---

### Rollback

If the upgrade fails, restore from the backup:

```bash
HELM_RELEASE=tabnine \
NAMESPACE=tabnine \
BACKUP_FILE=pg15-backup-20260320-120000.sql \
VALUES_FILE=your-values.yaml \
./scripts/rollback-postgres.sh
```

---

### Troubleshooting

**Services can't connect after upgrade** — check authentication method:
```bash
kubectl exec -n tabnine tabnine-postgresql-0 -- cat /opt/bitnami/postgresql/conf/pg_hba.conf
```
Should show `scram-sha-256`.

**MD5 function errors** — check FIPS mode:
```bash
kubectl exec -n tabnine tabnine-postgresql-0 -- env | grep OPENSSL_FIPS
```
Should show `OPENSSL_FIPS=no`.

**Upgrade Job keeps failing** — inspect the Job logs and events:
```bash
kubectl describe job -n tabnine tabnine-postgresql-upgrade
kubectl logs -n tabnine job/tabnine-postgresql-upgrade
```
