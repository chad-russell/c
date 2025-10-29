{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;

    # zplug = {
    # enable = true;
    # plugins = [ ];
    # };
  };

  programs.zsh.profileExtra = ''
    # Ensure Nix profile binaries take precedence over Homebrew
    export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
    export PATH="$PATH:$HOME/.npm-global/bin"
    export PATH="$PATH:$HOME/.opencode/bin"
    export PATH="$PATH:/opt/homebrew/bin"
    export PATH="$HOME/.local/bin:$PATH"
  '';

  home.sessionVariables = {
    EDITOR = "nvim";
    AWS_PROFILE = "chad";
  };

  home.shellAliases = {
    ".." = "cd ..";
    "..." = "cd ../..";
    e = "eza";
    vi = "nvim";
    vim = "nvim";
    v = "nvim";
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # TODO(chad): turn these functions into nix packages/apps, include in home.packages
  programs.zsh.initContent = ''
    bindkey '^f' autosuggest-accept;

    set -o vi;

    bindkey '^P' up-line-or-search;
    bindkey '^N' down-line-or-search;

    function mkcd {
        mkdir $1;
        cd $1;
    }

    function homeup {
        home-manager switch --flake ~/nix/#${config.configurationName}
    }

    function nixup {
        sudo nixos-rebuild switch --flake ~/nix/#${config.configurationName}
    }

    function killport {
        lsof -ti:$1 | xargs kill -9
    }

    # Prevent git from asking for the passphrase every fucking time
    function ssh_reload {
        ssh-add ~/.ssh/id_rsa;
    }

    function nixedit {
        cursor ~/nix;
    }

    alias pr='pnpm run';
  '';
}
