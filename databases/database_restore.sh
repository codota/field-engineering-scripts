#!/usr/bin/env bash

# Default values
mode="kubernetes"
namespace="tabnine"
release="tabnine"
remote_host=""
remote_port="5432"
remote_db="postgres"
admin_user=""

# Track if namespace/release were explicitly set
namespace_set=false
release_set=false

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Restore PostgreSQL and Redis databases"
    echo ""
    echo "Options:"
    echo "  -m, --mode MODE       Mode: 'kubernetes' or 'remote' (default: kubernetes)"
    echo "  -n, --namespace NS    Kubernetes namespace (default: tabnine)"
    echo "  -r, --release NAME    Helm chart release name (default: tabnine)"
    echo "  -h, --host HOST       Remote PostgreSQL host (for remote mode)"
    echo "  -p, --port PORT       Remote PostgreSQL port (default: 5432)"
    echo "  -d, --database DB     Remote PostgreSQL database name (default: postgres)"
    echo "  -u, --user USER       Admin username for PostgreSQL"
    echo "  --help                Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                          # Kubernetes mode with defaults"
    echo "  $0 -n my-namespace -r my-release            # Kubernetes with custom namespace/release"
    echo "  $0 -m remote -h db.example.com -u admin     # Remote mode"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            mode="$2"
            shift 2
            ;;
        -n|--namespace)
            namespace="$2"
            namespace_set=true
            shift 2
            ;;
        -r|--release)
            release="$2"
            release_set=true
            shift 2
            ;;
        -h|--host)
            remote_host="$2"
            shift 2
            ;;
        -p|--port)
            remote_port="$2"
            shift 2
            ;;
        -d|--database)
            remote_db="$2"
            shift 2
            ;;
        -u|--user)
            admin_user="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate mode
if [[ "$mode" != "kubernetes" && "$mode" != "remote" ]]; then
    echo "Error: Mode must be either 'kubernetes' or 'remote'"
    usage
fi

# If in kubernetes mode and no namespace/release flags were set, show confirmation
if [[ "$mode" == "kubernetes" && "$namespace_set" == false && "$release_set" == false ]]; then
    echo "============================================"
    echo "  No namespace/release provided — using defaults"
    echo "============================================"
    echo ""
    echo "  Mode:         ${mode}"
    echo "  Namespace:    ${namespace}"
    echo "  Helm Release: ${release}"
    echo ""
    echo "  Usage: $0 [OPTIONS]"
    echo "  Example: $0 -n tabnine -r tabnine"
    echo "           $0 -n my-namespace -r my-release"
    echo "           $0 -m remote -h db.example.com -u admin"
    echo ""
    echo "  Run '$0 --help' for all options."
    echo "============================================"
    read -rp "Proceed with defaults? (y/N): " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# Validate remote mode parameters
if [[ "$mode" == "remote" ]]; then
    if [[ -z "$remote_host" ]]; then
        echo "Error: Remote host is required for remote mode"
        usage
    fi
    
    if [[ -z "$admin_user" ]]; then
        echo "Error: Admin username is required"
        read -p "Enter PostgreSQL admin username: " admin_user
    fi
    
    # Prompt for admin password (not stored in command history)
    read -s -p "Enter PostgreSQL admin password: " admin_password
    echo
    
    if [[ -z "$admin_password" ]]; then
        echo "Error: Admin password cannot be empty"
        exit 1
    fi
fi

# Check if kubectl exists, otherwise use sudo microk8s kubectl
if [[ "$mode" == "kubernetes" ]]; then
    if command -v kubectl &> /dev/null; then
        kubectl_cmd="kubectl"
    else
        kubectl_cmd="sudo microk8s kubectl"
    fi
fi

# Derive resource names from release name
postgres_pod="${release}-postgresql-0"
redis_pod="${release}-redis-master-0"
redis_no_evict_pod="${release}-no-evict-redis-master-0"

echo "Using mode:         ${mode}"
echo "Using namespace:    ${namespace}"
echo "Using Helm release: ${release}"
echo ""

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# PostgreSQL Restore
echo "Starting PostgreSQL restore in $mode mode..."

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

if [[ "$mode" == "kubernetes" ]]; then
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
else
    # For remote mode, check for active connections
    echo "Checking for active database connections on remote server..."
    
    active_connections=$(PGPASSWORD="${admin_password}" psql -h "${remote_host}" -p "${remote_port}" -U "${admin_user}" -d "${remote_db}" -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname = '${remote_db}' AND pid <> pg_backend_pid() AND state = 'active';" | tr -d ' ')
    
    echo "Found ${active_connections:-0} active connections"
    
    # If there are active connections, terminate them
    if [ -n "$active_connections" ] && [ "$active_connections" -gt 0 ]; then
        echo "Terminating ${active_connections} active connections..."
        PGPASSWORD="${admin_password}" psql -h "${remote_host}" -p "${remote_port}" -U "${admin_user}" -d "${remote_db}" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${remote_db}' AND pid <> pg_backend_pid() AND state = 'active';"
        echo "Waiting 5 seconds for connections to close..."
        sleep 5
    fi
fi

echo "Proceeding with restore..."

# Check if dump file exists
if [[ ! -f ./dump.sql ]]; then
    handle_error "PostgreSQL dump file (dump.sql) not found in current directory"
fi

# Determine if the dump file is in plain SQL or custom format
file_type=$(file -b ./dump.sql | grep -i "PostgreSQL custom database dump" > /dev/null && echo "custom" || echo "plain")
echo "Detected dump file type: $file_type"

if [[ "$mode" == "kubernetes" ]]; then
    # Drop all tables in the database
    echo "Dropping all tables in the database..."
    ${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -c \"
    DO \\\$\\\$ DECLARE
        r RECORD;
    BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
            EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
        END LOOP;
    END \\\$\\\$;
    \"" > /dev/null 2>&1 || handle_error "Failed to drop tables"

    # Copy dump file to pod
    echo "Copying PostgreSQL dump file to pod..."
    ${kubectl_cmd} cp ./dump.sql ${postgres_pod}:/tmp/dump.sql -n ${namespace} > /dev/null 2>&1 || handle_error "Failed to copy dump file to pod"

    # Restore database
    echo "Restoring PostgreSQL database..."
    if [[ "$file_type" == "custom" ]]; then
        # Use pg_restore for custom format
        ${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} pg_restore -h localhost -U tabnine -d tabnine --clean --if-exists --no-owner --no-privileges --no-security-labels --no-comments /tmp/dump.sql > /dev/null 2>&1" || true
    else
        # Use psql for plain SQL format
        ${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -f /tmp/dump.sql > /dev/null 2>&1" || true
    fi

    # Verify that tables were created
    echo "Verifying database restoration..."
    table_count=$(${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -t -c \"SELECT count(*) FROM pg_tables WHERE schemaname = 'public';\"" | tr -d ' ')

    if [ -z "$table_count" ] || [ "$table_count" -eq 0 ]; then
        handle_error "Database restoration failed - no tables found"
    else
        echo "Database restored successfully with $table_count tables"
    fi
    ${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "rm -f /tmp/dump.sql" > /dev/null 2>&1 || handle_error "Failed to remove temporary dump file"
else
    # Remote mode - restore directly to remote database
    echo "Dropping all tables in the remote database..."
    PGPASSWORD="${admin_password}" psql -h "${remote_host}" -p "${remote_port}" -U "${admin_user}" -d "${remote_db}" -c "
    DO \$\$ DECLARE
        r RECORD;
    BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
            EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
        END LOOP;
    END \$\$;
    " > /dev/null 2>&1 || handle_error "Failed to drop tables in remote database"

    # Restore database to remote server
    echo "Restoring PostgreSQL database to remote server..."
    if [[ "$file_type" == "custom" ]]; then
        # Use pg_restore for custom format
        PGPASSWORD="${admin_password}" pg_restore -h "${remote_host}" -p "${remote_port}" -U "${admin_user}" -d "${remote_db}" --clean --if-exists --no-owner --no-privileges --no-security-labels --no-comments ./dump.sql > /dev/null 2>&1 || true
    else
        # Use psql for plain SQL format
        PGPASSWORD="${admin_password}" psql -h "${remote_host}" -p "${remote_port}" -U "${admin_user}" -d "${remote_db}" -f ./dump.sql > /dev/null 2>&1 || true
    fi

    # Verify that tables were created
    echo "Verifying database restoration..."
    table_count=$(PGPASSWORD="${admin_password}" psql -h "${remote_host}" -p "${remote_port}" -U "${admin_user}" -d "${remote_db}" -t -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';" | tr -d ' ')

    if [ -z "$table_count" ] || [ "$table_count" -eq 0 ]; then
        handle_error "Database restoration failed - no tables found"
    else
        echo "Database restored successfully with $table_count tables"
    fi
fi

# Set row level security and permissions
echo "Setting up row level security and permissions..."
if [[ "$mode" == "kubernetes" ]]; then
    ${kubectl_cmd} exec -n ${namespace} ${postgres_pod} -- /bin/sh -c "PGPASSWORD=${db_password} psql -h localhost -U tabnine -d tabnine -c \"
    ALTER TABLE IF EXISTS access_tokens ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS audit_log_entries ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS organization_settings ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS organization_users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS organizations ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS team_feature_settings ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS team_users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS teams ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS user_activity_log ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS users ENABLE ROW LEVEL SECURITY;
    \"" > /dev/null 2>&1 || handle_error "Failed to re-enable row level security"
else
    PGPASSWORD="${admin_password}" psql -h "${remote_host}" -p "${remote_port}" -U "${admin_user}" -d "${remote_db}" -c "
    ALTER TABLE IF EXISTS access_tokens ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS audit_log_entries ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS organization_settings ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS organization_users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS organizations ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS team_feature_settings ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS team_users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS teams ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS user_activity_log ENABLE ROW LEVEL SECURITY;
    ALTER TABLE IF EXISTS users ENABLE ROW LEVEL SECURITY;
    " > /dev/null 2>&1 || handle_error "Failed to re-enable row level security on remote database"
fi

echo "PostgreSQL Database Restore Successful"

# Only continue with Redis restore in kubernetes mode
if [[ "$mode" == "remote" ]]; then
    echo "Remote PostgreSQL restore completed successfully"
    exit 0
fi

# Scale up deployments that were scaled down
for deployment in "${scaled_deployments[@]}"; do
    echo "Scaling up ${deployment}..."
    ${kubectl_cmd} scale deployment -n ${namespace} ${deployment} --replicas=1 > /dev/null 2>&1 || handle_error "Failed to scale up ${deployment}"
done

# Redis Restore
echo "Starting Redis restore..."

# Check if dump file exists
if [ ! -f ./redis.rdb ]; then
    handle_error "Redis dump file (redis.rdb) not found in current directory"
fi

# Get Redis password
redis_password=$(${kubectl_cmd} get secrets -n ${namespace} ${release}-redis -o yaml | yq -r '.data.redis-password' | base64 -d)

# Stop Redis server to replace dump file
echo "Stopping Redis server..."
${kubectl_cmd} exec -n ${namespace} ${redis_pod} -- /bin/sh -c "REDISCLI_AUTH=${redis_password} redis-cli -h localhost SAVE" > /dev/null 2>&1 || handle_error "Failed to save Redis database before restore"

# Copy dump file to pod
echo "Copying Redis dump file to pod..."
${kubectl_cmd} cp ./redis.rdb ${redis_pod}:/data/dump.rdb -n ${namespace} > /dev/null 2>&1 || handle_error "Failed to copy Redis dump file to pod"

# Restart Redis to load the new dump file
echo "Restarting Redis to load the new dump file..."
${kubectl_cmd} delete pod -n ${namespace} ${redis_pod} > /dev/null 2>&1 || handle_error "Failed to restart Redis pod"

# Wait for Redis pod to be ready
echo "Waiting for Redis pod to be ready..."
${kubectl_cmd} wait --for=condition=ready pod -n ${namespace} ${redis_pod} --timeout=60s > /dev/null 2>&1 || handle_error "Timeout waiting for Redis pod to be ready"

# Non-Evicting Redis Restore
echo "Starting Non-Evicting Redis restore..."

# Check if dump file exists
if [ ! -f ./redis-no-evict.rdb ]; then
    handle_error "Redis dump file (redis-no-evict.rdb) not found in current directory"
fi

# Get Redis password
redis_no_evict_password=$(${kubectl_cmd} get secrets -n ${namespace} ${release}-non-eviction-redis -o yaml | yq -r '.data.redis-password' | base64 -d)

# Stop Redis server to replace dump file
echo "Stopping Non-Evicting Redis server..."
${kubectl_cmd} exec -n ${namespace} ${redis_no_evict_pod} -- /bin/sh -c "REDISCLI_AUTH=${redis_no_evict_password} redis-cli -h localhost SAVE" > /dev/null 2>&1 || handle_error "Failed to save Non-Evicting Redis database before restore"

# Copy dump file to pod
echo "Copying Non-Evicting Redis dump file to pod..."
${kubectl_cmd} cp ./redis-no-evict.rdb ${redis_no_evict_pod}:/data/dump.rdb -n ${namespace} > /dev/null 2>&1 || handle_error "Failed to copy Redis dump file to pod"

# Restart Redis to load the new dump file
echo "Restarting Redis to load the new dump file..."
${kubectl_cmd} delete pod -n ${namespace} ${redis_no_evict_pod} > /dev/null 2>&1 || handle_error "Failed to restart Redis pod"

# Wait for Redis pod to be ready
echo "Waiting for Redis pod to be ready..."
${kubectl_cmd} wait --for=condition=ready pod -n ${namespace} ${redis_no_evict_pod} --timeout=60s > /dev/null 2>&1 || handle_error "Timeout waiting for Redis pod to be ready"

echo "Redis Database Restore Successful"
echo "All restores completed successfully"
