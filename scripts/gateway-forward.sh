#!/bin/bash

################################################################################
#                                                                              #
#  Gateway Port-Forward Script                                               #
#  Manage kubectl port-forward to Envoy Gateway via HTTPBin service         #
#                                                                              #
#  Usage: ./gateway-forward.sh [COMMAND] [OPTIONS]                           #
#                                                                              #
################################################################################

set -e

# Configuration
NAMESPACE="example-app"
SERVICE="httpbin"
DEFAULT_PORT=8080
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

print_usage() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║              🌐 Gateway Port-Forward Script                              ║
║                                                                           ║
║  Manage port-forwarding to Envoy Gateway in your local k8s cluster      ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

USAGE:
  ./gateway-forward.sh [COMMAND] [OPTIONS]

COMMANDS:
  start [PORT]        Start port-forward (default: 8080)
                      Examples:
                        ./gateway-forward.sh start              # Uses port 8080
                        ./gateway-forward.sh start 3000         # Uses port 3000

  stop                Stop all port-forwards

  status              Show port-forward status

  restart [PORT]      Restart port-forward (default: 8080)

  test [PORT]         Test gateway connection (default: 8080)

  logs [PORT]         Show port-forward logs (default: 8080)

  multiple PORTS...   Start multiple port-forwards
                      Example: ./gateway-forward.sh multiple 8080 8081 8082

  browser [PORT]      Open gateway in browser (default: 8080)

  help                Show this help message

EXAMPLES:
  # Start simple port-forward
  ./gateway-forward.sh start

  # Start on custom port
  ./gateway-forward.sh start 3000

  # Test connection
  ./gateway-forward.sh test

  # Start multiple ports for load testing
  ./gateway-forward.sh multiple 8080 8081 8082

  # Open in browser
  ./gateway-forward.sh browser

  # View logs
  ./gateway-forward.sh logs

  # Stop everything
  ./gateway-forward.sh stop

OPTIONS:
  -h, --help          Show help message
  -v, --verbose       Verbose output

EOF
}

################################################################################
# Core Functions
################################################################################

check_prerequisites() {
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi

    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi

    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' not found. Have you deployed the example app?"
        exit 1
    fi

    # Check if service exists
    if ! kubectl get service "$SERVICE" -n "$NAMESPACE" &> /dev/null; then
        log_error "Service '$SERVICE' not found in namespace '$NAMESPACE'."
        exit 1
    fi
}

check_port_available() {
    local port=$1

    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

get_port_process() {
    local port=$1
    lsof -ti:$port 2>/dev/null || echo ""
}

cmd_start() {
    local port=${1:-$DEFAULT_PORT}

    check_prerequisites

    log_info "Starting port-forward on port $port..."

    # Check if port is available
    if ! check_port_available $port; then
        local pid=$(get_port_process $port)
        log_error "Port $port is already in use (PID: $pid)"
        read -p "Kill process and continue? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill -9 $pid 2>/dev/null || true
            sleep 1
        else
            exit 1
        fi
    fi

    # Start port-forward in background
    kubectl port-forward -n "$NAMESPACE" svc/"$SERVICE" "$port":80 \
        > /tmp/gateway-forward-$port.log 2>&1 &

    local pf_pid=$!
    sleep 2

    # Check if port-forward started successfully
    if ! ps -p $pf_pid > /dev/null 2>&1; then
        log_error "Failed to start port-forward. Check logs:"
        cat /tmp/gateway-forward-$port.log
        exit 1
    fi

    log_success "Port-forward started successfully!"
    log_info "PID: $pf_pid"
    log_info "URL: http://localhost:$port"
    log_info "Logs: /tmp/gateway-forward-$port.log"
    echo ""
    log_info "Test with: curl http://localhost:$port/get"
    log_info "Browser: open http://localhost:$port"
    log_info "Stop with: ./gateway-forward.sh stop"
}

cmd_stop() {
    log_info "Stopping all port-forwards..."

    local stopped=0
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            log_success "Stopped port-forward (PID: $pid)"
            ((stopped++))
        fi
    done < <(ps aux | grep "kubectl port-forward.*httpbin" | grep -v grep)

    if [ $stopped -eq 0 ]; then
        log_warning "No active port-forwards found"
    else
        log_success "Stopped $stopped port-forward(s)"
    fi
}

cmd_status() {
    log_info "Checking port-forward status..."
    echo ""

    # Check for active port-forwards
    local found=0
    while IFS= read -r line; do
        found=1
        local pid=$(echo "$line" | awk '{print $2}')
        local port=$(echo "$line" | grep -oP 'svc/\S+\s+\K[0-9]+' || echo "N/A")

        log_success "Active port-forward found"
        log_info "  PID: $pid"
        log_info "  Port: $port:80"
        log_info "  URL: http://localhost:$port"
        echo ""
    done < <(ps aux | grep "kubectl port-forward.*httpbin" | grep -v grep)

    if [ $found -eq 0 ]; then
        log_warning "No active port-forwards found"
        log_info "Start one with: ./gateway-forward.sh start"
    fi
}

cmd_restart() {
    local port=${1:-$DEFAULT_PORT}
    log_info "Restarting port-forward on port $port..."
    cmd_stop
    sleep 1
    cmd_start $port
}

cmd_test() {
    local port=${1:-$DEFAULT_PORT}

    log_info "Testing gateway connection on port $port..."
    echo ""

    # Test if service is reachable
    if ! timeout 5 bash -c "</dev/null >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        log_error "Cannot connect to localhost:$port"
        log_info "Make sure port-forward is running:"
        log_info "  ./gateway-forward.sh start $port"
        return 1
    fi

    log_success "Connection successful!"
    echo ""

    # Test HTTP endpoint
    log_info "Testing HTTP endpoint /get..."
    if command -v curl &> /dev/null; then
        local response=$(curl -s http://localhost:$port/get | head -c 100)
        if [ -z "$response" ]; then
            log_error "No response from gateway"
            return 1
        fi
        log_success "Response received:"
        echo ""
        curl -s http://localhost:$port/get | jq . 2>/dev/null || curl -s http://localhost:$port/get
    else
        log_warning "curl not installed, skipping HTTP test"
    fi
}

cmd_logs() {
    local port=${1:-$DEFAULT_PORT}
    local logfile="/tmp/gateway-forward-$port.log"

    if [ ! -f "$logfile" ]; then
        log_warning "No logs found for port $port"
        log_info "Log file: $logfile"
        return 1
    fi

    log_info "Port-forward logs for port $port:"
    echo ""
    tail -20 "$logfile"
}

cmd_multiple() {
    if [ $# -eq 0 ]; then
        log_error "Please specify port numbers"
        log_info "Usage: ./gateway-forward.sh multiple 8080 8081 8082"
        return 1
    fi

    check_prerequisites

    log_info "Starting port-forwards on ports: $@"
    echo ""

    local count=0
    for port in "$@"; do
        log_info "Starting on port $port..."

        if ! check_port_available $port; then
            log_warning "Port $port already in use, skipping..."
            continue
        fi

        kubectl port-forward -n "$NAMESPACE" svc/"$SERVICE" "$port":80 \
            > /tmp/gateway-forward-$port.log 2>&1 &

        sleep 1
        ((count++))
    done

    echo ""
    log_success "Started $count port-forward(s)"
    echo ""
    log_info "Access via:"
    for port in "$@"; do
        if check_port_available $port; then
            log_info "  http://localhost:$port"
        fi
    done

    echo ""
    log_info "View status: ./gateway-forward.sh status"
    log_info "Stop all: ./gateway-forward.sh stop"
}

cmd_browser() {
    local port=${1:-$DEFAULT_PORT}
    local url="http://localhost:$port"

    log_info "Opening $url in browser..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$url"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$url"
    elif command -v start &> /dev/null; then
        start "$url"
    else
        log_warning "Cannot open browser automatically"
        log_info "Open manually: $url"
    fi
}

################################################################################
# Main
################################################################################

main() {
    local command=${1:-help}
    shift || true

    case "$command" in
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop
            ;;
        status)
            cmd_status
            ;;
        restart)
            cmd_restart "$@"
            ;;
        test)
            cmd_test "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        multiple)
            cmd_multiple "$@"
            ;;
        browser)
            cmd_browser "$@"
            ;;
        help|-h|--help)
            print_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            print_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
