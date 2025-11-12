#!/usr/bin/env bash

podman build \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  -f /home/crussell/Code/c/vicinae/Containerfile \
  -t localhost/vicinae-runtime