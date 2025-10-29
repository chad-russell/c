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
    OPENROUTER_API_KEY = "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";
    GEMINI_API_KEY = "AIzaSyDKyoYmlRA7l5LSS3sJEs_SmgDmHElCwrQ";
    HOMEASSISTANT_AUTH_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIyYTNmOGI2ODFiYWY0ZjI3ODkyNzJjODBiNjQzNTFjOCIsImlhdCI6MTczODcyMDc5MCwiZXhwIjoyMDU0MDgwNzkwfQ.yfSF1se-WGTjFbJP2ZgLMOjn1a8C-Rsd7yiMklIMG_c";
    MEALIE_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJsb25nX3Rva2VuIjp0cnVlLCJpZCI6ImVkOGU2MDdiLTU5ODQtNDBkNC04ZGFmLTA3MjU2ZjEwNmUxOSIsIm5hbWUiOiJtZWFsZXllIiwiaW50ZWdyYXRpb25faWQiOiJnZW5lcmljIiwiZXhwIjoxODk4ODc0MTEzfQ.pgMrapOfHC1LGEcf8J_54xf3bLP9YAeKLIWKQu2E3rM";
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
