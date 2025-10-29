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

# How to sync your repository up with the template

This guide shows you how to sync your custom image git repository to be up-to-date with [blue-build/template](https://github.com/blue-build/template/). This procedure shouldn’t ever be required to keep your repository functional, but might be useful if the template has gained new features since you generated your repository.

0. Open your repository folder on the command line on a machine with `git`.
1. Run the command below to add the template as a Git remote.

   Terminal window

   ```
   git remote add template https://github.com/blue-build/template.git
   ```
2. Run the command below to fetch the latest commits from both your repository and the template.

   Terminal window

   ```
   git fetch --all
   ```
3. Run the command below to merge the changes from the template onto the current branch of your repository. You can do this with the main branch checked out, or another branch, if you want to make sure the changes work before committing to the main branch.

   Terminal window

   ```
   git merge template/main --allow-unrelated-histories
   ```
4. Fix merge conflicts in a merge editor. At least Visual Studio Code supports this feature by default, and other tools might do too, so use what you’re most comfortable with.

   * You can totally ignore changes in the `config/`, `files/`, `recipes/`, and `modules/` directories, the `README.md` and the `cosign.pub`, so that your customizations are not overwritten. Otherwise use your own discretion.
5. Commit the merge and push the changes to your repository.

[Edit page](https://github.com/blue-build/website/edit/main/src/content/docs/how-to/sync.mdx)

[Previous
 How to build multiple images from a single codebase](/how-to/multiple-images/)   [Next
 recipe.yml](/reference/recipe/)
