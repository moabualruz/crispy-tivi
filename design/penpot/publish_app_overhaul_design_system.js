/*
 * Publish CrispyTivi vNext app-overhaul foundations to Penpot.
 * Execute through local Penpot MCP REPL:
 *   jq -Rs '{code:.}' design/penpot/publish_app_overhaul_design_system.js \
 *     | curl -sS -X POST http://localhost:4403/execute \
 *         -H 'Content-Type: application/json' --data-binary @-
 */
const V = {
  voidBlack: '#05070A',
  panel: '#0C1118',
  raised: '#121A24',
  glass: '#CC121A24',
  focus: '#FFF1A8',
  brand: '#E50914',
  brandSoft: '#FF4D5A',
  actionBlue: '#3B82F6',
  success: '#22C55E',
  warning: '#F59E0B',
  danger: '#EF4444',
  textPrimary: '#F8FAFC',
  textSecondary: '#B6C2D1',
  textMuted: '#64748B',
};

function rect(parent, name, x, y, w, h, fill, stroke = null, radius = 6) {
  const r = penpot.createRectangle();
  r.name = name;
  r.x = parent.x + x;
  r.y = parent.y + y;
  r.resize(w, h);
  r.fills = fill ? [{ fillColor: fill, fillOpacity: 1 }] : [];
  r.strokes = stroke ? [{ strokeColor: stroke, strokeWidth: 1, strokeOpacity: 1 }] : [];
  r.borderRadius = radius;
  parent.appendChild(r);
  return r;
}

function text(parent, name, value, x, y, w, opts = {}) {
  const t = penpot.createText(value);
  t.name = name;
  t.x = parent.x + x;
  t.y = parent.y + y;
  t.resize(w, opts.h || 42);
  t.growType = 'auto-height';
  t.fontSize = String(opts.size || 16);
  t.fontWeight = String(opts.weight || 500);
  t.fills = [{ fillColor: opts.color || V.textPrimary, fillOpacity: 1 }];
  parent.appendChild(t);
  return t;
}

function board(name, x, y, w = 1440, h = 920) {
  const b = penpot.createBoard();
  b.name = name;
  b.x = x;
  b.y = y;
  b.resize(w, h);
  b.fills = [{ fillColor: V.voidBlack, fillOpacity: 1 }];
  b.strokes = [{ strokeColor: V.focus, strokeWidth: 1, strokeOpacity: 0.5 }];
  b.borderRadius = 6;
  rect(b, 'Top Accent', 0, 0, w, 10, V.focus, null, 0);
  b.setSharedPluginData('crispy-tivi', 'artifact', 'app-overhaul-design-system');
  b.setSharedPluginData('crispy-tivi', 'source', 'CrispyOverhaul* Flutter tokens');
  return b;
}

function removeOld() {
  let removed = 0;
  for (const p of penpot.currentFile.pages) {
    for (const child of [...(p.root.children || [])]) {
      if (child.getSharedPluginData?.('crispy-tivi', 'artifact') === 'app-overhaul-design-system') {
        child.remove();
        removed++;
      }
    }
  }
  return removed;
}

function upsertToken(set, type, name, value) {
  for (const token of [...(set.tokens || [])]) if (token.name === name) token.remove();
  return set.addToken({ type, name, value });
}

function populateTokens() {
  const catalog = penpot.library.local.tokens;
  let set = (catalog.sets || []).find((candidate) => candidate.name === 'CrispyTivi vNext');
  if (!set) set = catalog.addSet({ name: 'CrispyTivi vNext' });
  if (!set.active) set.toggleActive();
  [
    ['color.surface.void', V.voidBlack],
    ['color.surface.panel', V.panel],
    ['color.surface.raised', V.raised],
    ['color.surface.glass', V.glass],
    ['color.accent.focus', V.focus],
    ['color.accent.brand', V.brand],
    ['color.accent.brandSoft', V.brandSoft],
    ['color.accent.actionBlue', V.actionBlue],
    ['color.semantic.success', V.success],
    ['color.semantic.warning', V.warning],
    ['color.semantic.danger', V.danger],
    ['color.text.primary', V.textPrimary],
    ['color.text.secondary', V.textSecondary],
    ['color.text.muted', V.textMuted],
  ].forEach(([name, value]) => upsertToken(set, 'color', name, value));
  [
    ['spacing.hairline', '2px'],
    ['spacing.compact', '6px'],
    ['spacing.small', '10px'],
    ['spacing.medium', '18px'],
    ['spacing.large', '28px'],
    ['spacing.section', '44px'],
    ['spacing.screen', '64px'],
  ].forEach(([name, value]) => upsertToken(set, 'spacing', name, value));
  [
    ['radius.sharp', '2px'],
    ['radius.card', '6px'],
    ['radius.sheet', '10px'],
    ['radius.pill', '999px'],
  ].forEach(([name, value]) => upsertToken(set, 'borderRadius', name, value));
  return { set: set.name, count: set.tokens.length };
}

function foundations() {
  const b = board('VNEXT - Foundations', 0, 0);
  text(b, 'Title', 'CrispyTivi vNext Foundations', 64, 54, 900, { size: 38, weight: 800 });
  text(b, 'Subtitle', 'Calmer cinematic surfaces, room-scale focus, and staged app migration tokens.', 64, 110, 980, { size: 18, color: V.textSecondary });
  const colors = Object.entries(V);
  colors.forEach(([name, color], i) => {
    const x = 64 + (i % 7) * 180;
    const y = 210 + Math.floor(i / 7) * 160;
    rect(b, `Color / ${name}`, x, y, 140, 78, color, V.textMuted, 6);
    text(b, `Color Label / ${name}`, name, x, y + 92, 160, { size: 12, weight: 700 });
    text(b, `Color Value / ${name}`, color, x, y + 116, 160, { size: 11, color: V.textSecondary });
  });
  return b;
}

function shell() {
  const b = board('VNEXT - App Shell Direction', 1600, 0);
  text(b, 'Title', 'App Shell Direction', 64, 54, 900, { size: 38, weight: 800 });
  rect(b, 'Shell Frame', 64, 170, 1180, 620, V.panel, V.textMuted, 10);
  rect(b, 'Navigation Rail', 96, 210, 108, 540, V.raised, null, 10);
  ['Home', 'Live', 'Guide', 'Movies', 'Settings'].forEach((label, i) => {
    const y = 250 + i * 86;
    rect(b, `Nav Target / ${label}`, 118, y, 64, 54, i === 1 ? V.focus : V.panel, null, 999);
    text(b, `Nav Label / ${label}`, label, 230, y + 12, 180, { size: 22, weight: i === 1 ? 800 : 500, color: i === 1 ? V.focus : V.textSecondary });
  });
  rect(b, 'Hero Surface', 450, 230, 680, 250, V.panelRaised, V.focus, 10);
  text(b, 'Hero Title', 'Focused content should read from across the room', 490, 290, 560, { size: 34, weight: 800 });
  text(b, 'Hero Body', 'Large type, visible focus rings, calmer elevation, and fewer black-on-black layers.', 490, 370, 520, { size: 17, color: V.textSecondary });
  return b;
}

function components() {
  const b = board('VNEXT - Component Direction', 3200, 0);
  text(b, 'Title', 'Component Direction', 64, 54, 900, { size: 38, weight: 800 });
  ['Default', 'Focused', 'Disabled'].forEach((label, i) => {
    const x = 96 + i * 260;
    rect(b, `Button / ${label}`, x, 220, 210, 58, i === 1 ? V.focus : V.brand, i === 1 ? V.focus : null, 6);
    text(b, `Button Label / ${label}`, label, x + 34, 238, 150, { size: 18, weight: 800, color: i === 1 ? V.voidBlack : V.textPrimary });
  });
  ['Panel', 'Raised panel', 'Glass panel'].forEach((label, i) => {
    const x = 96 + i * 330;
    rect(b, `Surface / ${label}`, x, 390, 280, 210, [V.panel, V.raised, V.glass][i], V.textMuted, i === 0 ? 6 : 10);
    text(b, `Surface Label / ${label}`, label, x + 28, 430, 220, { size: 22, weight: 800 });
    text(b, `Surface Body / ${label}`, 'Room-scale contrast with explicit focus treatment.', x + 28, 482, 210, { size: 14, color: V.textSecondary });
  });
  return b;
}

function publish() {
  const removed = removeOld();
  const tokenResult = populateTokens();
  const boards = [foundations(), shell(), components()];
  return { status: 'published-app-overhaul-design-system', removed, tokenSet: tokenResult, boards: boards.map((b) => b.name) };
}

return publish();
