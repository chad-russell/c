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
* [Creating a new module](#creating-a-new-module)
* [Coding your module](#coding-your-module)
* [Using your module](#using-your-module)

## On this page

* [Overview](#_top)
* [Creating a new module](#creating-a-new-module)
* [Coding your module](#coding-your-module)
* [Using your module](#using-your-module)

# How to make a custom module

If you want to extend your image with custom functionality that requires configuration, you should create a [module](/reference/module/).

## Creating a new module

[Section titled “Creating a new module”](#creating-a-new-module)

1. Open your repository and create a new directory inside the `modules/` directory. The name of this directory should be the name of your module.
   * This name will be used as the `type:` when launching your module.
   * If this name has multiple parts, they should be separated with a dash `-`.
   * As a guideline for (to be) official modules, the name should be a short and sweet noun or modifier-noun combination, without a `-installer` or `-setup` suffix being recommended.
2. Inside your newly created directory, create a file called `<name-of-your-module>.sh` and paste the following code into it:

   modules/<name-of-your-module>/<name-of-your-module>.sh

   ```
   #!/usr/bin/env bash

   set -euo pipefail
   ```

   * This makes sure the correct shell is used and errors in your module cause the build to fail.
3. You have now created an empty module and can proceed to coding it.

## Coding your module

[Section titled “Coding your module”](#coding-your-module)

This guide only includes the bare minimum information to get you started on your coding adventure. Check out the [module reference](/reference/module/) for more technical information about modules.

When being launched, your module receives its configuration as a JSON string as the first argument. It can be read from in bash using `jq` like this:

modules/<name-of-your-module>/<name-of-your-module>.sh

```
#!/usr/bin/env bash

set -euo pipefail

# read a single variable from the configuration

# `try` makes the command output 'null' if the key is not found, otherwise it will error out and the build will fail

# the `.["var"]` syntax is optional and could be replaced with the less safe and more error-prone `.var` syntax

VAR=$(echo "$1" | jq -r 'try .["var"]')

echo "$VAR"

# read an array from the configuration

get_json_array ARRAY 'try .["array"][]' "$1"

# loop over the array

for THING in "${ARRAY[@]}"; do

echo "$THING"

done
```

In addition to the module’s own configuration, each module has access to a set of environment variables. Check out the [module reference’s run environment section](/reference/module/#module-run-environment) for a list.

Though bash is the recommended language to write modules, they can technically be written in any language as long as the `.sh` is used to launch them while passing the configuration.

## Using your module

[Section titled “Using your module”](#using-your-module)

Your custom modules are available by default in custom images built in the same repository. There is no need to specify the source, you can just use them the same way you can use default modules. If the name of your custom module is the same as a default module’s name, the custom module will always be used instead.

recipe.yml

```
modules:

- type: <name-of-your-module>

option: true
```

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/how-to/making-modules.mdx)

[Previous
 How to build and test locally](/how-to/local/)   [Next
 How to use BlueBuild modules from a Containerfile](/how-to/minimal-setup/)
