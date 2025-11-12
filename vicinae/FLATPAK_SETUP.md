# Flatpak Integration Setup

## The Solution

The container includes a **wrapper script** at `/usr/bin/flatpak` that automatically forwards all Flatpak commands to your host system using `flatpak-spawn --host`.

This means Flatpak apps "just work" - no configuration needed! 🎉

## Steps

### 1. Rebuild the Container

```bash
./vicinae-ctl.sh update
```

This takes ~10 minutes to rebuild.

### 2. Test It!

After rebuild, just search for any Flatpak app and launch it:
- `spotify` ✅
- `zen` ✅  
- `discord` ✅
- Any Flatpak app will work!

**No configuration needed** - the wrapper handles everything automatically.

## How It Works

When a Flatpak `.desktop` file says `Exec=/usr/bin/flatpak run ...`:

1. **Container sees** the Flatpak `.desktop` files (via `XDG_DATA_DIRS` pointing to Flatpak export dirs)
2. **Container shows** the icons (via mounted `/usr/share/icons` and Flatpak icon dirs)  
3. **Container tries to execute** `/usr/bin/flatpak run ...`
4. **Wrapper intercepts** - `/usr/bin/flatpak` is actually a script that calls `flatpak-spawn --host`
5. **Host executes** the actual Flatpak command on your host system

Result:
- ✅ No nested containers
- ✅ Uses your existing Flatpak installation
- ✅ Apps run with your host user permissions  
- ✅ Access to all your host resources
- ✅ Zero configuration needed

## Bonus: Generic Host Command Execution

The container also includes `/usr/local/bin/host-exec` (similar to distrobox):

```bash
# Run any command on the host
podman exec systemd-vicinae host-exec flatpak list
podman exec systemd-vicinae host-exec firefox
```

## Launching Non-Flatpak Apps

For regular system apps (installed via DNF/RPM), they won't work by default because they're not in the container. Options:

1. **Install in container** - Add them to the Containerfile
2. **Use Launch Prefix** - In Vicinae settings, set Launch Prefix to `host-exec` to run ALL apps on host
3. **Selective wrappers** - Create wrappers like `/usr/bin/firefox` → `flatpak-spawn --host firefox`

Most people just use Flatpaks for GUI apps and it works perfectly!

## Troubleshooting

If Flatpak apps still don't launch after rebuild:

1. **Check the logs**: `./vicinae-ctl.sh logs`
2. **Verify wrapper exists**: `podman exec systemd-vicinae cat /usr/bin/flatpak`
3. **Test manually**: `podman exec systemd-vicinae /usr/bin/flatpak --version`
4. **Test host command**: `podman exec systemd-vicinae flatpak-spawn --host flatpak --version`

