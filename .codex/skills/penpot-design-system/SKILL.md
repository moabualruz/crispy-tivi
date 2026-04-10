---
name: penpot-design-system
description: Use when creating, resetting, publishing, or verifying CrispyTivi Penpot design-system artifacts through local Penpot MCP/REPL, including tokens, components, variants, assets, and editable screen patterns.
---

# Penpot Design System Skill

Use this with `$design-system` when Penpot is part of the work.

## Sources

- Flutter tokens are authoritative:
  - `app/flutter/lib/core/theme/`
  - `design/tokens/crispy.tokens.json`
- Penpot mirrors Flutter token names.
- Use official Penpot concepts: token sets, libraries/components, variants,
  assets, comments/annotations, pages/boards.

## Local MCP Access

Preferred local endpoint in this workspace:

```bash
curl -sS -X POST http://localhost:4403/execute \
  -H 'Content-Type: application/json' \
  --data-binary @-
```

Payload shape:

```json
{"code":"return { ok: true, page: penpot.currentPage?.name };"}
```

Do not rely on native page switching from REPL tasks. This local Penpot runtime
has shown unreliable cross-page deletion/reparenting. Build on one active page.

## Required Workflow

1. Reset active Penpot page before rebuild.
2. Verify active page board count is zero.
3. Populate Penpot token set `CrispyTivi` using `penpot.library.local.tokens`.
4. Upload real repo assets before drawing placeholder equivalents.
5. Build editable boards from shapes:
   - `FOUNDATION - ...`
   - `COMPONENT - ...`
   - `PATTERN - ...`
   - `SCREEN - ...`
   - `FEATURE - ...`
   - `ASSET - ...`
6. Components must include state/variant grids, not only a single specimen.
7. Use Penpot components/variant containers when the API is reliable; if this
   local API blocks that, document the blocker and use clearly labeled editable
   variant boards as fallback.
8. Attach shared plugin data:
   - `artifact=editable-design-system`
   - `source=<Flutter owner or token source>`
   - `widgetbook=<use case path when known>`
9. Read back:
   - active token set name/count
   - board names/count
   - asset image count
   - duplicate active board names

## Local Penpot API Caveats

- Penpot shape coordinates are page-absolute even after appending a shape to a
  board. When drawing inside a board at `(board.x, board.y)`, add the board
  origin to every child shape position (`child.x = board.x + localX`,
  `child.y = board.y + localY`).
- Do not validate board visibility by comparing child coordinates to
  `0..board.width` / `0..board.height`; validate against page-absolute bounds:
  `board.x..board.x + board.width` and `board.y..board.y + board.height`.
- Before rebuilding the active design-system page, remove **all** active-page
  root children, not only known/prefixed boards. Old orphan shapes can sit over
  the new boards and make the UI look broken even when board-count read-back
  passes.
- Add visible overview affordances to every board: distinct board fill,
  large title, and high-contrast header/accent. A board with valid children can
  still fail visually if it reads as a black rectangle at overview zoom.
- Asset imports also need page-absolute placement. If importing into
  `ASSET - Brand Assets`, calculate image coordinates from that board's
  absolute origin before appending the image to the board.
- Always inspect the actual target file URL in browser after publish, not only
  a newly created/sandbox file. If access is blocked, grant the test profile
  explicit team/file access or use the owner profile with an installed bridge.

## Quality Bar

- Editable shapes first; screenshots are reference-only.
- Components need visible states: default, focused, selected, disabled/loading
  where applicable.
- Tokens must be real Penpot tokens, not only drawn swatches.
- Do not call an inventory board a design system.
- Do not publish to the wrong page. Active page must be the design-system page
  before writing. Verify after publishing.
- Do not declare completion from data read-back alone. Pair read-back with a
  browser screenshot or snapshot of the actual Penpot file and verify boards
  are visible, not hidden under old content or collapsed into the foundation
  area.

## Verification Snippet

```js
const tokenSet = penpot.library.local.tokens.sets.find(s => s.name === 'CrispyTivi');
const boards = [];
for (const p of penpot.currentFile.pages) {
  for (const s of (p.root.children || [])) {
    if (s.type === 'board' &&
        s.getSharedPluginData?.('crispy-tivi','artifact') === 'editable-design-system') {
      boards.push({ page: p.name, name: s.name, children: s.children?.length || 0 });
    }
  }
}
return { tokenSet: { active: tokenSet?.active, count: tokenSet?.tokens?.length }, boards };
```

## Visibility Read-Back Snippet

Use this after publishing to catch the coordinate/visibility bug:

```js
const boards = [];
for (const p of penpot.currentFile.pages) {
  for (const s of (p.root.children || [])) {
    if (s.type === 'board' &&
        s.getSharedPluginData?.('crispy-tivi','artifact') === 'editable-design-system') {
      const children = s.children || [];
      const visibleChildren = children.filter((c) =>
        (c.x ?? 0) >= s.x - 10 &&
        (c.y ?? 0) >= s.y - 10 &&
        (c.x ?? 0) <= s.x + s.width + 20 &&
        (c.y ?? 0) <= s.y + s.height + 20
      ).length;
      boards.push({ name: s.name, x: s.x, y: s.y, children: children.length, visibleChildren });
    }
  }
}
return {
  activeBoards: boards.length,
  duplicateActive: boards.length - new Set(boards.map((b) => b.name)).size,
  uniquePositions: new Set(boards.map((b) => `${b.x},${b.y}`)).size,
  hiddenChildBoards: boards
    .filter((b) => b.children > 0 && b.visibleChildren === 0)
    .map((b) => b.name),
  boards,
};
```
