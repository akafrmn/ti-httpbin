# Gateway Port-Forward Scripts

Convenient bash scripts for managing port-forwarding to your Envoy Gateway in the local Kubernetes cluster.

## Overview

The `gateway-forward.sh` script provides a simple interface to manage `kubectl port-forward` connections to the HTTPBin service through the Envoy Gateway.

### Why Use This Script?

- ✅ **Easy**: One command to start/stop port-forwarding
- ✅ **Flexible**: Support for custom ports and multiple forwards
- ✅ **Safe**: Checks port availability before binding
- ✅ **Testing**: Built-in test and browser open commands
- ✅ **Management**: View status and logs easily

## Installation

The script is already in the `scripts/` directory and is executable.

### Make Executable (if needed)
```bash
chmod +x scripts/gateway-forward.sh
```

### Add to PATH (optional)
```bash
# Add to your ~/.zshrc or ~/.bashrc:
export PATH="$PATH:/Users/your-user/work/ti/playson/ti-httpbin/scripts"

# Then use from anywhere:
gateway-forward.sh start
```

### Create Alias (optional)
```bash
# Add to your ~/.zshrc or ~/.bashrc:
alias gw="~/path/to/ti-httpbin/scripts/gateway-forward.sh"

# Then use:
gw start
gw stop
gw test
```

## Usage

### Basic Commands

#### Start Port-Forward (Default: 8080)
```bash
./scripts/gateway-forward.sh start
# Access: http://localhost:8080
```

#### Start on Custom Port
```bash
./scripts/gateway-forward.sh start 3000
# Access: http://localhost:3000
```

#### Stop Port-Forward
```bash
./scripts/gateway-forward.sh stop
```

#### Check Status
```bash
./scripts/gateway-forward.sh status
```

#### Restart Port-Forward
```bash
./scripts/gateway-forward.sh restart
# Or on custom port:
./scripts/gateway-forward.sh restart 3000
```

#### Test Connection
```bash
./scripts/gateway-forward.sh test
# Or on custom port:
./scripts/gateway-forward.sh test 3000
```

#### View Logs
```bash
./scripts/gateway-forward.sh logs
# Or for custom port:
./scripts/gateway-forward.sh logs 3000
```

#### Open in Browser
```bash
./scripts/gateway-forward.sh browser
# Or on custom port:
./scripts/gateway-forward.sh browser 3000
```

#### Multiple Port-Forwards
```bash
./scripts/gateway-forward.sh multiple 8080 8081 8082
# Useful for load testing or parallel testing
```

### Full Help
```bash
./scripts/gateway-forward.sh help
```

## Examples

### Simple Testing Flow

```bash
# Terminal 1: Start port-forward
./scripts/gateway-forward.sh start

# Terminal 2: Run tests
./scripts/gateway-forward.sh test

# Terminal 3: View live logs
./scripts/gateway-forward.sh logs
```

### Load Testing Setup

```bash
# Terminal 1: Start multiple ports
./scripts/gateway-forward.sh multiple 8080 8081 8082

# Terminal 2: Run concurrent tests
for port in 8080 8081 8082; do
  curl http://localhost:$port/uuid &
done
wait
```

### Development Workflow

```bash
# Start in background
./scripts/gateway-forward.sh start &

# Work on your code...
# Commit changes...

# Test changes
curl http://localhost:8080/get | jq .

# When done
./scripts/gateway-forward.sh stop
```

### Browser Testing

```bash
# Start and automatically open browser
./scripts/gateway-forward.sh start && \
./scripts/gateway-forward.sh browser

# Or on custom port
./scripts/gateway-forward.sh start 3000
./scripts/gateway-forward.sh browser 3000
```

## Commands Reference

| Command | Usage | Purpose |
|---------|-------|---------|
| `start` | `./gateway-forward.sh start [PORT]` | Start port-forward |
| `stop` | `./gateway-forward.sh stop` | Stop all port-forwards |
| `status` | `./gateway-forward.sh status` | Show active forwards |
| `restart` | `./gateway-forward.sh restart [PORT]` | Restart port-forward |
| `test` | `./gateway-forward.sh test [PORT]` | Test connection |
| `logs` | `./gateway-forward.sh logs [PORT]` | View logs |
| `multiple` | `./gateway-forward.sh multiple PORT1 PORT2...` | Start multiple |
| `browser` | `./gateway-forward.sh browser [PORT]` | Open in browser |
| `help` | `./gateway-forward.sh help` | Show help |

## Features

### ✅ Port Management
- Automatic port availability checking
- Kill conflicting processes with confirmation
- Multiple simultaneous port-forwards

### ✅ Error Handling
- Prerequisites checking (kubectl, cluster, namespace, service)
- Connection testing with curl
- Detailed error messages

### ✅ Logging
- Automatic log file creation: `/tmp/gateway-forward-PORT.log`
- Easy log viewing with `logs` command
- Tail output for quick inspection

### ✅ Convenience
- Open in browser directly
- Test HTTP endpoints automatically
- Status display with active forwards

### ✅ Automation
- Background execution
- Exit status codes for scripting
- Combinable with other commands

## Troubleshooting

### Port Already in Use
```bash
# Script will ask to kill it
./scripts/gateway-forward.sh start

# Or manually:
lsof -i :8080
kill -9 <PID>

# Try different port:
./scripts/gateway-forward.sh start 3000
```

### Connection Refused
```bash
# Check if port-forward is running
./scripts/gateway-forward.sh status

# Check logs
./scripts/gateway-forward.sh logs

# Check if pods are running
kubectl get pods -n example-app
```

### No Response from Gateway
```bash
# Test connection
./scripts/gateway-forward.sh test

# Check gateway status
kubectl describe gateway envoy-gateway -n example-app

# Check pod logs
kubectl logs -n example-app -l app.kubernetes.io/name=httpbin
```

## Integration with Other Tools

### With curl
```bash
./scripts/gateway-forward.sh start &
sleep 1
curl -s http://localhost:8080/get | jq .
```

### With HTTPie
```bash
./scripts/gateway-forward.sh start &
sleep 1
http http://localhost:8080/get
```

### With Artillery (load testing)
```bash
./scripts/gateway-forward.sh multiple 8080 8081 8082 &
artillery quick --count 100 --num 10 http://localhost:8080/get
```

### With Watch (continuous monitoring)
```bash
./scripts/gateway-forward.sh start &
watch -n 1 'curl -s http://localhost:8080/uuid | jq .'
```

## Bash Completion (Optional)

Add to your `.bashrc` or `.zshrc`:

```bash
_gateway_forward_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local commands="start stop status restart test logs multiple browser help"
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
}

complete -F _gateway_forward_completion gateway-forward.sh
```

## Environment Variables

The script uses the following defaults (hardcoded in the script):

- `NAMESPACE`: `example-app`
- `SERVICE`: `httpbin`
- `DEFAULT_PORT`: `8080`

To customize, edit the script or override before running:

```bash
NAMESPACE=my-app SERVICE=my-service ./scripts/gateway-forward.sh start
```

## Advanced Usage

### Background Execution
```bash
# Start in background, save PID
./scripts/gateway-forward.sh start 8080 &
PF_PID=$!

# Do work...

# Stop by PID
kill $PF_PID
```

### Chained Commands
```bash
# Start, test, and open browser
./scripts/gateway-forward.sh start && \
./scripts/gateway-forward.sh test && \
./scripts/gateway-forward.sh browser
```

### Conditional Execution
```bash
# Only start if not already running
if ! ./scripts/gateway-forward.sh status | grep -q "Active"; then
  ./scripts/gateway-forward.sh start
fi
```

### Exit Status Codes
```bash
./scripts/gateway-forward.sh test
if [ $? -eq 0 ]; then
  echo "Gateway is reachable"
else
  echo "Gateway is not reachable"
fi
```

## Tips & Tricks

### Keep Terminal Clean
```bash
# Start in background and detach
nohup ./scripts/gateway-forward.sh start > /dev/null 2>&1 &

# Or use screen/tmux
tmux new-session -d -s gw './scripts/gateway-forward.sh start'
```

### Monitor Multiple Ports
```bash
# Terminal 1
./scripts/gateway-forward.sh logs 8080

# Terminal 2
./scripts/gateway-forward.sh logs 8081

# Terminal 3
./scripts/gateway-forward.sh logs 8082
```

### Automated Testing
```bash
#!/bin/bash
./scripts/gateway-forward.sh start 8080
sleep 2

for i in {1..100}; do
  curl -s http://localhost:8080/get | jq '.origin'
done

./scripts/gateway-forward.sh stop
```

## Logs Location

All port-forward logs are stored in:
```
/tmp/gateway-forward-PORT.log
```

Example:
```
/tmp/gateway-forward-8080.log
/tmp/gateway-forward-3000.log
```

## Support

For issues or feature requests:

1. Check the script help: `./gateway-forward.sh help`
2. View logs: `./gateway-forward.sh logs`
3. Check gateway status: `./scripts/gateway-forward.sh status`
4. Check cluster: `kubectl cluster-info`

## See Also

- [Envoy Gateway Documentation](https://gateway.envoyproxy.io)
- [Kubectl Port-Forward Docs](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)
- [HTTPBin GitHub](https://github.com/postmanlabs/httpbin)
