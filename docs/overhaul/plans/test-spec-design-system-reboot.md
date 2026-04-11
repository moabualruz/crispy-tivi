# Test Spec: CrispyTivi Design-System Reboot

## Scope

Verification for design-system governance, Widgetbook coverage, Penpot rebuild,
and documentation.

## Static Checks

1. Dart format:

```bash
dart format app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart
```

Expected: exits 0.

2. Dart analyze:

```bash
dart analyze app/flutter/lib/widgetbook.dart app/flutter/lib/widgetbook/*.dart
```

Expected: no issues.

3. Design tokens:

```bash
scripts/design/check_design_tokens.sh
```

Expected: token check passed.

4. Widgetbook build:

```bash
scripts/design/build_widgetbook.sh
```

Expected: builds `app/flutter/build/widgetbook`.
Known acceptable warnings:

- Flutter web wasm dry-run warning from `flutter_rust_bridge`.
- Icon font tree-shaking warning.

## Penpot Read-Back

Run through local REPL endpoint:

```bash
curl -sS -X POST http://localhost:4403/execute \
  -H 'Content-Type: application/json' \
  --data-binary @-
```

Payload:

```json
{
  "code": "const tokenSet = penpot.library.local.tokens.sets.find(s => s.name === 'CrispyTivi'); const boards=[]; let assetImages=0; for (const p of penpot.currentFile.pages) { for (const s of (p.root.children||[])) { if (s.type==='board' && s.getSharedPluginData?.('crispy-tivi','artifact')==='editable-design-system') { const children=s.children||[]; const visibleChildren=children.filter(c => (c.x ?? 0) >= s.x - 10 && (c.y ?? 0) >= s.y - 10 && (c.x ?? 0) <= s.x + s.width + 20 && (c.y ?? 0) <= s.y + s.height + 20).length; if (s.name==='ASSET - Brand Assets') for (const c of children) if ((c.type||'').toLowerCase().includes('image') || c.name?.startsWith('Brand Asset - ')) assetImages++; boards.push({name:s.name,x:s.x,y:s.y,children:children.length,visibleChildren,widgetbook:s.getSharedPluginData?.('crispy-tivi','widgetbook')||''}); } } } return {page:penpot.currentPage?.name, tokenSet:{active:tokenSet?.active,count:tokenSet?.tokens?.length}, activeBoards:boards.length, duplicateActive:boards.length - new Set(boards.map(b=>b.name)).size, uniquePositions:new Set(boards.map(b=>`${b.x},${b.y}`)).size, boardsWithWidgetbook:boards.filter(b=>b.widgetbook).length, assetImages, hiddenChildBoards:boards.filter(b=>b.children>0 && b.visibleChildren===0).map(b=>b.name), boards};"
}
```

Expected:

- page is active design-system page.
- tokenSet.active is true.
- tokenSet.count >= 22.
- activeBoards >= 20.
- duplicateActive is 0.
- active board positions are unique.
- every active board has at least one visible child inside its own
  page-absolute bounds.
- hiddenChildBoards is empty.
- assetImages is at least 2.
- every Widgetbook `designLink` target names an existing Penpot board.

## Coverage Matrix Check

File: `design/docs/widgetbook-coverage.md`

Expected:

- Summary section exists.
- Total scanned UI classes > 0.
- No `unclassified` decision appears.
- Deferred rows include reasons.

## Acceptance Gate

Do not claim completion unless all commands above are run and outputs are read.
