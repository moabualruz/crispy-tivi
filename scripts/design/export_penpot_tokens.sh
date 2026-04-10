#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${PENPOT_TOKENS_OUT:-$ROOT_DIR/design/tokens/penpot.tokens.json}"

mkdir -p "$(dirname "$OUT")"

if [[ -n "${PENPOT_TOKENS_FILE:-}" ]]; then
  cp "$PENPOT_TOKENS_FILE" "$OUT"
elif [[ -n "${PENPOT_EXPORT_CMD:-}" ]]; then
  bash -lc "$PENPOT_EXPORT_CMD" > "$OUT"
else
  cat >&2 <<'EOF'
No Penpot token export source configured.

Set one of:
  PENPOT_TOKENS_FILE=/path/to/export.json
  PENPOT_EXPORT_CMD='your-cli-command-that-prints-token-json'

For agent workflows, prefer running Penpot MCP separately:
  npx @penpot/mcp@beta
EOF
  exit 2
fi

python3 -m json.tool "$OUT" >/tmp/crispy_penpot_tokens_validated.json
mv /tmp/crispy_penpot_tokens_validated.json "$OUT"
printf 'Penpot tokens exported: %s\n' "$OUT"
