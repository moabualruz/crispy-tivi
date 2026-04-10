#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOKENS="${DESIGN_TOKENS_FILE:-$ROOT_DIR/design/tokens/crispy.tokens.json}"

python3 - "$TOKENS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(f"Missing token file: {path}")

data = json.loads(path.read_text())
required = [
    ("color", "background", "immersive"),
    ("color", "background", "surface"),
    ("color", "brand", "red"),
    ("color", "overlay", "osdPanel"),
    ("color", "overlay", "scrim60"),
    ("color", "seek", "segmentHighlight"),
    ("spacing", "md"),
    ("radius", "tv"),
    ("typography", "micro"),
    ("elevation", "level2", "blur"),
    ("motion", "duration", "normal"),
    ("motion", "duration", "skeletonPulse"),
    ("motion", "duration", "heroAdvanceInterval"),
]

for key_path in required:
    node = data
    for key in key_path:
        if key not in node:
            raise SystemExit(f"Missing token: {'.'.join(key_path)}")
        node = node[key]
    if "$value" not in node:
        raise SystemExit(f"Token has no $value: {'.'.join(key_path)}")

print(f"Token check passed: {path}")
PY

if ! grep -R "class CrispySpacing" "$ROOT_DIR/app/flutter/lib/core/theme" >/dev/null; then
  echo "Missing Flutter spacing tokens" >&2
  exit 1
fi

if ! grep -R "class CrispyRadius" "$ROOT_DIR/app/flutter/lib/core/theme" >/dev/null; then
  echo "Missing Flutter radius tokens" >&2
  exit 1
fi
