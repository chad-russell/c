Let's break down the requirements and design a solution that aims to meet them.
Core Goals:
Unified Access: https://homeassistant.crussell.io works seamlessly whether on the LAN or external.
Offline LAN Access: Critically, it must work on the LAN even if the public internet connection is down.
Security: HTTPS is mandatory.
No Firewall Ports Opened: Strong preference to avoid exposing your home IP or opening inbound ports on your firewall.
User Simplicity: No extra apps (like Tailscale) required on your wife's phone.
Understanding the Challenges:
SSL without Internet: The biggest hurdle for "offline LAN access" with HTTPS is SSL certificate validation. Standard Let's Encrypt certificates require internet access for issuance and renewal. If the internet is down, a browser or app might not trust a certificate it can't verify or if the locally served certificate is self-signed without a trusted root.
Split DNS: You need homeassistant.crussell.io to resolve to a public IP when external, and a private IP when internal.
Proposed Solution Strategy:
We'll combine your existing public VPS setup (for external access without opening home ports) with a robust internal setup using AdGuard Home and Traefik on your gateway. The key for offline SSL will be to have your internal Traefik also manage a Let's Encrypt certificate for homeassistant.crussell.io, which it can serve from its cache when the internet is down.
Detailed Plan:
External Access (Handled by your Public VPS - Largely Unchanged):
Public DNS: homeassistant.crussell.io will continue to have an A/AAAA record pointing to your public VPS IP address.
VPS Reverse Proxy (Caddy/Traefik): Your existing setup on the VPS will terminate SSL for external requests using a Let's Encrypt certificate and proxy traffic to your internal Home Assistant server (likely via Tailscale or a WireGuard tunnel from the VPS to your home network). This keeps your home ports closed.
Internal DNS (AdGuard Home on your Gateway - 192.168.68.212):
DNS Rewrite: AdGuard Home will be configured to resolve homeassistant.crussell.io to the IP address of your gateway (192.168.68.212), where Traefik is running.
DHCP Configuration: Your LAN's DHCP server (usually your router) must assign 192.168.68.212 as the primary DNS server for all LAN clients (including your wife's phone when connected to Wi-Fi).
Internal Reverse Proxy & SSL (Traefik on your Gateway - 192.168.68.212):
Listening: Traefik will listen on port 443 for HTTPS traffic.
Routing: It will route requests for homeassistant.crussell.io to your internal Home Assistant instance (192.168.68.51:8123).
SSL Certificate Management (Key Part for Offline):
Traefik on your gateway will be configured to obtain its own Let's Encrypt certificate for homeassistant.crussell.io using the DNS-01 challenge with Route53 (just like your public VPS likely does).
This means your internal Traefik will also need AWS credentials with permissions to modify your Route53 zone.
When the internet is UP, Traefik will fetch and renew this certificate, storing it in its acme.json file.
When the internet is DOWN, Traefik will serve this locally cached, valid Let's Encrypt certificate. As long as the certificate hasn't expired (they are typically valid for 90 days), browsers and apps on the LAN will trust it because it's a standard, publicly trusted certificate.
Why this approach meets your needs:
Unified Access: The same URL works. DNS resolution directs the client to the right place (VPS externally, Gateway internally).
Offline LAN Access: Because internal Traefik has its own valid Let's Encrypt certificate (cached), it can serve homeassistant.crussell.io over HTTPS even if the internet is out. The client device already trusts Let's Encrypt CAs. The main limitation is if an internet outage lasts longer than the certificate's validity + renewal window.
HTTPS: Ensured both externally and internally.
No Firewall Ports Opened: External access is via the VPS.
User Simplicity: No changes for your wife's phone beyond connecting to the home Wi-Fi (which should automatically give it the correct internal DNS server via DHCP).