#!/bin/bash

# CLuster used: local docker desktop with kind
# Options: use k3d for more automation

# Install Flux
flux bootstrap github --owner=akafrmn \
  --repository=ti-httpbin --private=false \
  --personal=true --components-extra source-watcher \
  --branch=main --path=clusters/docker-desktop
