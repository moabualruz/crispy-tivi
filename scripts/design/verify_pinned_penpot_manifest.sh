#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
payload="$(jq -Rs '{code:.}' "$repo_root/design/penpot/publish_app_overhaul_design_system.js")"

curl -sS \
  -X POST \
  http://localhost:4403/execute \
  -H 'Content-Type: application/json' \
  --data-binary "$payload"
