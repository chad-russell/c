#!/usr/bin/env bash

# Get host UID
HOST_UID=$(id -u)

# Set XDG_RUNTIME_DIR if not set
: ${XDG_RUNTIME_DIR:=/run/user/$HOST_UID}

# Set WAYLAND_DISPLAY if not set
: ${WAYLAND_DISPLAY:=wayland-0}

# Verify the Wayland socket exists
if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
    echo "Error: Wayland socket not found at $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    echo "Make sure you're running this from a Wayland session."
    exit 1
fi

podman run -d --name vicinae \
  --env WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  --env XDG_RUNTIME_DIR=/run/user/1000 \
  --env QT_QPA_PLATFORM=wayland \
  --env XDG_DATA_DIRS=/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share:/usr/local/share:/usr/share:$HOME/.local/share \
  --volume $XDG_RUNTIME_DIR:/run/user/1000:rw \
  --volume vicinae-config:/home/vicinae/.config \
  --volume vicinae-data:/home/vicinae/.local/share \
  --volume vicinae-cache:/home/vicinae/.cache \
  --volume /usr/share/applications:/usr/share/applications:ro \
  --volume /var/lib/flatpak:/var/lib/flatpak:ro \
  --volume $HOME/.local/share/applications:$HOME/.local/share/applications:ro \
  --volume $HOME/.local/share/flatpak:$HOME/.local/share/flatpak:ro \
  --volume /var/lib/flatpak/exports/share:/var/lib/flatpak/exports/share:ro \
  --volume $HOME/.local/share/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share:ro \
  --volume /usr/share/icons:/usr/share/icons:ro \
  --volume /usr/share/pixmaps:/usr/share/pixmaps:ro \
  --volume $HOME/.local/share/icons:$HOME/.local/share/icons:ro \
  --device /dev/dri \
  --security-opt label=disable \
  --userns=keep-id \
  localhost/vicinae-runtime:latest