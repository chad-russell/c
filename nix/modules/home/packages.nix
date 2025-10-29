{
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    eza
    ripgrep
    fd
    httpie
    tokei
    hyperfine
    jq
    mprocs
    wget
    killall
    du-dust
    restic
    fastfetch
    inxi
    unzip
    lazydocker
    just
    pgcli
    fluxcd
    fzf
    sops
    age
    python313Packages.markitdown
    # inputs.nix-ai-tools.packages.${pkgs.system}.crush
    # inputs.nix-ai-tools.packages.${pkgs.system}.opencode
    # inputs.nix-ai-tools.packages.${pkgs.system}.qwen-code
    # inputs.nix-ai-tools.packages.${pkgs.system}.codex
  ];
}
