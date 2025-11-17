# ti-httpbin

A Kubernetes and Helm deployment repository with automated pre-commit hooks for code quality.

## Pre-commit Hooks Setup

This repository uses [pre-commit](https://pre-commit.com/) hooks to ensure code quality and consistency. The hooks automatically validate YAML files, check formatting, and validate Helm charts before each commit.

### Prerequisites

- Python 3.x
- pip (Python package manager)
- Helm (for chart validation)
- GITHUB_TOKEN in zsrc

### Installation

1. Install pre-commit:

```bash
pip install pre-commit
```

2. Install the git hook scripts:

```bash
pre-commit install
```

3. (Optional) Run hooks manually on all files:

```bash
pre-commit run --all-files
```

### Bootrsp Process

```bash
./scripts/k3d-bootstrap.sh
```

### Check Flux sync
```
kubectl get kustomization -n flux-system
```

### Check all pods
```
kubectl get pods -A
```

### Access services
```
curl -k https://app01.localhost/get
curl -k https://grafana.localhost/login
```
