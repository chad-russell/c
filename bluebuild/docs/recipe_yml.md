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
  + [name:](#name)
  + [description:](#description)
  + [alt-tags: (optional)](#alt-tags-optional)
  + [base-image:](#base-image)
  + [image-version:](#image-version)
  + [blue-build-tag: (optional)](#blue-build-tag-optional)
  + [nushell-version: (optional)](#nushell-version-optional)
  + [stages: (optional)](#stages-optional)
  + [modules:](#modules)

## On this page

* [Overview](#_top)
  + [name:](#name)
  + [description:](#description)
  + [alt-tags: (optional)](#alt-tags-optional)
  + [base-image:](#base-image)
  + [image-version:](#image-version)
  + [blue-build-tag: (optional)](#blue-build-tag-optional)
  + [nushell-version: (optional)](#nushell-version-optional)
  + [stages: (optional)](#stages-optional)
  + [modules:](#modules)

# recipe.yml

A `recipe.yml` file describes the build process of a custom image. The top-level keys set the metadata and base for the image, and modules are build steps that add things on top of the base.

Tip

You can add the lines below to the top of your recipe to get yaml completion in your favorite editor.

```
---

# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json
```

### `name:`

[Section titled “name:”](#name)

The image name. Used when publishing to GHCR as `ghcr.io/<user>/<name>`.

#### Example:

[Section titled “Example:”](#example)

recipes/recipe.yml

```
name: weird-os
```

### `description:`

[Section titled “description:”](#description)

The image description. Published to GHCR in the image metadata.

#### Example:

[Section titled “Example:”](#example-1)

recipes/recipe.yml

```
description: This is my personal OS image.
```

### `alt-tags:` (optional)

[Section titled “alt-tags: (optional)”](#alt-tags-optional)

Allows setting custom tags on the recipe’s final image. Adding tags to this property will override the `latest` and timestamp tags.

#### Example:

[Section titled “Example:”](#example-2)

```
alt-tags:

- gts

- stable
```

### `base-image:`

[Section titled “base-image:”](#base-image)

The [OCI](https://opencontainers.org/) image to base your custom image on. Only atomic Fedora images and those based on them are officially supported. Universal Blue is recommended. A list of uBlue images can be found on the [uBlue website](https://universal-blue.org/images/). BlueBuild-built images can be used as well.

#### Example:

[Section titled “Example:”](#example-3)

recipes/recipe.yml

```
base-image: ghcr.io/ublue-os/silverblue-main
```

### `image-version:`

[Section titled “image-version:”](#image-version)

The tag of the base image to build on. Used to select a version explicitly (`40`) or to always use the latest stable version (`latest`). A list of all available tags can be viewed by pasting your `base-image` url into your browser.

#### Example:

[Section titled “Example:”](#example-4)

recipes/recipe.yml

```
image-version: 40
```

### `blue-build-tag:` (optional)

[Section titled “blue-build-tag: (optional)”](#blue-build-tag-optional)

Version of the BlueBuild CLI to pull into your image. Supply the tag of the cli release container to pull, see [the list of available tags](https://github.com/blue-build/cli/pkgs/container/cli/versions?filters%5Bversion_type%5D=tagged) for reference. Useful for testing out pre-release versions of BlueBuild CLI. Default: `latest-installer`. Set to to `none` to opt out of installing the CLI into your image.

### `nushell-version:` (optional)

[Section titled “nushell-version: (optional)”](#nushell-version-optional)

Version of nushell to pull to `/usr/libexec/bluebuild/nu/nu` for use by modules. Change only if you need a specific version of Nushell, changing this might break some BlueBuild modules. Set to to `none` to opt out of installing Nushell into your image (this will break modules that depend on it).

### `stages:` (optional)

[Section titled “stages: (optional)”](#stages-optional)

A list of [stages](/reference/stages/) that are executed before the build of the final image. This is useful for compiling programs from source without polluting the final bootable image.

#### Example:

[Section titled “Example:”](#example-5)

```
stages:

- name: bluebuild

from: docker.io/library/rust:1.77

modules: # same as the top-level modules key, but executed in the custom stage

- type: script

no-cache: true

snippets:

- cargo install --locked --all-features blue-build
```

### `modules:`

[Section titled “modules:”](#modules)

A list of [modules](/reference/module/) that is executed in order. Multiple of the same module can be included.

Each item in this list should have at least a `type:` or be specified to be included from an external file in the `recipes/` directory with `from-file:`.

#### Example:

[Section titled “Example:”](#example-6)

recipes/recipe.yml

```
modules:

- type: rpm-ostree

# rest of the module config...

- from-file: common-packages.yml
```

The included file can have one or multiple modules:

recipes/common-packages.yml

```
# one module

type: rpm-ostree

# rest of the module config...
```

recipes/common-packages.yml

```
# multiple modules

modules:

- type: script

# rest of the module config...

- type: rpm-ostree

# rest of the module config...
```

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/reference/recipe.mdx)

[Previous
 How to sync your repository up with the template](/how-to/sync/)   [Next
 blue-build/github-action](/reference/github-action/)

