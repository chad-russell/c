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

# How to split configuration into multiple files

This guide shows you how to include module configuration into your recipe from an external file. This is useful if you’re [building multiple images](/how-to/multiple-images) or your recipe file is just getting cluttered.

1. Create a new YAML file for your module(s) inside the `recipes/` directory.
2. Add your module configuration into the file.
   * The file can configure just one module like this:

     recipes/common-flatpaks.yml

     ```
     ---

     # yaml-language-server: $schema=https://schema.blue-build.org/module-v1.json

     type: default-flatpaks

     system:

     install:

     - org.blender.Blender
     ```
   * Or it can configure multiple modules by declaring them under `modules:`:

     recipes/common-modules.yml

     ```
     ---

     # yaml-language-server: $schema=https://schema.blue-build.org/module-list-v1.json

     modules:

     - type: signing

     - type: files

     files:

     - usr: /usr

     - type: fonts

     fonts:

     nerd-fonts:

     - Hack

     - from-file: common-packages.yml
     ```
3. Import your module configuration file in your recipe with [`from-file:`](/reference/recipe/#modules).
   * Example:

     recipe.yml

     ```
     # ...rest of the recipe

     modules:

     - from-file: common-modules.yml

     - from-file: common-flatpaks.yml
     ```

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/how-to/multiple-files.mdx)

[Previous
 How to set up a custom module repository](/how-to/module-repository/)   [Next
 How to build multiple images from a single codebase](/how-to/multiple-images/)
