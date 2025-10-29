#!/usr/bin/env bash

set -oue pipefail

# Guarantee that the docker group exists even if the package install did not create it.
groupadd -f docker
