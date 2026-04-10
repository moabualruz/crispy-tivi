# Penpot Setup

CrispyTivi uses Penpot as the design source for collaborative product design
and Widgetbook as the implementation catalog for real Flutter widgets.

## Self-Host On Arch/CachyOS

Do not install or run Penpot from this project directory. Treat Penpot as a
normal user-level service and keep compose files, volumes, secrets, and
database state outside the repo.

Install the normal Arch packages:

```bash
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out/in after changing docker group membership.

Create a user service directory outside the repo:

```bash
mkdir -p ~/srv/penpot
cd ~/srv/penpot
curl -fsSL \
  https://raw.githubusercontent.com/penpot/penpot/main/docker/images/docker-compose.yaml \
  -o docker-compose.yaml
docker compose up -d
```

Production instances should run behind HTTPS and set a stable
`PENPOT_PUBLIC_URI`. For local-only experiments, use the default compose setup
from `~/srv/penpot`.

Useful service commands:

```bash
cd ~/srv/penpot
docker compose ps
docker compose logs -f
docker compose pull
docker compose up -d
docker compose down
```

## MCP

The Penpot MCP server is installed globally, not per project:

```bash
npm install -g @penpot/mcp@beta
penpot-mcp
```

The global Codex profile is configured to connect to:

```text
http://localhost:4401/mcp
```

When `penpot-mcp` is running it also serves:

- Penpot MCP plugin manifest/UI: `http://localhost:4400/manifest.json`
- Plugin websocket bridge: `ws://localhost:4402`
- MCP HTTP endpoint: `http://localhost:4401/mcp`
- Legacy SSE endpoint: `http://localhost:4401/sse`

This workspace also uses the local REPL bridge at `http://localhost:4403/execute`
for publishing editable boards and reading back verification state. If that
endpoint is down, run Penpot + MCP first, connect the Penpot plugin, then rerun
the publisher/read-back commands.

Open a Penpot file, load the plugin manifest from `http://localhost:4400`,
open the plugin UI, and click "Connect to MCP server". Agents should then read
Penpot components/tokens through MCP first, then update Flutter tokens and
Widgetbook use cases.
