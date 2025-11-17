#!/bin/bash

#############################################################################
# k3d Cluster Bootstrap Script
#
# Creates a k3d cluster from config and automatically updates /etc/hosts
#
# Cluster Specs:
#   - Name: k3d-local
#   - Master: 1 node (1GB RAM)
#   - Workers: 3 nodes (2GB RAM each)
#   - LoadBalancer: ports 80:80, 443:443
#
# Usage:
#   ./scripts/k3d-bootstrap.sh [--flux]
#
# Options:
#   --flux    Run Flux bootstrap after cluster creation
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

    # Add wildcard localhost entries for apps
    echo "0.0.0.0 app01.k8s.local $HOSTS_MARKER" | sudo tee -a /etc/hosts > /dev/null
    echo "0.0.0.0 *.k8s.local $HOSTS_MARKER" | sudo tee -a /etc/hosts > /dev/null

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

# Display cluster info
display_cluster_info() {
    print_header "Cluster Information"

    echo "Nodes:"
    kubectl get nodes -o wide

    echo ""
    echo "Cluster details:"
    k3d cluster list | grep "$CLUSTER_NAME"

    echo ""
    echo "Node resources:"
    kubectl top nodes 2>/dev/null || echo "  (kubectl top not available - install metrics-server if needed)"

    echo ""
    print_info "Kubeconfig context:"
    kubectl config current-context

    echo ""
    print_info "API Server: https://$KUBEAPI_HOST:6443"
    print_info "LoadBalancer HTTP: http://localhost:80"
    print_info "LoadBalancer HTTPS: https://localhost:443"
}

# Optional Flux bootstrap
run_flux_bootstrap() {
    if [ "$1" == "--flux" ]; then
        print_header "Running Flux Bootstrap"

        if [ -f "scripts/bootstrap.sh" ]; then
            print_info "Running scripts/bootstrap.sh..."
            bash scripts/bootstrap.sh
        else
            print_warning "Flux bootstrap script not found: scripts/bootstrap.sh"
            print_info "Run manually if needed"
        fi
    fi
}

# Main execution
main() {
    print_header "k3d Cluster Bootstrap"

    # Run all steps
    check_prerequisites
    delete_existing_cluster
    update_hosts_file
    create_cluster
    wait_for_cluster
    display_cluster_info
    run_flux_bootstrap "$1"

    # Final message
    print_header "Bootstrap Complete"
    print_success "Cluster $CLUSTER_NAME is ready!"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy Flux: ./scripts/bootstrap.sh (if not using --flux flag)"
    echo "  2. Apply NetworkPolicies: kubectl apply -k infra/networkpolicies/"
    echo "  3. Deploy apps: kubectl apply -k apps/app01/"
    echo ""
    echo "Access apps:"
    echo "  http://app01.k8s.local:80"
    echo "  https://app01.k8s.local:443"
    echo ""
    echo "To delete cluster:"
    echo "  k3d cluster delete $CLUSTER_NAME"
    echo ""
    echo "To remove /etc/hosts entries (optional):"
    echo "  sudo sed -i.backup '/$HOSTS_MARKER/d' /etc/hosts"
    echo ""
}

# Run main function
main "$@"
