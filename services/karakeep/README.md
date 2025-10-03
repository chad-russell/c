# Karakeep Quadlet Setup

This directory contains Podman Quadlet files for running Karakeep, a self-hosted bookmark manager with AI-powered tagging.

## Architecture

- **Meilisearch v1.10** - Fast search engine for bookmarks
- **Chrome (headless)** - Browser for web scraping and screenshots
- **Karakeep** - Main Next.js web application

## Files

- `karakeep.network` - Dedicated network for Karakeep services
- `karakeep-data.volume` - Meilisearch data persistence
- `karakeep-app-data.volume` - Karakeep application data (SQLite database and assets)
- `karakeep-chrome.container` - Headless Chrome container for web scraping
- `karakeep-meilisearch.container` - Meilisearch search engine
- `karakeep.container` - Main Karakeep application

## Installation

### Prerequisites

Before deploying, you must configure security credentials in the container files.

### 1. Generate Secure Random Strings

Generate two random strings for security:

```bash
openssl rand -base64 36
openssl rand -base64 36
```

### 2. Configure Security Settings

Edit the following files and replace `CHANGE_THIS_TO_A_SECURE_RANDOM_STRING` with the generated values:

**In `karakeep-meilisearch.container`:**
- Set `MEILI_MASTER_KEY` to your first random string

**In `karakeep.container`:**
- Set `NEXTAUTH_SECRET` to your second random string
- Set `MEILI_MASTER_KEY` to the **same value** as in karakeep-meilisearch.container
- Set `NEXTAUTH_URL` to your server's URL (e.g., `http://k4:3000` or `https://karakeep.yourdomain.com`)

### 3. Optional: Enable AI Tagging

Karakeep can automatically tag your bookmarks using AI.

#### Option A: OpenAI (Cloud)

1. Get an API key from [OpenAI](https://platform.openai.com/api-keys)
2. Uncomment and set in `karakeep.container`:
   ```
   Environment=OPENAI_API_KEY=your_api_key_here
   ```

See [OpenAI Costs](https://docs.karakeep.app/openai_costs) for pricing details.

#### Option B: Ollama (Local)

1. Install and run [Ollama](https://ollama.com/) on your host
2. Pull the models:
   ```bash
   ollama pull llama3.1
   ollama pull llava
   ```
3. Uncomment these lines in `karakeep.container`:
   ```
   Environment=OLLAMA_BASE_URL=http://host.containers.internal:11434
   Environment=INFERENCE_TEXT_MODEL=llama3.1
   Environment=INFERENCE_IMAGE_MODEL=llava
   Environment=INFERENCE_CONTEXT_LENGTH=3000
   ```

**Note:** Local inference quality depends on your model choice. Adjust `INFERENCE_CONTEXT_LENGTH` for better tags (higher = better quality but slower).

### 4. Enable User Service Persistence (IMPORTANT)

For rootless Podman services to persist across logins, you must enable linger:

```bash
ssh your-machine 'loginctl enable-linger $USER'
```

Without this, services will stop when you log out!

### 5. Deploy with Your Tool

If you're using the homelab deployment tool:

```bash
# Add karakeep to your machine in machines/machines.yaml
# Then sync:
bun run src/index.ts sync k4
```

Or manually for rootless deployment:

```bash
mkdir -p ~/.config/containers/systemd/
cp services/karakeep/*.{container,network,volume} ~/.config/containers/systemd/
loginctl enable-linger $USER  # IMPORTANT: Enable service persistence
systemctl --user daemon-reload
systemctl --user start karakeep.service
systemctl --user enable karakeep.service
```

## Accessing Karakeep

Once running, access Karakeep at: **http://localhost:3000** (or your configured NEXTAUTH_URL)

On first visit, you'll be prompted to create an admin account.

## Browser Extensions & Mobile Apps

Karakeep provides browser extensions and mobile apps for quick bookmark saving:

- [Chrome Extension](https://chromewebstore.google.com/detail/karakeep/jdohnbnlnhcnodlhldmfpknnkjncgmhf)
- [Firefox Extension](https://addons.mozilla.org/en-US/firefox/addon/karakeep/)
- iOS App (search "Karakeep" in App Store)
- Android App (available via GitHub releases)

See the [Quick Sharing Extensions](https://docs.karakeep.app/quick_sharing) docs for setup.

## Managing Services

Check status:
```bash
systemctl --user status karakeep.service
systemctl --user status karakeep-meilisearch.service
systemctl --user status karakeep-chrome.service
```

View logs:
```bash
journalctl --user -u karakeep.service -f
journalctl --user -u karakeep-meilisearch.service -f
```

Stop services:
```bash
systemctl --user stop karakeep.service
```

## Configuration Options

Edit `karakeep.container` to customize:

### Required Settings
- **NEXTAUTH_SECRET**: Random secret for session encryption
- **NEXTAUTH_URL**: Your server URL (change from `http://localhost:3000`)
- **MEILI_MASTER_KEY**: Secure key for Meilisearch (must match in both files)

### Optional Settings
- **MAX_ASSET_SIZE_MB**: Maximum size for archived assets (default: 50)
- **INFERENCE_LANG**: Language for AI inference (default: english)
- **Port**: Change `PublishPort=3000:3000` if you need a different host port

## Data Persistence

All data is stored in named volumes:
- `karakeep-data` - Meilisearch index data
- `karakeep-app-data` - Karakeep SQLite database and uploaded assets

View volumes:
```bash
podman volume ls | grep karakeep
```

Inspect volumes:
```bash
podman volume inspect karakeep-data
podman volume inspect karakeep-app-data
```

## Updating Karakeep

To update to the latest version:

```bash
# If using the release tag
podman pull ghcr.io/karakeep-app/karakeep:release
systemctl --user restart karakeep.service
```

Or pin to a specific version by changing the image tag in `karakeep.container`:
```
Image=ghcr.io/karakeep-app/karakeep:0.27.0
```

For Meilisearch upgrades, see the [Karakeep troubleshooting docs](https://docs.karakeep.app/troubleshooting).

## Troubleshooting

### Service won't start

Check if the images pulled successfully:
```bash
podman pull ghcr.io/karakeep-app/karakeep:release
podman pull docker.io/getmeili/meilisearch:v1.10
podman pull gcr.io/zenika-hub/alpine-chrome:123
```

### Can't log in / Session issues

Make sure:
1. `NEXTAUTH_SECRET` is set to a secure random string
2. `NEXTAUTH_URL` matches the URL you're accessing in your browser

### Web scraping not working

Check if Chrome container is running:
```bash
systemctl --user status karakeep-chrome.service
podman logs karakeep-chrome
```

### Search not working

Verify Meilisearch is running and the keys match:
```bash
systemctl --user status karakeep-meilisearch.service
# Check that MEILI_MASTER_KEY is the same in both container files
```

### Container logs

View container logs directly:
```bash
podman logs karakeep
podman logs karakeep-meilisearch
podman logs karakeep-chrome
```

## References

- [Karakeep Documentation](https://docs.karakeep.app/)
- [Karakeep GitHub](https://github.com/karakeep-app/karakeep)
- [Docker Compose Installation Guide](https://docs.karakeep.app/installation/docker)
- [Podman Quadlet Documentation](../../docs/quadlet.md)


