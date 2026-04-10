#!/usr/bin/env python3
"""Upload repo brand assets into the local Penpot design system."""

from __future__ import annotations

import base64
import json
import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ENDPOINT = "http://localhost:4403/execute"
TMP = Path("/tmp/crispy-tivi-penpot-assets")

ASSETS = [
    "app/flutter/assets/logo.png",
    "app/flutter/assets/logo_path2_nobox_silver.png",
]


def js(value: str) -> str:
    return json.dumps(value)


def post_code(code: str) -> dict:
    result = subprocess.run(
        [
            "curl",
            "-sS",
            "-X",
            "POST",
            ENDPOINT,
            "-H",
            "Content-Type: application/json",
            "--data-binary",
            "@-",
        ],
        input=json.dumps({"code": code}),
        text=True,
        capture_output=True,
        check=True,
    )
    data = json.loads(result.stdout)
    if not data.get("success"):
        raise RuntimeError(data)
    return data["result"]


def make_asset(source: Path) -> Path:
    target = TMP / source.relative_to(ROOT).with_suffix(".png")
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image = image.convert("RGBA")
        image.thumbnail((360, 360), Image.Resampling.LANCZOS)
        image.save(target, "PNG", optimize=True)
    return target


def create_board() -> dict:
    code = """
const C = { surface: '#121212', border: '#404040', brand: '#E50914', text: '#FFFFFF', med: '#B3B3B3' };
function rect(parent, name, x, y, w, h, fill, stroke = C.border) {
  const r = penpot.createRectangle();
  r.name = name; r.x = parent.x + x; r.y = parent.y + y; r.resize(w, h);
  r.fills = fill ? [{ fillColor: fill, fillOpacity: 1 }] : [];
  r.strokes = stroke ? [{ strokeColor: stroke, strokeWidth: 1, strokeOpacity: 1 }] : [];
  r.borderRadius = 2; parent.appendChild(r); return r;
}
function text(parent, name, value, x, y, w, opts = {}) {
  const t = penpot.createText(value);
  t.name = name; t.x = parent.x + x; t.y = parent.y + y; t.resize(w, opts.h || 36); t.growType = 'auto-height';
  t.fontSize = String(opts.size || 14); t.fontWeight = String(opts.weight || 400);
  t.lineHeight = String(opts.lineHeight || 1.22);
  t.fills = [{ fillColor: opts.color || C.text, fillOpacity: 1 }];
  parent.appendChild(t); return t;
}
for (const page of penpot.currentFile.pages) {
  for (const child of [...(page.root.children || [])]) {
    if (child.type === 'board' && child.name === 'ASSET - Brand Assets') child.remove();
  }
}
const b = penpot.createBoard();
b.name = 'ASSET - Brand Assets'; b.x = 3200; b.y = 3900; b.resize(1440, 620);
b.fills = [{ fillColor: '#4A3324', fillOpacity: 1 }];
b.strokes = [{ strokeColor: C.border, strokeWidth: 1, strokeOpacity: 1 }];
b.borderRadius = 2;
b.setSharedPluginData('crispy-tivi', 'artifact', 'editable-design-system');
b.setSharedPluginData('crispy-tivi', 'assetSource', 'app/flutter/assets');
rect(b, 'Top Accent', 0, 0, 1440, 8, C.brand, null);
text(b, 'Title', 'Brand Assets', 48, 42, 900, { size: 34, weight: 700 });
text(b, 'Note', 'Uploaded from checked-in Flutter assets. Use these as brand source artwork in Penpot.', 48, 88, 900, { size: 14, color: C.med, h: 64 });
return { id: b.id, name: b.name };
"""
    return post_code(code)


def import_asset(board_id: str, source: Path, index: int) -> dict:
    rel = source.relative_to(ROOT).as_posix()
    thumb = make_asset(source)
    encoded = base64.b64encode(thumb.read_bytes()).decode("ascii")
    x = 3200 + 72 + index * 420
    y = 3900 + 200
    code = f"""
const board = penpotUtils.findShapeById({js(board_id)});
if (!board) throw new Error('Missing asset board');
const rect = await penpotUtils.importImage({js(encoded)}, 'image/png', {js('Brand Asset - ' + rel)}, {x}, {y}, 280, undefined);
board.appendChild(rect);
rect.setSharedPluginData('crispy-tivi', 'sourcePath', {js(rel)});
const label = penpot.createText({js(rel)});
label.name = {js('Brand Asset Label - ' + rel)};
label.x = {x}; label.y = {y + 310}; label.resize(360, 40); label.growType = 'auto-height';
label.fontSize = '12'; label.fontWeight = '500'; label.fills = [{{ fillColor: '#B3B3B3', fillOpacity: 1 }}];
board.appendChild(label);
return {{ path: {js(rel)}, id: rect.id }};
"""
    return post_code(code)


def main() -> None:
    board = create_board()
    imported = []
    for index, rel in enumerate(ASSETS):
        imported.append(import_asset(board["id"], ROOT / rel, index))
    print(json.dumps({"board": board["name"], "assets": len(imported)}, indent=2))


if __name__ == "__main__":
    main()
