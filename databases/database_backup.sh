#!/usr/bin/env bash

# Parse command line arguments
# Usage: ./database_backup.sh [namespace] [release_name]
# Default namespace: tabnine
# Default release name: tabnine
namespace="${1:-tabnine}"
release="${2:-tabnine}"

# If no arguments were provided, show defaults and ask for confirmation
if [ $# -eq 0 ]; then
    echo "============================================"
    echo "  No arguments provided — using defaults"
    echo "============================================"
    echo ""
    echo "  Namespace:    ${namespace}"
    echo "  Helm Release: ${release}"
    echo ""
    echo "  Usage: $0 <namespace> <release_name>"
    echo "  Example: $0 tabnine tabnine"
    echo "           $0 my-namespace my-release"
    echo ""
    echo "============================================"
    read -rp "Proceed with defaults? (y/N): " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

echo "Using namespace: ${namespace}"
echo "Using Helm release: ${release}"
echo ""

# Check if kubectl exists, otherwise use sudo microk8s kubectl
if command -v kubectl &> /dev/null; then
    kubectl_cmd="kubectl"
else
    kubectl_cmd="sudo microk8s kubectl"
fi

# Derive resource names from release name
postgres_pod="${release}-postgresql-0"
redis_pod="${release}-redis-master-0"
redis_no_evict_pod="${release}-no-evict-redis-master-0"

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# PostgreSQL Backup
echo "Starting PostgreSQL backup..."

# Scale down deployments if they exist
deployments=(
    "${release}-tabnine-cloud-auth"
    "${release}-tabnine-cloud-analytics"
    "${release}-tabnine-cloud-analytics-consumer"
    "${release}-tabnine-cloud-indexer"
)
scaled_deployments=()

for deployment in "${deployments[@]}"; do
    # Check if deployment exists
    if ${kubectl_cmd} get deployment -n ${namespace} ${deployment} &> /dev/null; then
        echo "Scaling down ${deployment}..."
        ${kubectl_cmd} scale deployment -n ${namespace} ${deployment} --replicas=0 > /dev/null 2>&1 || handle_error "Failed to scale down ${deployment}"
        scaled_deployments+=("${deployment}")
    fi
done

# Wait for active connections to close
echo "Checking for active database connections..."

# Get database password once to avoid repeated calls
db_password=$(${kubectl_cmd} get secrets -n ${namespace} ${release}-database -o yaml | yq -r '.data.password' | base64 -d)

# Simple check for active connections - no interactive terminal needed
active_connections=$(${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -t -c \"SELECT count(*) FROM pg_stat_activity WHERE datname = 'tabnine' AND pid <> pg_backend_pid() AND state = 'active';\"" | tr -d ' ')

echo "Found ${active_connections:-0} active connections"

# If there are active connections, terminate them
if [ -n "$active_connections" ] && [ "$active_connections" -gt 0 ]; then
    echo "Terminating ${active_connections} active connections..."
    ${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'tabnine' AND pid <> pg_backend_pid() AND state = 'active';\""
    echo "Waiting 5 seconds for connections to close..."
    sleep 5
fi

echo "Proceeding with backup..."

# Disable row level security before backup
${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -c \"
ALTER TABLE acess_tokens NO FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_log_entries NO FORCE ROW LEVEL SECURITY;
ALTER TABLE organization_settings NO FORCE ROW LEVEL SECURITY;
ALTER TABLE organization_users NO FORCE ROW LEVEL SECURITY;
ALTER TABLE organizations NO FORCE ROW LEVEL SECURITY;
ALTER TABLE team_feature_settings NO FORCE ROW LEVEL SECURITY;
ALTER TABLE team_users NO FORCE ROW LEVEL SECURITY;
ALTER TABLE teams NO FORCE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log NO FORCE ROW LEVEL SECURITY;
ALTER TABLE users NO FORCE ROW LEVEL SECURITY;
\"" > /dev/null 2>&1 || handle_error "Failed to disable row level security"

# Perform database dump
${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} pg_dump -h localhost -U tabnine -d tabnine -Fc -b -f /tmp/dump.sql" > /dev/null 2>&1 || handle_error "Failed to dump database"
${kubectl_cmd} cp -n ${namespace} ${postgres_pod}:/tmp/dump.sql ./dump.sql > /dev/null 2>&1 || handle_error "Failed to copy dump file"
${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "rm -f /tmp/dump.sql" > /dev/null 2>&1 || handle_error "Failed to remove temporary dump file"

# Re-enable row level security after backup
${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -c \"
ALTER TABLE access_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_feature_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
\"" > /dev/null 2>&1 || handle_error "Failed to re-enable row level security"

echo "PostgreSQL Database Backup Successful"

# Scale up deployments that were scaled down
for deployment in "${scaled_deployments[@]}"; do
    echo "Scaling up ${deployment}..."
    ${kubectl_cmd} scale deployment -n ${namespace} ${deployment} --replicas=1 > /dev/null 2>&1 || handle_error "Failed to scale up ${deployment}"
done

# Redis Master Backup
echo "Starting Redis backup..."
# Get Redis password
redis_password=$(${kubectl_cmd} get secrets -n ${namespace} ${release}-redis -o yaml | yq -r '.data.redis-password' | base64 -d)
${kubectl_cmd} exec -n ${namespace} ${redis_pod} -- /bin/sh -c "REDISCLI_AUTH=${redis_password} redis-cli -h localhost SAVE" > /dev/null 2>&1 || handle_error "Failed to save Redis database"
${kubectl_cmd} cp -n ${namespace} ${redis_pod}:/data/dump.rdb ./redis.rdb > /dev/null 2>&1 || handle_error "Failed to copy Redis dump file"
${kubectl_cmd} exec -n ${namespace} ${redis_pod} -- /bin/sh -c "rm -rf /data/dump.rdb" > /dev/null 2>&1 || handle_error "Failed to remove temporary Redis dump file"

# Non-Evicting Redis Master Backup
echo "Starting Non-Evicting Redis backup..."
# Get Redis password
redis_no_evict_password=$(${kubectl_cmd} get secrets -n ${namespace} ${release}-non-eviction-redis -o yaml | yq -r '.data.redis-password' | base64 -d)
${kubectl_cmd} exec -n ${namespace} ${redis_no_evict_pod} -- /bin/sh -c "REDISCLI_AUTH=${redis_no_evict_password} redis-cli -h localhost SAVE" > /dev/null 2>&1 || handle_error "Failed to save Redis database"
${kubectl_cmd} cp -n ${namespace} ${redis_no_evict_pod}:/data/dump.rdb ./redis-no-evict.rdb > /dev/null 2>&1 || handle_error "Failed to copy Redis dump file"
${kubectl_cmd} exec -n ${namespace} ${redis_no_evict_pod} -- /bin/sh -c "rm -rf /data/dump.rdb" > /dev/null 2>&1 || handle_error "Failed to remove temporary Redis dump file"

echo "Redis Database Backup Successful"
echo "All backups completed successfully"
