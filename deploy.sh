#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
RELEASE_NAME="${RELEASE_NAME:-uptime-kuma}"

echo "=== Deploying Uptime Kuma to Kubernetes ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

step() {
    echo -e "${GREEN}==>${NC} $1"
}

info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Check prerequisites
step "Checking prerequisites"

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Please install helm."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Check your KUBECONFIG."
    exit 1
fi

echo "✅ Prerequisites met"
echo ""

# Add Helm repo
step "Adding bjw-s Helm repository"
helm repo add bjw-s https://bjw-s-labs.github.io/helm-charts/ 2>/dev/null || true
helm repo update bjw-s
echo ""

# Create namespace
step "Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo ""

# Deploy Uptime Kuma
step "Deploying Uptime Kuma"
helm upgrade --install "$RELEASE_NAME" bjw-s/app-template \
    --namespace "$NAMESPACE" \
    --values values.yaml \
    --wait \
    --timeout 5m
echo ""

# Wait for pod to be ready
step "Waiting for pod to be ready"
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=uptime-kuma \
    -n "$NAMESPACE" \
    --timeout=300s
echo ""

# Get ingress info
step "Deployment complete!"
echo ""
echo "Uptime Kuma is now running."
echo ""
echo "Access the web UI:"
INGRESS_HOST=$(kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/name=uptime-kuma -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "uptime.media.lan")
echo "  http://$INGRESS_HOST"
echo ""
echo "Check status:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=uptime-kuma"
echo ""
echo "First-time setup:"
echo "  1. Open the web UI"
echo "  2. Create admin account (this creates on first visit)"
echo "  3. Configure notifications: Settings → Notifications"
echo "  4. Import monitors: Settings → Backup → Import (use examples/monitors.json)"
