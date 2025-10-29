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
* [Default configuration options](#default-configuration-options)
  + [type:](#type)
  + [source: (optional)](#source-optional)
  + [no-cache: (optional)](#no-cache-optional)
  + [env: (optional)](#env-optional)
  + [secrets: (optional)](#secrets-optional)
* [How modules are launched](#how-modules-are-launched)
* [Module run environment](#module-run-environment)
  + [CONFIG\_DIRECTORY](#config_directory)
  + [MODULE\_DIRECTORY](#module_directory)
  + [IMAGE\_NAME](#image_name)
  + [IMAGE\_REGISTRY](#image_registry)
  + [BASE\_IMAGE](#base_image)
  + [OS\_VERSION](#os_version)
  + [get\_json\_array](#get_json_array)
* [module.yml](#moduleyml)
  + [name:](#name)
  + [shortdesc:](#shortdesc)
  + [example:](#example)

## On this page

* [Overview](#_top)
* [Default configuration options](#default-configuration-options)
  + [type:](#type)
  + [source: (optional)](#source-optional)
  + [no-cache: (optional)](#no-cache-optional)
  + [env: (optional)](#env-optional)
  + [secrets: (optional)](#secrets-optional)
* [How modules are launched](#how-modules-are-launched)
* [Module run environment](#module-run-environment)
  + [CONFIG\_DIRECTORY](#config_directory)
  + [MODULE\_DIRECTORY](#module_directory)
  + [IMAGE\_NAME](#image_name)
  + [IMAGE\_REGISTRY](#image_registry)
  + [BASE\_IMAGE](#base_image)
  + [OS\_VERSION](#os_version)
  + [get\_json\_array](#get_json_array)
* [module.yml](#moduleyml)
  + [name:](#name)
  + [shortdesc:](#shortdesc)
  + [example:](#example)

# Module

A module is a self-contained part of the build executed during the build process of an image. Most modules are bash scripts ([blue-build/modules](https://github.com/blue-build/modules)), but some default modules are implemented with Containerfile templating directly in [blue-build/cli](https://github.com/blue-build/cli). Modules are configured in the [recipe](/reference/recipe/) or an external configuration file.

## Default configuration options

[Section titled “Default configuration options”](#default-configuration-options)

Modules themselves differ on what configuration options they use and require, and that information is available on module-specific reference pages. These options are always available.

### `type:`

[Section titled “type:”](#type)

The name of the module to run. This corresponds to the name of the directory as well as the script’s name in the module’s directory. For example, using `test` would call the script in `$MODULE_DIRECTORY/test/test.sh`.

### `source:` (optional)

[Section titled “source: (optional)”](#source-optional)

Caution

A module can execute arbitrary code both in the image build and consequently on your booted system, so make sure you trust the source you specify.

The URL of the module repository (an OCI image) to pull the module from. If left unspecified, the source use is a hybrid the default module repository at `ghcr.io/blue-build/modules` and the custom modules in the local `modules/` directory, where custom modules overwrite the default modules.

### `no-cache:` (optional)

[Section titled “no-cache: (optional)”](#no-cache-optional)

When set to `true`, the module is run regardless if previous layers in the build have been cached. This is useful in [stages](/reference/stages) where the goal is to build the latest version of a program from a git repository. Otherwise, the module wouldn’t run again unless previous layers were also re-ran.

### `env:` (optional)

[Section titled “env: (optional)”](#env-optional)

A list of environment variables to set when running the module. These variables are available to the module’s script and can be used to customize its behavior. Set these as key-value pairs.

```
type: script

env:

TEST: 'test'

snippets:

- '[ -n "$TEST" ]'
```

### `secrets:` (optional)

[Section titled “secrets: (optional)”](#secrets-optional)

A list of secrets to mount when running the module. These secrets are available to the module’s script and can be used only by it.

## How modules are launched

[Section titled “How modules are launched”](#how-modules-are-launched)

A module added into an image’s configuration is turned into a `RUN`-statement that launches the module with a JSON version of its configuration in the generated Containerfile (or an equivalent dynamic bash command if using the legacy template).

For example, the following module configuration would be turned into the `RUN`-statement below:

recipes/module.yml

```
type: rpm-ostree

install:

- micro

uninstall:

- firefox

- firefox-langpacks
```

Containerfile

```
# the contents of this statement have been simplified slightly to better illustrate the topic on hand

RUN /tmp/modules/rpm-ostree/rpm-ostree.sh '{"type":"rpm-ostree,"from-file":"module.yml","repos":null,"install":["micro"],"remove":["firefox","firefox-langpacks"]}'
```

## Module run environment

[Section titled “Module run environment”](#module-run-environment)

Every module is ran in an environment containing the following environment variables and functions.

### `CONFIG_DIRECTORY`

[Section titled “CONFIG\_DIRECTORY”](#config_directory)

Environment variable containing the path to the files for the build (`/tmp/files` or `/tmp/config`).

### `MODULE_DIRECTORY`

[Section titled “MODULE\_DIRECTORY”](#module_directory)

Environment variable containing the path to the directory containing all the modules of the module repository the current module is from (`/tmp/modules`).

### `IMAGE_NAME`

[Section titled “IMAGE\_NAME”](#image_name)

Environment variable containing the name of the image declared in `recipe.yml`.

### `IMAGE_REGISTRY`

[Section titled “IMAGE\_REGISTRY”](#image_registry)

Environment variable containing the registry URL and namespace (usually `ghcr.io/<username>`). Can be used with `IMAGE_NAME` to get the full image URL.

### `BASE_IMAGE`

[Section titled “BASE\_IMAGE”](#base_image)

Environment variable containing the URL of the OCI image used as the base.

### `OS_VERSION`

[Section titled “OS\_VERSION”](#os_version)

Environment variable containing the major version of running operating system. The value is gathered from the `VERSION_ID` in `/etc/os-release`.

### `get_json_array`

[Section titled “get\_json\_array”](#get_json_array)

Bash function that helps with reading arrays from the module’s configuration.

```
get_json_array OUTPUT_VAR_NAME 'try .key.to.array[]' "${1}"
```

or less readable, but safer command for extracting array values:

```
get_json_array OUTPUT_VAR_NAME 'try .["key"].["to"].["array"][]' "${1}"
```

## `module.yml`

[Section titled “module.yml”](#moduleyml)

A `module.yml` is the metadata file for a public module, used on the website to generate module reference pages. May be used in future projects to showcase modules and supply some defaults for them.

### `name:`

[Section titled “name:”](#name)

The name of the module, same as the name of the directory and script.

### `shortdesc:`

[Section titled “shortdesc:”](#shortdesc)

A short description of the module, ideally not more than one sentence long. This is used in website metadata or anywhere a shorter module description is needed.

### `example:`

[Section titled “example:”](#example)

A YAML string of example configuration showcasing the configuration options available with inline documentation to describe them.

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/reference/module.mdx)

[Previous
 blue-build/github-action](/reference/github-action/)   [Next
 Stages](/reference/stages/)
