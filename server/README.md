# PixelEscape relay server

Pairs players by a 5-letter join code and forwards game traffic over WebSocket.
Runs in a Debian 12 LXC on the homelab, listening on 127.0.0.1:8090, with
Cloudflare Tunnel or Caddy in front for wss://pixelescape.notnow.no.

Install or update (as root in the container):

    apt update && apt install -y curl && curl -fsSL https://raw.githubusercontent.com/Kentpaulsen/SudoFPS/main/server/install.sh | bash

With Caddy (ports 80 and 443 forwarded to the container):

    curl -fsSL https://raw.githubusercontent.com/Kentpaulsen/SudoFPS/main/server/install.sh | CADDY=1 bash

Status: `systemctl status pixelescape-relay`, logs: `journalctl -u pixelescape-relay -f`,
health: `curl http://127.0.0.1:8090/`. Protocol is documented at the top of relay.py.
