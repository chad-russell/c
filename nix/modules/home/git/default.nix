{
  config,
  pkgs,
  self ? null,
  ...
}: {
  # Git
  programs.git = {
    enable = true;
    userName = "Chad Russell";
    userEmail = "chaddouglasrussell@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
    aliases = {
      co = "checkout";
      cm = "commit";
      st = "status";
      br = "branch";
      hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
      type = "cat-file -t";
      dump = "cat-file -p";
      l = "log --pretty=format:'%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]' --decorate --shortstat";
      la = "log --pretty=format:'%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]' --decorate --stat --summary --date=short";
      aa = "add --all";
      amend = "commit --amend";
      unstage = "reset HEAD --";
      last = "log -1 HEAD";
      recent = "for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short)'";
      wip = "commit -am 'WIP'";
      undo = "reset --soft HEAD~1";
      stash-all = "stash save --include-untracked";
      aliases = "config --get-regexp alias";
      gerp = "grep";
      grpe = "grep";
    };
  };

  # Custom git scripts
  home.packages = [
    (pkgs.writeShellScriptBin "git-bs" ''
      #!/usr/bin/env bash

      # Get the list of recent branches, including the current branch
      branches=$(git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short)' | head -n 20)

      # If no branches found, exit
      if [ -z "$branches" ]; then
        echo "No branches found"
        exit 1
      fi

      # Use fzf to select a branch
      selected_branch=$(echo "$branches" | ${pkgs.fzf}/bin/fzf --height 40% --reverse --prompt="Switch to branch > ")

      # If no branch selected (user pressed Esc), exit
      if [ -z "$selected_branch" ]; then
        exit 0
      fi

      # Switch to the selected branch
      git checkout "$selected_branch"
    '')

    (pkgs.writeShellScriptBin "git-refresh" ''
      #!/usr/bin/env bash

      # Default source branch is 'main' if not specified
      SOURCE_BRANCH=''${1:-main}
      CURRENT_BRANCH=$(git symbolic-ref --short HEAD)

      # Check if current branch is the source branch
      if [ "$CURRENT_BRANCH" = "$SOURCE_BRANCH" ]; then
        echo "You are already on the $SOURCE_BRANCH branch. Just pulling latest changes."
        git pull
        exit 0
      fi

      # Check if the source branch exists
      if ! git show-ref --verify --quiet refs/heads/$SOURCE_BRANCH; then
        echo "Branch '$SOURCE_BRANCH' does not exist locally."

        # Check if it exists as a remote branch
        if git ls-remote --heads origin $SOURCE_BRANCH | grep -q $SOURCE_BRANCH; then
          echo "But it exists as a remote branch. Fetching it..."
          git fetch origin $SOURCE_BRANCH:$SOURCE_BRANCH
        else
          echo "And it doesn't exist as a remote branch either. Exiting."
          exit 1
        fi
      fi

      echo "Refreshing $CURRENT_BRANCH with latest changes from $SOURCE_BRANCH..."

      # Fetch the latest changes from remote for the source branch
      echo "Fetching latest changes for $SOURCE_BRANCH..."
      git fetch origin $SOURCE_BRANCH:$SOURCE_BRANCH

      # Merge the source branch into the current branch
      echo "Merging $SOURCE_BRANCH into $CURRENT_BRANCH..."
      if git merge $SOURCE_BRANCH; then
        echo "Successfully refreshed $CURRENT_BRANCH with latest changes from $SOURCE_BRANCH!"
      else
        echo "Merge conflicts detected. Please resolve them manually."
      fi
    '')

    pkgs.gh
    pkgs.lazygit
  ];
}
