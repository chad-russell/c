{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    tailscale
    (writeShellScriptBin "tailscale-exit-node-switcher" ''
      PATH="${jq}/bin:${fzf}/bin:$PATH"
      set -e

      # Get all exit nodes
      nodes=$(tailscale status --json | jq -r '.Peer[] | select(.ExitNodeOption == true) | "\(.HostName) [\(.TailscaleIPs[0])]"')

      if [ -z "$nodes" ]; then
          echo "No exit nodes available."
          exit 1
      fi

      # Add disable option
      nodes="Disable exit node\n$nodes"

      # Select node
      selected=$(echo -e "$nodes" | fzf --prompt="Select exit node (or disable): ")

      if [ -z "$selected" ]; then
          echo "No selection made. Exiting."
          exit 0
      fi

      if [ "$selected" = "Disable exit node" ]; then
          sudo tailscale up --exit-node="" --ssh --reset
          echo "Exit node disabled."
      else
          # Extract IP from selection
          ip=$(echo "$selected" | grep -oE '\[.*\]' | tr -d '[]')
          sudo tailscale up --exit-node="$ip" --ssh --reset
          echo "Exit node set to $selected."
      fi
    '')
  ];
}
