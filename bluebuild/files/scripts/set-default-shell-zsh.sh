#!/usr/bin/env bash

set -oue pipefail

preferred_shell="/usr/bin/zsh"

if [ ! -x "$preferred_shell" ]; then
  echo "Expected shell $preferred_shell is not installed" >&2
  exit 1
fi

# Ensure new users default to zsh.
if [ -f /etc/default/useradd ]; then
  if grep -q '^SHELL=' /etc/default/useradd; then
    sed -i "s|^SHELL=.*|SHELL=$preferred_shell|" /etc/default/useradd
  else
    printf '\nSHELL=%s\n' "$preferred_shell" >> /etc/default/useradd
  fi
fi

# Switch root to zsh so the out-of-the-box experience matches the default.
if getent passwd root >/dev/null; then
  usermod --shell "$preferred_shell" root
fi
