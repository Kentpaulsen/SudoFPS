#!/usr/bin/env bash
# PixelEscape relay installer for Debian 12 or 13 (Proxmox LXC).
# Run as root:
#   curl -fsSL https://raw.githubusercontent.com/Kentpaulsen/SudoFPS/main/server/install.sh | bash
# Optional: install Caddy as HTTPS front (needs ports 80+443 forwarded to this container):
#   curl -fsSL https://raw.githubusercontent.com/Kentpaulsen/SudoFPS/main/server/install.sh | DOMAIN=pixelescape.notnow.no CADDY=1 bash
# Re-running the script updates the relay to the latest version.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/Kentpaulsen/SudoFPS/${REF:-main}/server"
DOMAIN="${DOMAIN:-pixelescape.notnow.no}"
CADDY="${CADDY:-0}"
# Listen address: keep what an earlier install used, else localhost. Use RELAY_HOST=0.0.0.0 when a
# reverse proxy on another machine (e.g. Nginx Proxy Manager) forwards to this container.
OLD_HOST=$(sed -n 's/^Environment=RELAY_HOST=//p' /etc/systemd/system/pixelescape-relay.service 2>/dev/null || true)
RELAY_HOST="${RELAY_HOST:-${OLD_HOST:-127.0.0.1}}"

if [ "$(id -u)" -ne 0 ]; then echo "Run as root."; exit 1; fi

echo "== Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 python3-websockets curl ca-certificates >/dev/null

echo "== Creating user and files"
id pixelescape >/dev/null 2>&1 || useradd --system --home /opt/pixelescape --shell /usr/sbin/nologin pixelescape
mkdir -p /opt/pixelescape
curl -fsSL "$REPO_RAW/relay.py" -o /opt/pixelescape/relay.py
chown -R pixelescape:pixelescape /opt/pixelescape

cat >/etc/systemd/system/pixelescape-relay.service <<EOF
[Unit]
Description=PixelEscape relay server
After=network-online.target
Wants=network-online.target

[Service]
User=pixelescape
ExecStart=/usr/bin/python3 /opt/pixelescape/relay.py
Environment=RELAY_HOST=$RELAY_HOST
Environment=RELAY_PORT=8090
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now pixelescape-relay >/dev/null
systemctl restart pixelescape-relay

if [ "$CADDY" = "1" ]; then
  echo "== Installing Caddy for $DOMAIN"
  apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https gnupg >/dev/null
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' >/etc/apt/sources.list.d/caddy-stable.list
  apt-get update -qq
  apt-get install -y -qq caddy >/dev/null
  cat >/etc/caddy/Caddyfile <<EOF
$DOMAIN {
	reverse_proxy 127.0.0.1:8090
}
EOF
  systemctl reload caddy || systemctl restart caddy
fi

sleep 1
echo "== Health check"
if curl -fsS http://127.0.0.1:8090/; then
  echo "Relay is running on $RELAY_HOST:8090."
else
  echo "Relay did not answer. Check: journalctl -u pixelescape-relay -n 50"
  exit 1
fi
