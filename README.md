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

## Setup Instructions

This repository supports two deployment modes:

### For Repository Admins (Write Access)

If you have admin/write access to the repository and want to set up GitOps with full GitHub integration (deploy keys, webhooks):

```bash
./scripts/bootstrap.sh --admin
```

This will:
- Create a k3d cluster
- Install Flux with GitHub authentication
- Create deploy keys and webhooks
- Enable write-back to the repository

### For Reviewers (Read-Only Access)

If you're reviewing the repository or don't have admin access, you can still deploy and test the full stack locally:

```bash
./scripts/bootstrap.sh --read-only
```

This will:
- Create a k3d cluster
- Install Flux in read-only mode
- Pull from the public GitHub repository (HTTPS, no auth)
- Deploy all applications for local testing

**Note:** Read-only mode cannot push changes back to GitHub, but is perfect for testing and reviewing the deployment.

### Cluster Only (No Flux)

To create just the k3d cluster without Flux:

```bash
./scripts/bootstrap.sh
```

You can deploy Flux later by running the script again with `--admin` or `--read-only`.

## Verification Commands

### Check Flux sync status
```bash
flux get sources git
flux get kustomizations
kubectl get kustomization -n flux-system
```

### Check all pods
```bash
kubectl get pods -A
```

### Access services
```bash
curl -k https://app01.localhost/get
curl -k https://grafana.localhost/login
```

## Cleanup

### Delete the cluster
```bash
k3d cluster delete k3d-local
```

### Remove /etc/hosts entries
```bash
sudo sed -i.backup '/# k3d-local-cluster/d' /etc/hosts
```
