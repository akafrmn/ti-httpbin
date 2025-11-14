# Example Application - HTTPBin

This is an example application that demonstrates how to expose services through Envoy Gateway.

## Overview

The example app deploys:
- **HTTPBin Service**: A simple HTTP request/response testing service
- **Kubernetes Service**: ClusterIP service for internal communication
- **Gateway**: Envoy Gateway configured for HTTP traffic
- **HTTPRoute**: Routes HTTP traffic to the backend service

## Components

### Deployment (`deployment.yaml`)
- Runs 2 replicas of `kennethreitz/httpbin` image
- Health checks: liveness & readiness probes
- Resource limits: 100m CPU, 128Mi memory (per pod)

### Service (`service.yaml`)
- ClusterIP service exposing port 80
- Routes traffic to httpbin pods

### Gateway (`gateway.yaml`)
- `GatewayClass`: References Envoy Gateway controller
- `Gateway`: Listens on port 80 for HTTP traffic
- `HTTPRoute`: Routes traffic to httpbin service

## Quick Start

### Apply the Example App

```bash
# Using Flux (if synced via kustomization)
kubectl apply -k apps/example-app/

# Or manual apply
kubectl apply -f apps/example-app/
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n example-app

# Check services
kubectl get svc -n example-app

# Check gateway status
kubectl get gateway -n example-app
kubectl get httproute -n example-app
```

### Test the Application

```bash
# Port forward to the gateway
kubectl port-forward -n example-app svc/envoy-gateway 8080:80 &

# Make a test request
curl http://localhost:8080/get

# View request headers
curl http://localhost:8080/headers

# Test POST with JSON
curl -X POST http://localhost:8080/post \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from HTTPBin"}'
```

### Access via Hostname

If using Docker Desktop or local testing:

```bash
# Add to /etc/hosts
127.0.0.1 example.local

# Test via hostname
curl http://example.local/get
```

## Configuration Details

### Hostnames
- `example.local` - Custom hostname
- `localhost` - Loopback (for testing)

### Routes
- Path: `/` (all paths)
- Method: Any
- Backend: httpbin service on port 80

## Cleanup

```bash
# Remove example app
kubectl delete -k apps/example-app/

# Or
kubectl delete namespace example-app
```

## References

- [HTTPBin GitHub](https://github.com/postmanlabs/httpbin)
- [Envoy Gateway HTTPRoute Docs](https://gateway.envoyproxy.io/latest/concepts/traffic/#http-routing)
- [Kubernetes Gateway API](https://gateway.api.k8s.io/)
