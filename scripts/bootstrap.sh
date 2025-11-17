#!/bin/bash

#############################################################################
# Unified k3d Cluster Bootstrap Script
#
# Creates a k3d cluster and deploys Flux in either admin or read-only mode
#
# Cluster Specs:
#   - Name: k3d-local
#   - Master: 1 node (1GB RAM)
#   - Workers: 3 nodes (2GB RAM each)
#   - LoadBalancer: ports 80:80, 443:443
#
# Usage:
#   ./scripts/bootstrap.sh              # Create cluster only (no Flux)
#   ./scripts/bootstrap.sh --admin      # Create cluster + Flux admin mode (requires GitHub auth)
#   ./scripts/bootstrap.sh --read-only  # Create cluster + Flux read-only mode (for reviewers)
#
# Modes:
#   --admin      Uses flux bootstrap github (requires repo write access)
#   --read-only  Uses flux install + manual GitOps setup (public repo, no auth)
#############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="k3d-local"
CONFIG_FILE="k3d-local-cluster.yaml"
KUBEAPI_HOST="k3d-local.k8s.local"
HOSTS_MARKER="# k3d-local-cluster"
GITHUB_OWNER="akafrmn"
GITHUB_REPO="ti-httpbin"
FLUX_BRANCH="addons"
FLUX_PATH="clusters/docker-desktop"

# Parse command line arguments
FLUX_MODE=""
case "$1" in
    --admin)
        FLUX_MODE="admin"
        ;;
    --read-only)
        FLUX_MODE="readonly"
        ;;
    "")
        FLUX_MODE="none"
        ;;
    *)
        echo "Usage: $0 [--admin|--read-only]"
        echo "  --admin      Deploy Flux in admin mode (requires GitHub auth)"
        echo "  --read-only  Deploy Flux in read-only mode (for reviewers)"
        echo "  (no args)    Create cluster only, skip Flux deployment"
        exit 1
        ;;
esac

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check k3d
    if ! command -v k3d &> /dev/null; then
        print_error "k3d is not installed"
        echo "Install with: brew install k3d"
        exit 1
    fi
    print_success "k3d installed: $(k3d version | head -1)"

    # Check Docker
    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        echo "Please start Docker Desktop"
        exit 1
    fi
    print_success "Docker is running"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        echo "Install with: brew install kubectl"
        exit 1
    fi
    print_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || echo 'installed')"

    # Check flux CLI if needed
    if [ "$FLUX_MODE" != "none" ]; then
        if ! command -v flux &> /dev/null; then
            print_error "flux CLI is not installed"
            echo "Install with: brew install fluxcd/tap/flux"
            exit 1
        fi
        print_success "flux CLI installed: $(flux version --client | grep 'flux:' | awk '{print $2}')"
    fi

    # Check config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Config file not found: $CONFIG_FILE"
        echo "Expected location: $(pwd)/$CONFIG_FILE"
        exit 1
    fi
    print_success "Config file found: $CONFIG_FILE"
}

# Delete existing cluster
delete_existing_cluster() {
    if k3d cluster list | grep -q "$CLUSTER_NAME"; then
        print_header "Deleting Existing Cluster"
        print_warning "Cluster $CLUSTER_NAME already exists, deleting..."

        # Remove old hosts entries before deleting cluster
        remove_hosts_entries

        k3d cluster delete "$CLUSTER_NAME"
        print_success "Cluster deleted"
        sleep 2
    fi
}

# Remove hosts file entries
remove_hosts_entries() {
    print_info "Removing old /etc/hosts entries..."

    # Check if hosts file has k3d-local entries
    if grep -q "$HOSTS_MARKER" /etc/hosts 2>/dev/null; then
        # Create temp file without k3d-local entries
        sudo sed -i.backup "/$HOSTS_MARKER/d" /etc/hosts
        print_success "Old hosts entries removed"
    else
        print_info "No existing hosts entries to remove"
    fi
}

# Update hosts file
update_hosts_file() {
    print_header "Updating /etc/hosts"

    # Remove old entries first
    remove_hosts_entries

    print_info "Adding new hosts entries..."

    # Add kubeAPI host entry
    echo "127.0.0.1 $KUBEAPI_HOST $HOSTS_MARKER" | sudo tee -a /etc/hosts > /dev/null

    print_success "Hosts file updated:"
    grep "$HOSTS_MARKER" /etc/hosts | sed 's/^/  /'
}

# Create cluster
create_cluster() {
    print_header "Creating k3d Cluster"

    print_info "Creating cluster: $CLUSTER_NAME"
    print_info "Config: $CONFIG_FILE"
    print_info "This may take 1-2 minutes..."
    echo ""

    k3d cluster create --config "$CONFIG_FILE"

    print_success "Cluster created successfully"
}

# Wait for cluster ready
wait_for_cluster() {
    print_header "Waiting for Cluster Ready"

    print_info "Waiting for nodes to be Ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=120s

    print_success "All nodes are Ready"
}

# Install Flux in admin mode
install_flux_admin() {
    print_header "Installing Flux (Admin Mode)"

    print_info "Running flux bootstrap github..."
    print_warning "This requires GitHub authentication and repo write access"
    echo ""

    flux bootstrap github \
        --owner="$GITHUB_OWNER" \
        --repository="$GITHUB_REPO" \
        --private=false \
        --personal=true \
        --components-extra=source-watcher \
        --branch="$FLUX_BRANCH" \
        --path="$FLUX_PATH"

    print_success "Flux bootstrap completed"
}

# Install Flux in read-only mode
install_flux_readonly() {
    print_header "Installing Flux (Read-Only Mode)"

    print_info "Installing Flux controllers without GitHub integration..."
    flux install

    print_success "Flux controllers installed"

    print_info "Waiting for Flux controllers to be ready..."
    kubectl wait --for=condition=Ready pods --all -n flux-system --timeout=180s

    print_success "Flux controllers are ready"

    print_info "Creating GitRepository resource (public HTTPS)..."

    # Create GitRepository manifest
    cat <<EOF | kubectl apply -f -
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: $FLUX_BRANCH
  url: https://github.com/$GITHUB_OWNER/$GITHUB_REPO
EOF

    print_success "GitRepository created"

    print_info "Creating Kustomization resource..."

    # Create Kustomization manifest
    cat <<EOF | kubectl apply -f -
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./$FLUX_PATH
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
EOF

    print_success "Kustomization created"

    print_info "Flux is now syncing from public repository (read-only)"
}

# Wait for Flux to be ready
wait_for_flux_ready() {
    print_header "Waiting for Flux Reconciliation"

    print_info "Waiting for GitRepository to be ready..."
    kubectl wait --for=condition=Ready gitrepository/flux-system -n flux-system --timeout=120s || true

    print_info "Waiting for Kustomization to be ready..."
    kubectl wait --for=condition=Ready kustomization/flux-system -n flux-system --timeout=300s || true

    print_success "Flux reconciliation complete"
}

# Display cluster info
display_cluster_info() {
    print_header "Cluster Information"

    echo "Nodes:"
    kubectl get nodes -o wide

    echo ""
    echo "Cluster details:"
    k3d cluster list | grep "$CLUSTER_NAME"

    if [ "$FLUX_MODE" != "none" ]; then
        echo ""
        echo "Flux Status:"
        flux get sources git
        echo ""
        flux get kustomizations
    fi

    echo ""
    print_info "Kubeconfig context:"
    kubectl config current-context

    echo ""
    print_info "API Server: https://$KUBEAPI_HOST:6443"
    print_info "GW HTTP: http://localhost:80"
    print_info "GW HTTPS: https://localhost:443"
}

# Display final instructions
display_final_instructions() {
    print_header "Bootstrap Complete"
    print_success "Cluster $CLUSTER_NAME is ready!"
    echo ""

    if [ "$FLUX_MODE" == "none" ]; then
        echo "Cluster created without Flux."
        echo ""
        echo "To deploy Flux:"
        echo "  Admin mode:     ./scripts/bootstrap.sh --admin"
        echo "  Read-only mode: ./scripts/bootstrap.sh --read-only"
        echo ""
    elif [ "$FLUX_MODE" == "admin" ]; then
        echo "Flux deployed in ADMIN mode (write access to GitHub repo)"
        echo ""
        echo "Check Flux sync status:"
        echo "  flux get sources git"
        echo "  flux get kustomizations"
        echo "  kubectl get kustomization -n flux-system"
        echo ""
    else
        echo "Flux deployed in READ-ONLY mode (public repo, no auth)"
        echo ""
        echo "Check Flux sync status:"
        echo "  flux get sources git"
        echo "  flux get kustomizations"
        echo "  kubectl get kustomization -n flux-system"
        echo ""
        echo "Note: This setup pulls from the public repo without authentication."
        echo "Changes cannot be pushed back to GitHub from this cluster."
        echo ""
    fi

    echo "Monitor all pods:"
    echo "  kubectl get pods -A"
    echo ""
    echo "Access services (once deployed):"
    echo "  HTTP:  curl -k https://app01.localhost/get"
    echo "  HTTP:  curl -k https://grafana.localhost/login"
    echo ""
    echo "To delete cluster:"
    echo "  k3d cluster delete $CLUSTER_NAME"
    echo ""
    echo "To remove /etc/hosts entries:"
    echo "  sudo sed -i.backup '/$HOSTS_MARKER/d' /etc/hosts"
    echo ""
}

# Main execution
main() {
    print_header "k3d Cluster Bootstrap"

    if [ "$FLUX_MODE" == "admin" ]; then
        print_info "Mode: Admin (GitHub auth required)"
    elif [ "$FLUX_MODE" == "readonly" ]; then
        print_info "Mode: Read-Only (no GitHub auth)"
    else
        print_info "Mode: Cluster only (no Flux)"
    fi

    # Run cluster setup steps
    check_prerequisites
    delete_existing_cluster
    update_hosts_file
    create_cluster
    wait_for_cluster

    # Deploy Flux if requested
    if [ "$FLUX_MODE" == "admin" ]; then
        install_flux_admin
        wait_for_flux_ready
    elif [ "$FLUX_MODE" == "readonly" ]; then
        install_flux_readonly
        wait_for_flux_ready
    fi

    # Show final status
    display_cluster_info
    display_final_instructions
}

# Run main function
main
