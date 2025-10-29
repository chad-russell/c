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

# How to build multiple images from a single codebase

When your needs grow beyond just one user on one machine, you might want to build multiple versions of your custom image for different use cases or based on different base images. This guide outlines the configuration steps required to build multiple images out of a single repository.

1. Create a new recipe file.

   * To make this easier, you might want to just duplicate and rename your other recipe file.
   * Make sure to name your recipe files accordingly, for example: `recipe-gnome.yml` for a GNOME version of your image and `recipe-kde.yml` for a KDE version of your image.
2. Edit your new recipe file. You should *at least* change the name of the image to prevent collision with your other images, but other changes can also made at this point.

   * Example:

     recipe-gnome.yml

     ```
     name: weird-gnome

     description: This is the GNOME version of my personal OS image.

     base-image: ghcr.io/ublue-os/silverblue-main

     # ...
     ```

     recipe-kde.yml

     ```
     name: weird-kde

     description: This is the LDE Plasma version of my personal OS image.

     base-image: ghcr.io/ublue-os/kinoite-main

     # ...
     ```
3. Open the build workflow file in `.github/workflows/build.yml` and edit the list of recipe files under `jobs: bluebuild: strategy: matrix: recipe:` to contain all the recipes you want to build.

   * The list simply consists of paths under the `recipes/` folder in your git repository. For example, if you have many recipes and want to store them all in a subdirectory like `recipes/common/`, you can use them in `build.yml` by specifying the subdirectory.
   * After this step, all versions of your custom images should start building.
   * Example:

     build.yml

     ```
     # ...

     jobs:

     bluebuild:

     strategy:

     matrix:

     recipe:

     - recipe-gnome.yml

     - recipe-kde.yml

     # or like this if you want to have the recipes in their own directory:

     # - common/gnome.yml

     # - common/kde.yml

     # ...
     ```

If you want to share parts of configuration between your different image, check out [“How to split configuration into multiple files”](/how-to/multiple-files).

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/how-to/multiple-images.mdx)

[Previous
 How to split configuration into multiple files](/how-to/multiple-files/)   [Next
 How to sync your repository up with the template](/how-to/sync/)
