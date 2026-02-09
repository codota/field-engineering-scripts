#!/usr/bin/env bash
#
# Infrastructure Validation Script
# Tests: Kubernetes, NGINX Ingress, Local Path Provisioner, GPU Operator
#
# Usage: ./infra_validate.sh [OPTIONS]
#   -n, --namespace NS    Namespace for test resources (default: default)
#   -g, --skip-gpu        Skip GPU Operator tests
#   --help                Display help
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Defaults
test_namespace="default"
skip_gpu=false
pass_count=0
fail_count=0
warn_count=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace) test_namespace="$2"; shift 2 ;;
        -g|--skip-gpu) skip_gpu=true; shift ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "  -n, --namespace NS    Namespace for test resources (default: default)"
            echo "  -g, --skip-gpu        Skip GPU Operator tests"
            echo "  --help                Display help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Detect kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL="kubectl"
elif command -v microk8s &> /dev/null; then
    KUBECTL="sudo microk8s kubectl"
else
    echo -e "${RED}ERROR: kubectl not found${NC}"
    exit 1
fi

# Helper functions
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════${NC}"
}

print_test() {
    echo -ne "  ├─ $1 ... "
}

pass() {
    echo -e "${GREEN}✅ PASS${NC} ${1:+— $1}"
    ((pass_count++))
}

fail() {
    echo -e "${RED}❌ FAIL${NC} ${1:+— $1}"
    ((fail_count++))
}

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC} ${1:+— $1}"
    ((warn_count++))
}

cleanup_test_resources() {
    echo ""
    echo -e "  ${CYAN}Cleaning up test resources...${NC}"
    ${KUBECTL} delete pod test-nginx-probe --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1
    ${KUBECTL} delete pvc test-localpv-claim --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1
    ${KUBECTL} delete pod test-gpu-probe --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1
    echo -e "  ${GREEN}Cleanup complete.${NC}"
}

trap cleanup_test_resources EXIT

# ═══════════════════════════════════════
# 1. KUBERNETES CLUSTER
# ═══════════════════════════════════════
print_header "1. Kubernetes Cluster"

# 1a. Nodes Ready
print_test "All nodes in Ready state"
not_ready=$(${KUBECTL} get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)
total_nodes=$(${KUBECTL} get nodes --no-headers 2>/dev/null | wc -l)
if [[ "$not_ready" -eq 0 && "$total_nodes" -gt 0 ]]; then
    pass "${total_nodes} node(s) ready"
else
    fail "${not_ready} node(s) not ready out of ${total_nodes}"
fi

# 1b. System pods healthy
print_test "System pods healthy (kube-system)"
failing_pods=$(${KUBECTL} get pods -n kube-system --no-headers 2>/dev/null | grep -vE "Running|Completed" | wc -l)
if [[ "$failing_pods" -eq 0 ]]; then
    pass
else
    fail "${failing_pods} pod(s) not running"
    ${KUBECTL} get pods -n kube-system --no-headers | grep -vE "Running|Completed" | sed 's/^/    /'
fi

# 1c. API server responsive
print_test "API server responsive"
if ${KUBECTL} cluster-info > /dev/null 2>&1; then
    pass
else
    fail "API server not reachable"
fi

# 1d. Can schedule a pod
print_test "Pod scheduling works"
${KUBECTL} run test-nginx-probe \
    --image=nginx:alpine \
    --restart=Never \
    --namespace=${test_namespace} \
    --overrides='{"spec":{"terminationGracePeriodSeconds":0}}' \
    > /dev/null 2>&1

if ${KUBECTL} wait --for=condition=ready pod/test-nginx-probe \
    --namespace=${test_namespace} --timeout=60s > /dev/null 2>&1; then
    pass
else
    fail "Test pod did not reach Ready state within 60s"
fi
${KUBECTL} delete pod test-nginx-probe --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1

# 1e. DNS resolution
print_test "CoreDNS resolution"
dns_result=$(${KUBECTL} run test-dns-probe --image=busybox:1.36 --restart=Never \
    --namespace=${test_namespace} \
    --overrides='{"spec":{"terminationGracePeriodSeconds":0}}' \
    --command -- nslookup kubernetes.default.svc.cluster.local 2>&1) || true
${KUBECTL} wait --for=condition=ready pod/test-dns-probe --namespace=${test_namespace} --timeout=30s > /dev/null 2>&1 || true
sleep 3
dns_log=$(${KUBECTL} logs test-dns-probe --namespace=${test_namespace} 2>/dev/null || echo "")
${KUBECTL} delete pod test-dns-probe --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1
if echo "$dns_log" | grep -q "Address"; then
    pass
else
    warn "DNS check inconclusive"
fi

# ═══════════════════════════════════════
# 2. NGINX INGRESS CONTROLLER
# ═══════════════════════════════════════
print_header "2. NGINX Ingress Controller"

# Detect ingress namespace
ingress_ns=""
for ns in ingress-nginx ingress nginx-ingress; do
    if ${KUBECTL} get namespace ${ns} > /dev/null 2>&1; then
        ingress_ns="${ns}"
        break
    fi
done

if [[ -z "$ingress_ns" ]]; then
    fail "Ingress namespace not found (checked: ingress-nginx, ingress, nginx-ingress)"
else
    echo -e "  ${CYAN}Detected ingress namespace: ${ingress_ns}${NC}"

    # 2a. Controller pod running
    print_test "Ingress controller pod(s) running"
    running=$(${KUBECTL} get pods -n ${ingress_ns} --no-headers 2>/dev/null | grep -i "ingress" | grep "Running" | wc -l)
    if [[ "$running" -gt 0 ]]; then
        pass "${running} controller pod(s)"
    else
        fail "No running ingress controller pods"
    fi

    # 2b. Service exists with IP/port
    print_test "Ingress service has endpoint"
    svc_info=$(${KUBECTL} get svc -n ${ingress_ns} --no-headers 2>/dev/null | grep -i "ingress" | head -1)
    if [[ -n "$svc_info" ]]; then
        svc_type=$(echo "$svc_info" | awk '{print $2}')
        external_ip=$(echo "$svc_info" | awk '{print $4}')
        if [[ "$svc_type" == "LoadBalancer" && "$external_ip" != "<pending>" && "$external_ip" != "<none>" ]]; then
            pass "LoadBalancer — ${external_ip}"
        elif [[ "$svc_type" == "NodePort" ]]; then
            node_ports=$(echo "$svc_info" | awk '{print $5}')
            pass "NodePort — ${node_ports}"
        elif [[ "$external_ip" == "<pending>" ]]; then
            warn "LoadBalancer IP pending — may need MetalLB or cloud LB"
        else
            pass "${svc_type}"
        fi
    else
        fail "No ingress service found"
    fi

    # 2c. IngressClass exists
    print_test "IngressClass resource exists"
    ic_count=$(${KUBECTL} get ingressclass --no-headers 2>/dev/null | wc -l)
    if [[ "$ic_count" -gt 0 ]]; then
        ic_name=$(${KUBECTL} get ingressclass --no-headers 2>/dev/null | head -1 | awk '{print $1}')
        pass "${ic_name}"
    else
        warn "No IngressClass defined — ingress resources may not route"
    fi

    # 2d. Check existing ingress resources
    print_test "Ingress resources across cluster"
    ingress_count=$(${KUBECTL} get ingress -A --no-headers 2>/dev/null | wc -l)
    if [[ "$ingress_count" -gt 0 ]]; then
        pass "${ingress_count} ingress resource(s) found"
    else
        warn "No ingress resources defined yet"
    fi
fi

# ═══════════════════════════════════════
# 3. LOCAL PATH PROVISIONER
# ═══════════════════════════════════════
print_header "3. Local Path Provisioner"

# Detect provisioner namespace
lp_ns=""
for ns in local-path-storage local-path-provisioner kube-system; do
    if ${KUBECTL} get pods -n ${ns} --no-headers 2>/dev/null | grep -qi "local-path"; then
        lp_ns="${ns}"
        break
    fi
done

if [[ -z "$lp_ns" ]]; then
    fail "Local Path Provisioner not found in any expected namespace"
else
    echo -e "  ${CYAN}Detected provisioner namespace: ${lp_ns}${NC}"

    # 3a. Provisioner pod running
    print_test "Provisioner pod running"
    lp_running=$(${KUBECTL} get pods -n ${lp_ns} --no-headers 2>/dev/null | grep -i "local-path" | grep "Running" | wc -l)
    if [[ "$lp_running" -gt 0 ]]; then
        pass
    else
        fail "Provisioner pod not running"
    fi

    # 3b. StorageClass exists
    print_test "StorageClass exists"
    sc_info=$(${KUBECTL} get sc --no-headers 2>/dev/null | grep -i "local-path")
    if [[ -n "$sc_info" ]]; then
        sc_name=$(echo "$sc_info" | awk '{print $1}')
        is_default=$(echo "$sc_info" | grep -c "(default)" || true)
        if [[ "$is_default" -gt 0 ]]; then
            pass "${sc_name} (default)"
        else
            warn "${sc_name} exists but is NOT marked as default"
        fi
    else
        fail "No local-path StorageClass found"
    fi

    # 3c. PVC bind test
    print_test "PVC binds successfully"
    cat <<EOF | ${KUBECTL} apply -f - > /dev/null 2>&1
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-localpv-claim
  namespace: ${test_namespace}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 128Mi
EOF

    # Local-path-provisioner only binds when a pod mounts the PVC
    cat <<EOF | ${KUBECTL} apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: test-localpv-consumer
  namespace: ${test_namespace}
spec:
  terminationGracePeriodSeconds: 0
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "30"]
    volumeMounts:
    - mountPath: /data
      name: test-vol
  volumes:
  - name: test-vol
    persistentVolumeClaim:
      claimName: test-localpv-claim
EOF

    # Wait for pod to trigger binding
    ${KUBECTL} wait --for=condition=ready pod/test-localpv-consumer \
        --namespace=${test_namespace} --timeout=90s > /dev/null 2>&1 || true

    pvc_status=$(${KUBECTL} get pvc test-localpv-claim --namespace=${test_namespace} -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$pvc_status" == "Bound" ]]; then
        pass
    else
        fail "PVC status: ${pvc_status} (expected Bound)"
    fi
    ${KUBECTL} delete pod test-localpv-consumer --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1
    ${KUBECTL} delete pvc test-localpv-claim --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1
fi

# ═══════════════════════════════════════
# 4. GPU OPERATOR
# ═══════════════════════════════════════
if [[ "$skip_gpu" == true ]]; then
    print_header "4. GPU Operator (SKIPPED)"
    echo -e "  ${YELLOW}Skipped via --skip-gpu flag${NC}"
else
    print_header "4. GPU Operator"

    # Detect GPU operator namespace
    gpu_ns=""
    for ns in gpu-operator nvidia-gpu-operator; do
        if ${KUBECTL} get namespace ${ns} > /dev/null 2>&1; then
            gpu_ns="${ns}"
            break
        fi
    done

    if [[ -z "$gpu_ns" ]]; then
        fail "GPU Operator namespace not found (checked: gpu-operator, nvidia-gpu-operator)"
    else
        echo -e "  ${CYAN}Detected GPU operator namespace: ${gpu_ns}${NC}"

        # 4a. Operator pods running
        print_test "GPU Operator pods running"
        gpu_pods_total=$(${KUBECTL} get pods -n ${gpu_ns} --no-headers 2>/dev/null | wc -l)
        gpu_pods_healthy=$(${KUBECTL} get pods -n ${gpu_ns} --no-headers 2>/dev/null | grep -cE "Running|Completed" || true)
        gpu_pods_failing=$((gpu_pods_total - gpu_pods_healthy))
        if [[ "$gpu_pods_total" -gt 0 && "$gpu_pods_failing" -eq 0 ]]; then
            pass "${gpu_pods_healthy} pod(s) healthy"
        elif [[ "$gpu_pods_total" -gt 0 ]]; then
            warn "${gpu_pods_failing} of ${gpu_pods_total} pod(s) not healthy"
            ${KUBECTL} get pods -n ${gpu_ns} --no-headers | grep -vE "Running|Completed" | sed 's/^/    /'
        else
            fail "No pods found in ${gpu_ns}"
        fi

        # 4b. GPU resources visible on nodes
        print_test "nvidia.com/gpu allocatable on nodes"
        gpu_nodes=$(${KUBECTL} get nodes -o json 2>/dev/null | \
            python3 -c "
import sys, json
data = json.load(sys.stdin)
count = 0
for node in data.get('items', []):
    gpus = node.get('status', {}).get('allocatable', {}).get('nvidia.com/gpu', '0')
    if int(gpus) > 0:
        name = node.get('metadata', {}).get('name', 'unknown')
        print(f'    {name}: {gpus} GPU(s)')
        count += int(gpus)
print(f'TOTAL:{count}')
" 2>/dev/null) || gpu_nodes="TOTAL:0"

        total_gpus=$(echo "$gpu_nodes" | grep "^TOTAL:" | cut -d: -f2)
        if [[ "$total_gpus" -gt 0 ]]; then
            pass "${total_gpus} GPU(s) across cluster"
            echo "$gpu_nodes" | grep -v "^TOTAL:" | head -5
        else
            fail "No GPUs detected as allocatable"
        fi

        # 4c. nvidia-smi test pod
        print_test "nvidia-smi runs successfully in test pod"
        cat <<EOF | ${KUBECTL} apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: test-gpu-probe
  namespace: ${test_namespace}
spec:
  restartPolicy: Never
  terminationGracePeriodSeconds: 0
  containers:
  - name: gpu-test
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

        if ${KUBECTL} wait --for=condition=ready pod/test-gpu-probe \
            --namespace=${test_namespace} --timeout=120s > /dev/null 2>&1 || \
           ${KUBECTL} wait --for=jsonpath='{.status.phase}'=Succeeded pod/test-gpu-probe \
            --namespace=${test_namespace} --timeout=120s > /dev/null 2>&1; then

            gpu_log=$(${KUBECTL} logs test-gpu-probe --namespace=${test_namespace} 2>/dev/null || echo "")
            if echo "$gpu_log" | grep -q "NVIDIA-SMI"; then
                gpu_model=$(echo "$gpu_log" | grep -oP '(?<=\| )[\w\s]+(?=\s+\|)' | head -1 | xargs)
                pass "${gpu_model:-GPU detected}"
            else
                fail "nvidia-smi did not produce expected output"
            fi
        else
            pod_status=$(${KUBECTL} get pod test-gpu-probe --namespace=${test_namespace} -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            fail "Test pod status: ${pod_status}"
        fi
        ${KUBECTL} delete pod test-gpu-probe --namespace=${test_namespace} --ignore-not-found=true > /dev/null 2>&1
    fi
fi

# ═══════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════
print_header "Summary"
echo ""
echo -e "  ${GREEN}Passed:  ${pass_count}${NC}"
echo -e "  ${RED}Failed:  ${fail_count}${NC}"
echo -e "  ${YELLOW}Warnings: ${warn_count}${NC}"
echo ""

if [[ "$fail_count" -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✅ All critical checks passed.${NC}"
else
    echo -e "  ${RED}${BOLD}❌ ${fail_count} check(s) failed — review output above.${NC}"
fi
echo ""

exit ${fail_count}
