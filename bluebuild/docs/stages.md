[Skip to content](#_top)

[![BlueBuild. A minimal logo with a blue-billed duck holding a golden wrench in its beak.](/_astro/logo-dark.YPxwsi0J.svg) ![BlueBuild. A minimal logo with a blue-billed duck holding a golden wrench in its beak.](/_astro/logo-light.CDOQHsrv.svg)  BlueBuild](/)

Search  `CtrlK`

Cancel

[Home](/) [Docs](/learn/getting-started/) [Blog](/blog/) [Community](/community) [GitHub](https://github.com/blue-build/)

  Select theme   DarkLightAuto

* Learn

  + [Getting started](/learn/getting-started/)
  + [Thinking like a distribution](/learn/mindset/)
  + [Building on Universal Blue](/learn/universal-blue/)
  + [How BlueBuild works](/learn/how/)
  + [Troubleshooting, reporting bugs, and common issues](/learn/troubleshooting/)
  + [Contributing](/learn/contributing/)
  + [Scope](/learn/scope/)
* How-to

  + [How to set up a new repository](/how-to/setup/)
  + [How to set up container signing with cosign](/how-to/cosign/)
  + [How to build an ISO based on your custom image of Fedora Atomic](/how-to/generate-iso/)
  + [How to build and test locally](/how-to/local/)
  + [How to make a custom module](/how-to/making-modules/)
  + [How to use BlueBuild modules from a Containerfile](/how-to/minimal-setup/)
  + [How to set up a custom module repository](/how-to/module-repository/)
  + [How to split configuration into multiple files](/how-to/multiple-files/)
  + [How to build multiple images from a single codebase](/how-to/multiple-images/)
  + [How to sync your repository up with the template](/how-to/sync/)
* Reference

  + [recipe.yml](/reference/recipe/)
  + [blue-build/github-action](/reference/github-action/)
  + [Module](/reference/module/)
  + [Stages](/reference/stages/)
  + Modules

    - [akmods](/reference/modules/akmods/)
    - [bling](/reference/modules/bling/)
    - [brew](/reference/modules/brew/)
    - [chezmoi](/reference/modules/chezmoi/)
    - [containerfile](/reference/modules/containerfile/)
    - [copy](/reference/modules/copy/)
    - [default-flatpaks](/reference/modules/default-flatpaks/)
    - [dnf](/reference/modules/dnf/)
    - [files](/reference/modules/files/)
    - [fonts](/reference/modules/fonts/)
    - [gnome-extensions](/reference/modules/gnome-extensions/)
    - [gschema-overrides](/reference/modules/gschema-overrides/)
    - [initramfs](/reference/modules/initramfs/)
    - [justfiles](/reference/modules/justfiles/)
    - [kargs](/reference/modules/kargs/)
    - [os-release](/reference/modules/os-release/)
    - [rpm-ostree](/reference/modules/rpm-ostree/)
    - [script](/reference/modules/script/)
    - [signing](/reference/modules/signing/)
    - [soar](/reference/modules/soar/)
    - [systemd](/reference/modules/systemd/)
    - [yafti](/reference/modules/yafti/)

[Home](/) [Docs](/learn/getting-started/) [Blog](/blog/) [Community](/community) [GitHub](https://github.com/blue-build/)

  Select theme   DarkLightAuto

On this page

* [Overview](#_top)
* [Module Support](#module-support)
* [Syntax](#syntax)
  + [from:](#from)
  + [name:](#name)
  + [modules:](#modules)
  + [shell: (optional)](#shell-optional)
* [Example](#example)

## On this page

* [Overview](#_top)
* [Module Support](#module-support)
* [Syntax](#syntax)
  + [from:](#from)
  + [name:](#name)
  + [modules:](#modules)
  + [shell: (optional)](#shell-optional)
* [Example](#example)

# Stages

This property will allow users to define a list of Containerfile stages each with their own modules. Stages can be used to compile programs, perform parallel operations, and copy the results into the final image without contaminating the final image.

## Module Support

[Section titled “Module Support”](#module-support)

Currently the only modules that work out-of-the-box are `copy`, `script`, `files`, and `containerfile`. Other modules are dependent on the programs installed on the image. In order to better support some of our essential modules, a setup script is ran at the start of each stage that is not `scratch`. This script will install `curl`, `wget`, `bash`, and `grep` and use the package manager for the detected distributions.

At this time, the following distributions are supported:

* Debian
* Ubuntu
* Fedora
* Alpine

Other distributions can be used, but the necessary packages won’t be installed automatically. Contributions to increase the size of this list is [welcome](https://github.com/blue-build/cli/blob/main/scripts/setup.sh)!

## Syntax

[Section titled “Syntax”](#syntax)

### `from:`

[Section titled “from:”](#from)

The full image ref (image name + tag). This will be set in the `FROM` statement of the stage.

### `name:`

[Section titled “name:”](#name)

The name of the stage. This is used when referencing the stage when using the `from:` property in the `copy` [module](/reference/modules/copy/).

### `modules:`

[Section titled “modules:”](#modules)

The list of modules to execute. The exact same syntax used by the main recipe [`modules:`](/reference/module/) property.

### `shell:` (optional)

[Section titled “shell: (optional)”](#shell-optional)

Allows a user to pass in an array of strings that are passed directly into the [`SHELL` instruction](https://docs.docker.com/reference/dockerfile/#shell).

## Example

[Section titled “Example”](#example)

```
name: custom-image

base-image: ghcr.io/ublue-os/silverblue-main

image-version: 40

description: Stages example

stages:

- name: helix

from: docker.io/library/rust

modules:

- type: script

snippets:

- apt-get update && apt-get install -y git # Install git

- git clone https://github.com/helix-editor/helix.git # Clone the helix repo

- cd helix && RUSTFLAGS="-C target-feature=-crt-static" cargo install --path helix-term # Use cargo to install

- mkdir -p /out/ && mv $CARGO_HOME/bin/hx /out/hx && mv runtime /out/ # Move bin and runtime

modules:

# Copy the bin and runtime from the `helix` stage

- type: copy

from: helix

src: /out/hx

dest: /usr/bin/

- type: copy

from: helix

src: /out/runtime

dest: /usr/lib64/helix/
```

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/reference/stages.mdx)

[Previous
 Module](/reference/module/)   [Next
 akmods](/reference/modules/akmods/)
