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

## On this page

* [Overview](#_top)

# How to use BlueBuild modules from a Containerfile

The [BlueBuild CLI](https://github.com/blue-build/cli) is used to build a [recipe](/reference/recipe/) into a [Containerfile](https://github.com/containers/common/blob/main/docs/Containerfile.5.md), and then building that Containerfile into an OCI image, which can be switched to and booted on an atomic Fedora system. If you’re using recipes, you probably don’t need this guide.

0. To follow this tutorial, you need to have a setup with a Containerfile that is used to build a custom image of atomic Fedora.

   * If you don’t already have such as setup and don’t know where to get started the [`ublue-os/image-template`](https://github.com/ublue-os/image-template/) is a good minimal place to start.
1. Make the following changes to your Containerfile

   * (optional) Add this below each of the `FROM` lines that define images you wish to use BlueBuild modules with YAML configuration in

     ```
     # `yq` be used to pass BlueBuild modules configuration written in yaml

     COPY --from=docker.io/mikefarah/yq /usr/bin/yq /usr/bin/yq
     ```
2. Add a `RUN` statement for the module you wish to use

   ```
   # Run BlueBuild's gnome-extensions module

   RUN \

   # add in the module source code

   --mount=type=bind,from=ghcr.io/blue-build/modules:latest,src=/modules,dst=/tmp/modules,rw \

   # add in the script that sets up the module run environment

   --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:latest,src=/scripts/,dst=/tmp/scripts/ \

   # run the module

   /tmp/scripts/run_module.sh 'gnome-extensions' \

   '{"type":"gnome-extensions","install":["Vitals","GSConnect","Burn My Windows","PaperWM","Gnome 4x UI Improvements"]}'
   ```

   * The `run_module.sh` script takes in two arguments; the module’s name and it’s configuration as a JSON string.
   * If you wish to provide the module configuration as YAML instead of JSON, you can use the following code snippet at the bottom of the `RUN` statement shown above instead. (make sure to add `\n\` to the end of each line, and that you have `yq` installed)

     ```
     # run the module

     config=$'\

     type: gnome-extensions \n\

     install: \n\

     - Vitals # https://extensions.gnome.org/extension/1460/vitals/ \n\

     - GSConnect # https://extensions.gnome.org/extension/1319/gsconnect/ \n\

     - Burn My Windows # https://extensions.gnome.org/extension/4679/burn-my-windows/ \n\

     - PaperWM # https://extensions.gnome.org/extension/6099/paperwm/ \n\

     - Gnome 4x UI Improvements # https://extensions.gnome.org/extension/4158/gnome-40-ui-improvements/ \n\

     ' && \

     /tmp/scripts/run_module.sh "$(echo "$config" | yq eval '.type')" "$(echo "$config" | yq eval -o=j -I=0)"
     ```
   * If you wish to use a module that expects you to include some files, you can copy those to `/tmp/files/` as that is to the directory where the `./files/` directory is accessible in a standard BlueBuild build.

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/how-to/minimal-setup.mdx)

[Previous
 How to make a custom module](/how-to/making-modules/)   [Next
 How to set up a custom module repository](/how-to/module-repository/)
