# BlueBuild Template with Tailscale & Nix &nbsp; [![bluebuild build badge](https://github.com/blue-build/template/actions/workflows/build.yml/badge.svg)](https://github.com/blue-build/template/actions/workflows/build.yml)

This is a custom image based on the BlueBuild template that includes Tailscale pre-installed from the official repository, with the Tailscale service enabled by default, running on Fedora Cosmic Atomic. Nix package manager can be installed manually after first boot.

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Features

This image includes:
- Fedora Cosmic Atomic base OS
- Tailscale pre-installed from the official repository and service enabled
- Nix package manager (available for manual installation)
- Micro text editor
- Firefox and Loupe image viewer as Flatpaks

## Installation

```bash
sudo bluebuild build -B podman -I podman -R podman ./recipes/recipe-niri.yml

sudo bootc switch --transport containers-storage localhost/bluebuild-niri:latest
```

> If you get a message such as 'Image specification is unchanged', that is because bootc is dumb in the way it checks if something is new, and ONLY goes based off of the image tag - so something like `:latest` won't often work. You can just change the tag in the recipe file, or apply a new tag after the fact.

## First Boot

After installation, you'll need to:

1. Reboot your system (if you haven't already after installation)
2. For Tailscale: Run `sudo tailscale up` to authenticate and connect to your tailnet
3. For Nix: Run `/usr/bin/install-nix.sh` to install the Nix package manager

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/blue-build/template
```
