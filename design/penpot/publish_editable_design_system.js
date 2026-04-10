/*
 * Replace inventory/noise boards with an editable Penpot design system.
 *
 * Execute through local Penpot MCP REPL:
 *   jq -Rs '{code:.}' design/penpot/publish_editable_design_system.js \
 *     | curl -sS -X POST http://localhost:4403/execute \
 *         -H 'Content-Type: application/json' --data-binary @-
 */

const C = {
  bg: '#000000',
  surface: '#121212',
  raised: '#1E1E1E',
  high: '#FFFFFF',
  med: '#B3B3B3',
  dis: '#404040',
  border: '#404040',
  brand: '#E50914',
  live: '#FF5252',
  recording: '#D32F2F',
  success: '#4CAF50',
  successToast: '#2E7D32',
  warning: '#FF9800',
  warningToast: '#E65100',
  error: '#F44336',
  amber: '#FFC107',
  blue: '#1E88E5',
  green: '#43A047',
  yellow: '#FDD835',
  focus: '#FFFFFF',
  glassTint: '#CC1A1A1A',
  vignetteStart: '#80000000',
  vignetteEnd: '#E6000000',
  scrimLight: '#40000000',
  scrimMid: '#80000000',
  scrimHeavy: '#BF000000',
  scrimFull: '#E6000000',
  scrim60: '#99000000',
  scrim80: '#CC000000',
  osdPanel: '#B3000000',
  osdPanelDense: '#D91A1A1A',
  segmentHighlight: '#80FFB300',
  genreSports: '#1E4CAF50',
  genreNews: '#1E2196F3',
  genreMovie: '#1E9C27B0',
  genreKids: '#1EFF9800',
  genreMusic: '#1EE91E63',
  genreDocumentary: '#1E009688',
};

const S = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48 };

function removeOldBoards() {
  const prefixes = [
    'DOCUMENTATION -',
    'TOKENS -',
    'CATALOG -',
    'PAGE -',
    'DETAIL -',
    'VISUAL -',
    'STALE -',
    'EVIDENCE -',
    'GAP-LIST -',
    'SECTION -',
    'FOUNDATION -',
    'COMPONENT -',
    'PATTERN -',
    'SCREEN -',
    'FEATURE -',
    'ASSET -',
    'ARCHIVE DUPLICATE -',
  ];
  let removed = 0;
  const currentRoot = penpot.currentPage?.root;
  if (currentRoot) {
    for (const child of [...(currentRoot.children || [])]) {
      child.remove();
      removed++;
    }
  }
  for (const page of penpot.currentFile.pages) {
    if (page === penpot.currentPage) continue;
    for (const child of [...(page.root.children || [])]) {
      const isDesignArtifact =
        child.getSharedPluginData?.('crispy-tivi', 'artifact') === 'editable-design-system';
      const isLegacyBoard =
        child.type === 'board' && prefixes.some((prefix) => child.name.startsWith(prefix));
      if (isDesignArtifact || isLegacyBoard) {
        child.remove();
        removed++;
      }
    }
  }
  return removed;
}

function upsertToken(set, type, name, value) {
  for (const token of [...(set.tokens || [])]) {
    if (token.name === name) token.remove();
  }
  return set.addToken({ type, name, value });
}

function populateTokens() {
  const catalog = penpot.library.local.tokens;
  let set = (catalog.sets || []).find((candidate) => candidate.name === 'CrispyTivi');
  if (!set) set = catalog.addSet({ name: 'CrispyTivi' });
  if (!set.active) set.toggleActive();

  [
    ['color.background.immersive', C.bg],
    ['color.background.surface', C.surface],
    ['color.background.raised', C.raised],
    ['color.brand.red', C.brand],
    ['color.status.success', C.success],
    ['color.status.recording', C.recording],
    ['color.status.successToast', C.successToast],
    ['color.status.warning', C.warning],
    ['color.status.warningToast', C.warningToast],
    ['color.status.error', C.error],
    ['color.status.live', C.live],
    ['color.text.high', C.high],
    ['color.text.medium', C.med],
    ['color.text.disabled', C.dis],
    ['color.focus.border', C.focus],
    ['color.overlay.glassTint', C.glassTint],
    ['color.overlay.vignetteStart', C.vignetteStart],
    ['color.overlay.vignetteEnd', C.vignetteEnd],
    ['color.overlay.scrimLight', C.scrimLight],
    ['color.overlay.scrimMid', C.scrimMid],
    ['color.overlay.scrimHeavy', C.scrimHeavy],
    ['color.overlay.scrimFull', C.scrimFull],
    ['color.overlay.scrim60', C.scrim60],
    ['color.overlay.scrim80', C.scrim80],
    ['color.overlay.osdPanel', C.osdPanel],
    ['color.overlay.osdPanelDense', C.osdPanelDense],
    ['color.seek.segmentHighlight', C.segmentHighlight],
    ['color.highlight.amber', C.amber],
    ['color.genre.sports', C.genreSports],
    ['color.genre.news', C.genreNews],
    ['color.genre.movie', C.genreMovie],
    ['color.genre.kids', C.genreKids],
    ['color.genre.music', C.genreMusic],
    ['color.genre.documentary', C.genreDocumentary],
  ].forEach(([name, value]) => upsertToken(set, 'color', name, value));

  [
    ['spacing.xxs', '2px'],
    ['spacing.xs', '4px'],
    ['spacing.sm', '8px'],
    ['spacing.md', '16px'],
    ['spacing.lg', '24px'],
    ['spacing.xl', '32px'],
    ['spacing.xxl', '48px'],
  ].forEach(([name, value]) => upsertToken(set, 'spacing', name, value));

  [
    ['radius.none', '0px'],
    ['radius.tvSm', '1px'],
    ['radius.tv', '2px'],
    ['radius.progressBar', '1.5px'],
  ].forEach(([name, value]) => upsertToken(set, 'borderRadius', name, value));

  return { set: set.name, count: set.tokens.length };
}

function board(name, x, y, w = 1440, h = 980) {
  const b = penpot.createBoard();
  b.name = name;
  b.x = x;
  b.y = y;
  b.resize(w, h);
  b.fills = [{ fillColor: boardFill(name), fillOpacity: 1 }];
  b.strokes = [{ strokeColor: C.border, strokeWidth: 1, strokeOpacity: 1 }];
  b.borderRadius = 2;
  rect(b, 'Top Accent', 0, 0, w, 8, C.brand, null);
  const overviewMarker = rect(b, 'Overview Marker', w - 360, h - 74, 312, 34, C.bg, null, 2);
  overviewMarker.opacity = 0.5;
  text(b, 'Overview Marker Label', name, w - 344, h - 64, 280, {
    size: 14,
    weight: 700,
    color: C.med,
    h: 24,
  });
  return b;
}

function localX(parent, x) {
  return parent.type === 'board' ? parent.x + x : x;
}

function localY(parent, y) {
  return parent.type === 'board' ? parent.y + y : y;
}

function boardFill(name) {
  if (name.startsWith('FOUNDATION -')) return '#1E293B';
  if (name.startsWith('COMPONENT -')) return '#253346';
  if (name.startsWith('PATTERN -')) return '#1F3A5F';
  if (name.startsWith('SCREEN -')) return '#2E4057';
  if (name.startsWith('FEATURE -')) return '#2D2A5F';
  if (name.startsWith('ASSET -')) return '#4A3324';
  return C.surface;
}

function rect(parent, name, x, y, w, h, fill, stroke = C.border, radius = 2) {
  const r = penpot.createRectangle();
  r.name = name;
  r.x = localX(parent, x);
  r.y = localY(parent, y);
  r.resize(w, h);
  r.fills = fill ? [{ fillColor: fill, fillOpacity: 1 }] : [];
  r.strokes = stroke ? [{ strokeColor: stroke, strokeWidth: 1, strokeOpacity: 1 }] : [];
  r.borderRadius = radius;
  parent.appendChild(r);
  return r;
}

function ellipse(parent, name, x, y, w, h, fill, stroke = null) {
  const e = penpot.createEllipse();
  e.name = name;
  e.x = localX(parent, x);
  e.y = localY(parent, y);
  e.resize(w, h);
  e.fills = fill ? [{ fillColor: fill, fillOpacity: 1 }] : [];
  e.strokes = stroke ? [{ strokeColor: stroke, strokeWidth: 1, strokeOpacity: 1 }] : [];
  parent.appendChild(e);
  return e;
}

function text(parent, name, value, x, y, w, opts = {}) {
  const t = penpot.createText(value);
  t.name = name;
  t.x = localX(parent, x);
  t.y = localY(parent, y);
  t.resize(w, opts.h || 40);
  t.growType = 'auto-height';
  t.fontSize = String(opts.size || 14);
  t.fontWeight = String(opts.weight || 400);
  t.lineHeight = String(opts.lineHeight || 1.22);
  t.fills = [{ fillColor: opts.color || C.high, fillOpacity: 1 }];
  parent.appendChild(t);
  return t;
}

function title(parent, value, x, y, w = 900) {
  text(parent, 'Board Title', value, x, y, w, { size: 34, weight: 700 });
}

function note(parent, value, x, y, w = 900) {
  text(parent, 'Board Note', value, x, y, w, { size: 14, color: C.med, h: 64 });
}

function pill(parent, label, x, y, fill = C.raised, color = C.high) {
  const w = Math.max(72, label.length * 8 + 28);
  rect(parent, `Pill / ${label}`, x, y, w, 32, fill, null, 2);
  text(parent, `Pill Label / ${label}`, label, x + 14, y + 7, w - 24, {
    size: 11,
    weight: 700,
    color,
  });
  return w;
}

function settingsBadge(parent, label, x, y, color) {
  const w = Math.max(82, label.length * 7 + 18);
  const bg = rect(parent, `SettingsBadge / ${label}`, x, y, w, 20, color, color, 1);
  bg.fills = [{ fillColor: color, fillOpacity: 0.12 }];
  bg.strokes = [{ strokeColor: color, strokeWidth: 0.5, strokeOpacity: 0.5 }];
  text(parent, `SettingsBadge Label / ${label}`, label, x + 8, y + 5, w - 16, {
    size: 9,
    weight: 700,
    color,
    h: 14,
  });
  return w;
}

function button(parent, label, x, y, variant = 'filled', state = 'default') {
  const fill =
    variant === 'filled'
      ? state === 'disabled'
        ? C.dis
        : C.brand
      : state === 'focused'
        ? '#262626'
        : C.raised;
  const stroke = variant === 'outlined' || state === 'focused' ? C.high : null;
  rect(parent, `Button / ${variant} / ${state}`, x, y, 168, 44, fill, stroke, 2);
  text(parent, `Button Label / ${label}`, label, x + 20, y + 13, 128, {
    size: 13,
    weight: 700,
    color: state === 'disabled' ? C.med : C.high,
  });
}

function posterCard(parent, name, x, y, w = 132, h = 198, focused = false) {
  rect(parent, `Poster Card / ${name}`, x, y, w, h, '#252525', focused ? C.high : C.border, 2);
  rect(parent, `Poster Image / ${name}`, x + 8, y + 8, w - 16, h - 54, '#303030', null, 2);
  text(parent, `Poster Initial / ${name}`, name.slice(0, 2).toUpperCase(), x + 34, y + 58, 80, {
    size: 34,
    weight: 700,
    color: C.med,
  });
  text(parent, `Poster Title / ${name}`, name, x + 10, y + h - 38, w - 20, {
    size: 12,
    weight: 700,
  });
  rect(parent, `Poster Progress / ${name}`, x + 10, y + h - 14, w - 20, 3, '#333333', null, 1.5);
  rect(parent, `Poster Progress Fill / ${name}`, x + 10, y + h - 14, (w - 20) * 0.55, 3, C.brand, null, 1.5);
}

function navRail(parent, x, y, expanded = false) {
  const w = expanded ? 220 : 72;
  rect(parent, expanded ? 'Navigation Rail / Expanded' : 'Navigation Rail / Collapsed', x, y, w, 540, C.surface, C.border, 0);
  const items = ['Home', 'Search', 'Live', 'Guide', 'Movies', 'Series', 'DVR', 'Fav', 'Settings'];
  items.forEach((item, i) => {
    const iy = y + 24 + i * 54;
    rect(parent, `Nav Item / ${item}`, x + 12, iy, w - 24, 40, i === 2 ? C.brand : 'transparent', i === 2 ? null : C.border, 2);
    ellipse(parent, `Nav Icon / ${item}`, x + 25, iy + 11, 18, 18, i === 2 ? C.high : C.med, null);
    if (expanded) text(parent, `Nav Label / ${item}`, item, x + 58, iy + 12, 130, { size: 12 });
  });
}

function epgGrid(parent, x, y) {
  rect(parent, 'EPG Background', x, y, 900, 430, C.bg, C.border, 2);
  rect(parent, 'EPG Channel Column', x, y, 170, 430, C.surface, C.border, 0);
  for (let i = 0; i < 6; i++) {
    const rowY = y + 56 + i * 58;
    rect(parent, `EPG Channel Row ${i + 1}`, x, rowY, 170, 58, i === 2 ? '#262626' : C.surface, C.border, 0);
    ellipse(parent, `EPG Channel Logo ${i + 1}`, x + 16, rowY + 15, 28, 28, C.raised, C.border);
    text(parent, `EPG Channel Name ${i + 1}`, `Channel ${i + 1}`, x + 56, rowY + 19, 90, { size: 11 });
    for (let j = 0; j < 4; j++) {
      const w = [150, 220, 110, 180][(i + j) % 4];
      const px = x + 190 + j * 165;
      rect(parent, `EPG Program ${i + 1}.${j + 1}`, px, rowY + 8, w, 42, j === 1 ? '#1E2A22' : '#202020', C.border, 2);
      text(parent, `EPG Program Label ${i + 1}.${j + 1}`, ['News', 'Match', 'Movie', 'Kids'][j], px + 10, rowY + 20, w - 20, { size: 10 });
    }
  }
  rect(parent, 'EPG Now Line', x + 510, y + 42, 2, 370, C.live, null, 0);
}

function osd(parent, x, y) {
  rect(parent, 'OSD Video Surface', x, y, 980, 560, C.bg, C.border, 2);
  rect(parent, 'OSD Top Bar', x + 28, y + 24, 924, 58, '#000000', null, 2);
  text(parent, 'OSD Title', 'Live Channel - Current Program', x + 52, y + 43, 500, { size: 16, weight: 700 });
  pill(parent, 'LIVE', x + 820, y + 37, C.live);
  ellipse(parent, 'OSD Back 10', x + 382, y + 220, 56, 56, '#000000', C.high);
  ellipse(parent, 'OSD Play', x + 462, y + 202, 92, 92, C.high, null);
  ellipse(parent, 'OSD Fwd 10', x + 578, y + 220, 56, 56, '#000000', C.high);
  rect(parent, 'OSD Bottom Bar', x + 28, y + 448, 924, 84, '#000000', null, 2);
  rect(parent, 'OSD Progress Track', x + 64, y + 486, 780, 4, '#333333', null, 1.5);
  rect(parent, 'OSD Progress Fill', x + 64, y + 486, 310, 4, C.brand, null, 1.5);
  text(parent, 'OSD Time', '12:04 / 42:30', x + 64, y + 500, 200, { size: 11, color: C.med });
}

function foundations() {
  const b = board('FOUNDATION - Tokens', 0, 0, 1440, 980);
  title(b, 'Foundations / Tokens', 48, 42);
  note(b, 'Editable specimens plus real Penpot token set named CrispyTivi. Flutter Crispy* tokens remain authoritative.', 48, 88);
  const swatches = [
    ['bg.immersive', C.bg],
    ['bg.surface', C.surface],
    ['bg.raised', C.raised],
    ['brand.red', C.brand],
    ['text.high', C.high],
    ['text.medium', C.med],
    ['status.success', C.success],
    ['status.warning', C.warning],
    ['status.error', C.error],
    ['status.live', C.live],
  ];
  swatches.forEach(([label, color], i) => {
    const x = 48 + (i % 5) * 250;
    const y = 170 + Math.floor(i / 5) * 150;
    rect(b, `Color Token / ${label}`, x, y, 210, 78, color, C.border, 2);
    text(b, `Color Label / ${label}`, label, x, y + 88, 210, { size: 12, weight: 700 });
    text(b, `Color Hex / ${label}`, color, x, y + 110, 210, { size: 11, color: C.med });
  });
  const spacings = [['xxs', 2], ['xs', 4], ['sm', 8], ['md', 16], ['lg', 24], ['xl', 32], ['xxl', 48]];
  text(b, 'Spacing Title', 'Spacing scale', 48, 500, 300, { size: 20, weight: 700 });
  spacings.forEach(([label, size], i) => {
    const y = 550 + i * 44;
    rect(b, `Spacing / ${label}`, 48, y + 8, size * 4, 14, C.brand, null, 0);
    text(b, `Spacing Label / ${label}`, `${label}  ${size}px`, 270, y, 160, { size: 12 });
  });
  text(b, 'Radius Title', 'Radius scale', 600, 500, 300, { size: 20, weight: 700 });
  [['none', 0], ['tvSm', 1], ['tv', 2], ['progressBar', 1.5]].forEach(([label, radius], i) => {
    const x = 600 + i * 170;
    rect(b, `Radius / ${label}`, x, 560, 120, 82, C.raised, C.high, radius);
    text(b, `Radius Label / ${label}`, `${label}  ${radius}px`, x, 660, 150, { size: 12 });
  });
  text(b, 'Typography Title', 'Typography', 48, 760, 260, { size: 20, weight: 700 });
  text(b, 'Typography Micro', 'micro / 10px metadata label', 48, 812, 260, { size: 10, weight: 700, color: C.med });
  text(b, 'Elevation Title', 'Elevation', 360, 760, 260, { size: 20, weight: 700 });
  [
    ['level0', 0, 0, 0],
    ['level1', 3, 1, 30],
    ['level2', 12, 4, 38],
    ['level3', 24, 8, 45],
  ].forEach(([label, blur, offsetY, opacity], i) => {
    const x = 360 + i * 130;
    rect(b, `Elevation / ${label}`, x, 812, 96, 54, C.raised, C.border, 2);
    text(b, `Elevation Label / ${label}`, `${label}  b${blur}/y${offsetY}/${opacity}%`, x, 878, 128, { size: 10, color: C.med });
  });
  text(b, 'Motion Title', 'Motion', 930, 760, 260, { size: 20, weight: 700 });
  [
    ['extraFast', '80ms'],
    ['fast', '150ms'],
    ['normal', '300ms'],
    ['slow', '500ms'],
    ['skeleton', '1500ms'],
    ['autoHide', '4000ms'],
    ['heroCycle', '8000ms'],
    ['hoverScale', '1.1x'],
  ].forEach(([label, value], i) => {
    const x = 930 + (i % 3) * 150;
    const y = 812 + Math.floor(i / 3) * 44;
    rect(b, `Motion / ${label}`, x, y, 128, 34, i === 2 ? C.brand : C.raised, C.border, 2);
    text(b, `Motion Label / ${label}`, `${label} ${value}`, x + 10, y + 10, 108, { size: 10, color: C.high });
  });
  return b;
}

function components() {
  const b = board('COMPONENT - Core Components', 1600, 0, 1440, 1160);
  title(b, 'Core Components', 48, 42);
  note(b, 'Editable component specimens with states. Match Widgetbook @UseCase design links.', 48, 88);
  text(b, 'Buttons Header', 'Buttons', 48, 160, 220, { size: 22, weight: 700 });
  [['filled', 'default'], ['filled', 'focused'], ['filled', 'disabled'], ['outlined', 'default'], ['outlined', 'focused']].forEach(([v, s], i) => {
    button(b, `${v} ${s}`, 48 + i * 190, 210, v, s);
  });
  text(b, 'Badges Header', 'Badges and chips', 48, 310, 300, { size: 22, weight: 700 });
  pill(b, 'LIVE', 48, 365, C.live);
  pill(b, 'REC', 132, 365, C.live);
  pill(b, 'NEW EPISODE', 214, 365, C.brand);
  pill(b, '2026', 360, 365);
  pill(b, '4K', 432, 365);
  pill(b, 'PG-13', 496, 365);
  ['All', 'News', 'Sports', 'Movies', 'Kids'].forEach((label, i) => {
    pill(b, label, 48 + i * 110, 430, i === 2 ? C.brand : C.raised, i === 2 ? C.high : C.med);
  });
  text(b, 'States Header', 'State widgets', 48, 530, 300, { size: 22, weight: 700 });
  rect(b, 'Empty State Card', 48, 580, 280, 220, C.raised, C.border, 2);
  ellipse(b, 'Empty Icon', 166, 620, 48, 48, C.dis, null);
  text(b, 'Empty Title', 'No items', 112, 690, 160, { size: 18, weight: 700 });
  text(b, 'Empty Body', 'Add a playlist source in Settings', 82, 724, 220, { size: 12, color: C.med });
  rect(b, 'Error State Card', 360, 580, 280, 220, C.raised, C.border, 2);
  ellipse(b, 'Error Icon', 478, 620, 48, 48, C.error, null);
  text(b, 'Error Title', 'Failed to load', 422, 690, 180, { size: 18, weight: 700 });
  button(b, 'Retry', 416, 734, 'outlined', 'default');
  text(b, 'Skeleton Header', 'Skeletons', 700, 530, 300, { size: 22, weight: 700 });
  rect(b, 'Skeleton Card 1', 700, 580, 118, 170, '#2A2A2A', null, 2);
  rect(b, 'Skeleton Line 1', 700, 766, 160, 14, '#2A2A2A', null, 2);
  rect(b, 'Skeleton Line 2', 700, 790, 100, 14, '#2A2A2A', null, 2);
  rect(b, 'Skeleton Card 2', 890, 580, 118, 170, '#2A2A2A', null, 2);
  rect(b, 'Skeleton Avatar', 1080, 610, 64, 64, '#2A2A2A', null, 32);
  text(b, 'Surfaces Header', 'Glass surface', 48, 870, 300, { size: 22, weight: 700 });
  rect(b, 'Glass Surface Specimen', 48, 920, 440, 140, '#1A1A1A', C.border, 2);
  rect(b, 'Glass Tint Overlay', 48, 920, 440, 140, '#1A1A1A', null, 2).opacity = 0.82;
  text(b, 'Glass Surface Text', 'Sharp, dark, token-driven surface', 72, 974, 380, { size: 16, weight: 700 });
  return b;
}

function mediaPatterns() {
  const b = board('COMPONENT - Media Cards', 3200, 0, 1440, 980);
  title(b, 'Media Cards and Rows', 48, 42);
  note(b, 'Editable poster, landscape, progress, and horizontal rail patterns.', 48, 88);
  posterCard(b, 'Movie', 48, 170, 150, 225, false);
  posterCard(b, 'Focused', 240, 160, 170, 255, true);
  posterCard(b, 'Series', 456, 170, 150, 225, false);
  rect(b, 'Landscape Card', 700, 170, 420, 236, C.raised, C.border, 2);
  rect(b, 'Landscape Image', 716, 186, 388, 160, '#303030', null, 2);
  text(b, 'Landscape Initials', 'LS', 880, 242, 80, { size: 34, weight: 700, color: C.med });
  text(b, 'Landscape Title', 'Landscape Media Card', 724, 360, 320, { size: 16, weight: 700 });
  pill(b, '4K', 724, 386, C.brand);
  pill(b, 'Drama', 786, 386, C.raised, C.med);
  text(b, 'Rail Header', 'Horizontal rail pattern', 48, 500, 500, { size: 22, weight: 700 });
  ['One', 'Two', 'Three', 'Four', 'Five'].forEach((label, i) => posterCard(b, label, 48 + i * 178, 560, 132, 198, i === 1));
  return b;
}

function navigationPatterns() {
  const b = board('PATTERN - Navigation and TV Focus', 0, 1300, 1440, 980);
  title(b, 'Navigation and TV Focus', 48, 42);
  note(b, 'Editable shell navigation, focus, bottom nav, and TV color-button patterns.', 48, 88);
  navRail(b, 48, 170, false);
  navRail(b, 170, 170, true);
  rect(b, 'Content Area Specimen', 440, 170, 850, 540, C.bg, C.border, 2);
  text(b, 'Breadcrumb Specimen', 'Home / Live TV / Sports', 470, 198, 400, { size: 12, color: C.med });
  rect(b, 'Focused Content Card', 470, 260, 260, 150, C.raised, C.high, 2);
  text(b, 'Focused Card Title', 'Focused content target', 494, 322, 210, { size: 16, weight: 700 });
  rect(b, 'Bottom Nav', 440, 760, 850, 78, C.surface, C.border, 2);
  ['Home', 'Live', 'Search', 'Movies', 'Settings'].forEach((item, i) => {
    const x = 470 + i * 160;
    ellipse(b, `Bottom Icon / ${item}`, x + 50, 778, 20, 20, i === 1 ? C.brand : C.med, null);
    text(b, `Bottom Label / ${item}`, item, x + 30, 806, 80, { size: 11, color: i === 1 ? C.high : C.med });
  });
  rect(b, 'TV Color Legend', 440, 860, 850, 54, C.raised, C.border, 2);
  [['Clear', C.live], ['Search', C.green], ['Sort', C.yellow], ['My List', C.blue]].forEach(([label, color], i) => {
    ellipse(b, `TV Color Dot / ${label}`, 500 + i * 170, 880, 14, 14, color, null);
    text(b, `TV Color Label / ${label}`, label, 522 + i * 170, 878, 100, { size: 12 });
  });
  return b;
}

function epgPattern() {
  const b = board('PATTERN - EPG Timeline', 1600, 1300, 1440, 760);
  title(b, 'EPG Timeline Pattern', 48, 42);
  note(b, 'Editable guide grid: channel column, program blocks, time axis, and now line.', 48, 88);
  epgGrid(b, 48, 170);
  return b;
}

function playerPattern() {
  const b = board('PATTERN - Player OSD', 3200, 1300, 1440, 800);
  title(b, 'Player OSD Pattern', 48, 42);
  note(b, 'Editable OSD layout for live/VOD playback controls.', 48, 88);
  osd(b, 48, 160);
  return b;
}

function screenTemplates() {
  const b = board('SCREEN - Representative Layouts', 0, 2600, 1440, 1080);
  title(b, 'Representative Screen Layouts', 48, 42);
  note(b, 'Editable approximations of app screens assembled from design-system primitives.', 48, 88);
  rect(b, 'Home Screen Frame', 48, 170, 610, 380, C.bg, C.border, 2);
  text(b, 'Home Screen Title', 'Home', 76, 198, 180, { size: 22, weight: 700 });
  rect(b, 'Home Hero', 76, 250, 554, 120, C.raised, C.border, 2);
  text(b, 'Hero Title', 'Featured Movie', 104, 292, 220, { size: 20, weight: 700 });
  ['Continue', 'Top 10', 'Latest'].forEach((label, row) => {
    text(b, `Home Row Label / ${label}`, label, 76, 398 + row * 48, 140, { size: 12, color: C.med });
    for (let i = 0; i < 5; i++) rect(b, `Home Tile ${row}.${i}`, 180 + i * 76, 392 + row * 48, 58, 34, C.raised, C.border, 2);
  });
  rect(b, 'Live TV Frame', 720, 170, 610, 380, C.bg, C.border, 2);
  text(b, 'Live TV Title', 'Live TV', 748, 198, 180, { size: 22, weight: 700 });
  rect(b, 'Live Group Sidebar', 748, 250, 130, 260, C.surface, C.border, 2);
  for (let i = 0; i < 6; i++) rect(b, `Live Channel Row ${i}`, 900, 250 + i * 42, 380, 34, i === 1 ? '#262626' : C.raised, i === 1 ? C.high : C.border, 2);
  rect(b, 'Settings Frame', 48, 620, 610, 340, C.bg, C.border, 2);
  text(b, 'Settings Title', 'Settings', 76, 648, 180, { size: 22, weight: 700 });
  ['General', 'Sources', 'Playback', 'Data', 'Advanced', 'About'].forEach((label, i) => pill(b, label, 76 + (i % 3) * 160, 700 + Math.floor(i / 3) * 44, i === 0 ? C.brand : C.raised));
  for (let i = 0; i < 4; i++) rect(b, `Settings Tile ${i}`, 76, 810 + i * 34, 510, 26, C.raised, C.border, 2);
  rect(b, 'Multiview Frame', 720, 620, 610, 340, C.bg, C.border, 2);
  text(b, 'Multiview Title', 'Multiview', 748, 648, 180, { size: 22, weight: 700 });
  for (let r = 0; r < 2; r++) for (let col = 0; col < 2; col++) rect(b, `MV Slot ${r}.${col}`, 748 + col * 260, 700 + r * 120, 240, 104, C.raised, r === 0 && col === 0 ? C.high : C.border, 2);
  rect(b, 'MV Controls', 1000, 650, 300, 42, '#1A1A1A', C.border, 2);
  return b;
}

function featureWidgets() {
  const b = board('FEATURE - Live TV Widgets', 1600, 2600, 1440, 980);
  title(b, 'Feature Widgets / Live TV', 48, 42);
  note(b, 'Editable variants matching ChannelListItem and ChannelGridItem Widgetbook use cases.', 48, 88);
  text(b, 'Rows Header', 'ChannelListItem states', 48, 160, 360, { size: 22, weight: 700 });
  for (let i = 0; i < 3; i++) {
    const y = 220 + i * 112;
    rect(b, `Channel Row ${i + 1}`, 48, y, 720, 86, i === 0 ? '#262626' : C.raised, i === 0 ? C.high : C.border, 2);
    rect(b, `Channel Logo ${i + 1}`, 68, y + 19, 86, 48, '#303030', C.border, 2);
    text(b, `Channel Logo Text ${i + 1}`, ['CN', 'SP', 'MV'][i], 96, y + 32, 40, { size: 14, weight: 700, color: C.med });
    pill(b, String([12, 108, 204][i]), 174, y + 14, i === 0 ? C.brand : C.raised, i === 0 ? C.high : C.med);
    text(b, `Channel Name ${i + 1}`, ['Crispy News HD', 'Match Day Sports', 'Movie Classics'][i], 250, y + 17, 220, { size: 16, weight: 700 });
    text(b, `Program ${i + 1}`, ['Morning Briefing', 'Championship Live', 'No EPG data'][i], 250, y + 43, 280, { size: 12, color: C.med });
    rect(b, `Program Track ${i + 1}`, 250, y + 68, 260, 3, '#333333', null, 1.5);
    rect(b, `Program Fill ${i + 1}`, 250, y + 68, [120, 210, 0][i], 3, C.live, null, 1.5);
    if (i === 0) pill(b, 'FHD', 584, y + 18, C.raised, C.med);
    if (i === 1) pill(b, 'DUP', 584, y + 18, C.warning, C.high);
    if (i === 0) ellipse(b, 'Favorite Star', 688, y + 30, 20, 20, C.brand, null);
  }
  text(b, 'Grid Header', 'ChannelGridItem states', 48, 600, 360, { size: 22, weight: 700 });
  for (let i = 0; i < 3; i++) {
    const x = 48 + i * 210;
    rect(b, `Channel Grid Tile ${i + 1}`, x, 660, 178, 150, i === 1 ? '#262626' : C.raised, i === 1 ? C.high : C.border, 2);
    rect(b, `Grid Logo ${i + 1}`, x + 42, 690, 94, 48, '#303030', C.border, 2);
    text(b, `Grid Channel Name ${i + 1}`, ['News HD', 'Sports 4K', 'Kids'][i], x + 22, 752, 134, { size: 12, weight: 700 });
    text(b, `Grid Program ${i + 1}`, ['Briefing', 'Live Match', 'Cartoons'][i], x + 22, 776, 134, { size: 10, color: C.med });
  }
  return b;
}

function settingsWidgets() {
  const b = board('FEATURE - Settings Widgets', 3200, 2600, 1440, 880);
  title(b, 'Feature Widgets / Settings', 48, 42);
  note(b, 'Editable SettingsBadge, SettingsTileTitle, and SettingsCard variants mirrored by Flutter settings code and Widgetbook fixtures.', 48, 88);
  text(b, 'Badge Header', 'SettingsBadge variants', 48, 160, 360, { size: 22, weight: 700 });
  settingsBadge(b, 'Experimental', 48, 220, C.warning);
  settingsBadge(b, 'Coming Soon', 190, 220, '#9E9E9E');
  text(b, 'Card Header', 'SettingsCard group', 48, 320, 360, { size: 22, weight: 700 });
  rect(b, 'Settings Card', 48, 380, 620, 250, C.surface, null, 2);
  text(b, 'Settings Tile 1 Title', 'Auto resume last channel', 96, 410, 320, { size: 16, weight: 700 });
  text(b, 'Settings Tile 1 Subtitle', 'Start playback when Live TV opens.', 96, 438, 360, { size: 12, color: C.med });
  rect(b, 'Switch Track', 560, 414, 58, 30, C.brand, null, 15);
  ellipse(b, 'Switch Thumb', 588, 417, 24, 24, C.high, null);
  rect(b, 'Settings Divider', 104, 478, 520, 1, C.border, null, 0);
  ellipse(b, 'Settings Icon', 96, 516, 26, 26, C.med, null);
  text(b, 'Settings Tile 2 Title', 'Theme preview', 140, 508, 180, { size: 16, weight: 700 });
  settingsBadge(b, 'Experimental', 300, 508, C.warning);
  text(b, 'Settings Tile 2 Subtitle', 'Warm black with Crispy red accent.', 140, 538, 320, { size: 12, color: C.med });
  text(b, 'Chevron', '>', 600, 520, 30, { size: 20, color: C.med });
  text(b, 'Dialog Header', 'Dialog pattern', 760, 320, 360, { size: 22, weight: 700 });
  rect(b, 'Dialog', 760, 380, 460, 250, C.surface, C.border, 2);
  text(b, 'Dialog Title', 'Reset Appearance', 792, 416, 300, { size: 20, weight: 700 });
  text(b, 'Dialog Body', 'Reset all settings to their factory defaults?', 792, 464, 360, { size: 14, color: C.med });
  button(b, 'Cancel', 920, 548, 'outlined', 'default');
  button(b, 'Reset', 1080, 548, 'filled', 'default');
  text(b, 'Overflow-Safe Header', 'Overflow-safe title + badge', 760, 680, 460, { size: 22, weight: 700 });
  rect(b, 'Overflow-Safe Tile', 760, 730, 520, 78, C.surface, null, 2);
  text(b, 'Overflow-Safe Title', 'EPG Update Notification', 808, 752, 210, { size: 16, weight: 700 });
  settingsBadge(b, 'Experimental', 1038, 754, C.warning);
  text(b, 'Overflow-Safe Note', 'SettingsTileTitle constrains text before badge to avoid row overflow in narrow panels.', 808, 784, 420, { size: 11, color: C.med });
  return b;
}

function vodWidgets() {
  const b = board('FEATURE - VOD Widgets', 0, 3900, 1440, 980);
  title(b, 'Feature Widgets / VOD', 48, 42);
  note(b, 'Editable variants matching QualityBadge, CircularAction, EpisodeTile, and synopsis Widgetbook fixtures.', 48, 88);
  text(b, 'Quality Header', 'QualityBadge variants', 48, 160, 360, { size: 22, weight: 700 });
  ['HD', 'FHD', '4K', 'HDR'].forEach((label, i) => pill(b, label, 48 + i * 88, 220, C.bg, C.high));
  text(b, 'Action Header', 'CircularAction variants', 48, 320, 360, { size: 22, weight: 700 });
  [['+', 'My List'], ['OK', 'Saved'], ['UP', 'Rate'], ['SH', 'Share']].forEach(([icon, label], i) => {
    const x = 48 + i * 140;
    ellipse(b, `Circular Action / ${label}`, x + 22, 380, 46, 46, C.surface, C.border);
    text(b, `Circular Action Icon / ${label}`, icon, x + 36, 391, 24, { size: 18, color: C.brand, weight: 700 });
    text(b, `Circular Action Label / ${label}`, label, x, 436, 90, { size: 11, color: C.med });
  });
  text(b, 'Episode Header', 'EpisodeTile states', 48, 540, 360, { size: 22, weight: 700 });
  for (let i = 0; i < 3; i++) {
    const y = 600 + i * 92;
    rect(b, `Episode Tile ${i + 1}`, 48, y, 760, 76, i === 0 ? '#2A211A' : i === 1 ? '#1A222A' : C.raised, i === 1 ? C.brand : C.border, 2);
    rect(b, `Episode Thumbnail ${i + 1}`, 68, y + 8, 120, 68, '#303030', C.border, 2);
    text(b, `Episode Label ${i + 1}`, ['S2 E4  LAST WATCHED', 'S2 E5  UP NEXT', 'S2 E6  WATCHED'][i], 208, y + 10, 260, { size: 11, color: i === 1 ? C.brand : C.med, weight: 700 });
    text(b, `Episode Title ${i + 1}`, ['The Long Night', 'After the Signal', 'Signal Found'][i], 208, y + 32, 300, { size: 15, weight: 700 });
    text(b, `Episode Meta ${i + 1}`, ['47 min  Aired 2026', '49 min  Aired 2026', '51 min  Aired 2026'][i], 208, y + 54, 260, { size: 11, color: C.med });
    if (i === 0) rect(b, 'Episode Progress', 68, y + 72, 54, 3, C.brand, null, 1.5);
    if (i === 2) ellipse(b, 'Episode Watched Check', 740, y + 26, 24, 24, C.brand, null);
  }
  text(b, 'Synopsis Header', 'ExpandableSynopsis', 900, 160, 360, { size: 22, weight: 700 });
  rect(b, 'Synopsis Panel', 900, 220, 440, 250, C.raised, C.border, 2);
  text(b, 'Synopsis Text', 'A team of explorers uncovers a forgotten broadcast that points to a lost archive of classic films, live recordings, and impossible signals from beyond the edge of known space.', 928, 252, 380, { size: 14, color: C.med, h: 140, lineHeight: 1.35 });
  text(b, 'Synopsis More', '...more', 928, 410, 120, { size: 13, weight: 700 });
  return b;
}

function playerWidgets() {
  const b = board('FEATURE - Player Widgets', 1600, 3900, 1440, 940);
  title(b, 'Feature Widgets / Player', 48, 42);
  note(b, 'Editable variants matching OsdIconButton and subtitle style Widgetbook fixtures.', 48, 88);
  text(b, 'OSD Button Header', 'OsdIconButton states', 48, 160, 360, { size: 22, weight: 700 });
  rect(b, 'OSD Panel Strip', 48, 220, 560, 84, C.bg, C.border, 2);
  [['<<', 'Back 10'], ['>', 'Play'], ['>>', 'Forward 10'], ['CC', 'Disabled']].forEach(([icon, label], i) => {
    const x = 76 + i * 120;
    rect(b, `OSD Button ${label}`, x, 240, 52, 44, i === 1 ? C.high : 'transparent', i === 0 ? C.high : null, 2);
    text(b, `OSD Icon ${label}`, icon, x + 14, 253, 28, { size: 13, weight: 700, color: i === 1 ? C.bg : i === 3 ? C.dis : C.high });
    text(b, `OSD Label ${label}`, label, x - 14, 310, 90, { size: 10, color: C.med });
  });
  text(b, 'Subtitle Header', 'Subtitle style controls', 48, 390, 420, { size: 22, weight: 700 });
  rect(b, 'Subtitle Sheet', 48, 450, 680, 380, '#1A1A1A', C.border, 2);
  text(b, 'Subtitle Sheet Title', 'Subtitle Style', 72, 478, 280, { size: 18, weight: 700 });
  text(b, 'Subtitle Font Label', 'FONT SIZE', 72, 540, 200, { size: 11, color: C.med, weight: 700 });
  ['Small', 'Medium', 'Large', 'XL'].forEach((label, i) => pill(b, label, 72 + i * 110, 570, i === 1 ? C.brand : C.raised, i === 1 ? C.high : C.med));
  text(b, 'Subtitle Color Label', 'TEXT COLOR', 72, 635, 200, { size: 11, color: C.med, weight: 700 });
  [C.high, '#FFEA00', '#00E676', '#00E5FF'].forEach((color, i) => {
    ellipse(b, `Subtitle Color ${i}`, 72 + i * 48, 666, 32, 32, color, i === 0 ? C.brand : C.border);
  });
  text(b, 'Subtitle Background Label', 'BACKGROUND', 72, 720, 200, { size: 11, color: C.med, weight: 700 });
  ['Black', 'Semi', 'None'].forEach((label, i) => pill(b, label, 72 + i * 100, 750, i === 1 ? C.brand : C.raised, i === 1 ? C.high : C.med));
  rect(b, 'Subtitle Slider Track', 380, 760, 260, 3, '#333333', null, 1.5);
  rect(b, 'Subtitle Slider Fill', 380, 760, 150, 3, C.brand, null, 1.5);
  ellipse(b, 'Subtitle Slider Thumb', 522, 752, 18, 18, C.brand, null);
  text(b, 'Preview Header', 'Subtitle preview', 820, 390, 360, { size: 22, weight: 700 });
  rect(b, 'Preview Video', 820, 450, 500, 280, C.bg, C.border, 2);
  rect(b, 'Preview Subtitle Bg', 930, 610, 280, 42, '#000000', null, 2).opacity = 0.72;
  text(b, 'Preview Subtitle Text', 'Subtitle sample text', 968, 620, 220, { size: 20, weight: 700, color: '#FFEA00' });
  return b;
}

function componentButtonBoard() {
  const b = board('COMPONENT - Buttons', 0, 5200, 1440, 760);
  title(b, 'Buttons', 48, 42);
  note(b, 'AsyncFilledButton states mirrored from Widgetbook: default, focused, disabled, loading, and secondary variants.', 48, 88);
  ['Default', 'Focused', 'Disabled', 'Loading'].forEach((state, i) => {
    button(b, state, 80 + i * 220, 260, i === 3 ? 'outlined' : 'filled', state.toLowerCase());
    text(b, `Button State Label / ${state}`, state, 80 + i * 220, 330, 160, { size: 16, weight: 700 });
  });
  button(b, 'Cancel', 80, 460, 'outlined', 'default');
  button(b, 'Retry', 300, 460, 'outlined', 'focused');
  button(b, 'Continue', 520, 460, 'filled', 'default');
  return b;
}

function componentBadgeBoard() {
  const b = board('COMPONENT - Badges', 1600, 5200, 1440, 760);
  title(b, 'Badges', 48, 42);
  note(b, 'LiveBadge and ContentStatusBadge visual states with status color tokens.', 48, 88);
  ['LIVE', 'REC', 'NEW EPISODE', 'NEW SEASON', 'EXPIRING', 'ERROR'].forEach((label, i) => {
    pill(b, label, 80 + (i % 3) * 260, 260 + Math.floor(i / 3) * 100, i === 5 ? C.error : i < 2 ? C.live : C.brand);
  });
  return b;
}

function componentChipBoard() {
  const b = board('COMPONENT - Chips', 3200, 5200, 1440, 760);
  title(b, 'Chips', 48, 42);
  note(b, 'MetaChip and GenrePillRow states: neutral, selected, focused, and metadata variants.', 48, 88);
  ['2026', '4K', 'PG-13', 'Drama', 'News', 'Sports', 'Movies', 'Kids'].forEach((label, i) => {
    pill(b, label, 80 + (i % 4) * 190, 260 + Math.floor(i / 4) * 96, label === 'Sports' ? C.brand : C.raised, label === 'Sports' ? C.high : C.med);
  });
  return b;
}

function componentHeaderBoard() {
  const b = board('COMPONENT - Headers', 0, 6500, 1440, 720);
  title(b, 'Headers', 48, 42);
  note(b, 'SectionHeader variants for feature rows, settings groups, and TV-focused sections.', 48, 88);
  ['Sources', 'Continue Watching', 'Live TV', 'Settings'].forEach((label, i) => {
    rect(b, `Header Row / ${label}`, 80, 240 + i * 92, 720, 58, i === 2 ? '#262626' : C.raised, i === 2 ? C.high : C.border, 2);
    ellipse(b, `Header Icon / ${label}`, 104, 256 + i * 92, 26, 26, i === 2 ? C.brand : C.med, null);
    text(b, `Header Text / ${label}`, label, 150, 257 + i * 92, 360, { size: 22, weight: 700, color: C.high });
  });
  return b;
}

function componentSurfaceBoard() {
  const b = board('COMPONENT - Surfaces', 1600, 6500, 1440, 720);
  title(b, 'Surfaces', 48, 42);
  note(b, 'GlassSurface and sheet surfaces using tokenized dark material, tint, and border treatment.', 48, 88);
  [0, 1, 2].forEach((i) => {
    const x = 80 + i * 330;
    rect(b, `Surface Card ${i + 1}`, x, 250, 280, 260, i === 0 ? C.surface : i === 1 ? C.raised : '#1A1A1A', i === 2 ? C.high : C.border, 2);
    text(b, `Surface Title ${i + 1}`, ['Surface', 'Raised', 'Focused Glass'][i], x + 28, 288, 220, { size: 22, weight: 700 });
    text(b, `Surface Body ${i + 1}`, 'Token-driven background, border, tint, and spacing.', x + 28, 340, 220, { size: 14, color: C.med, h: 96 });
  });
  return b;
}

function componentStateBoard() {
  const b = board('COMPONENT - State Widgets', 3200, 6500, 1440, 760);
  title(b, 'State Widgets', 48, 42);
  note(b, 'Empty, loading, error, banner, and compact boundary states.', 48, 88);
  ['Empty', 'Loading', 'Error', 'Retry Banner'].forEach((label, i) => {
    const x = 80 + (i % 2) * 410;
    const y = 240 + Math.floor(i / 2) * 220;
    rect(b, `State Card / ${label}`, x, y, 330, 170, C.raised, label === 'Error' ? C.error : C.border, 2);
    ellipse(b, `State Icon / ${label}`, x + 32, y + 34, 46, 46, label === 'Error' ? C.error : label === 'Loading' ? C.brand : C.dis, null);
    text(b, `State Title / ${label}`, label, x + 102, y + 36, 190, { size: 22, weight: 700 });
    text(b, `State Body / ${label}`, 'Message text and optional action.', x + 102, y + 78, 190, { size: 13, color: C.med });
  });
  return b;
}

function componentSkeletonBoard() {
  const b = board('COMPONENT - Skeletons', 0, 7800, 1440, 700);
  title(b, 'Skeletons', 48, 42);
  note(b, 'SkeletonLoader family states for rows, cards, avatars, and media placeholders.', 48, 88);
  for (let i = 0; i < 4; i++) {
    const x = 80 + i * 250;
    rect(b, `Skeleton Poster ${i + 1}`, x, 250, 150, 220, '#2A2A2A', null, 2);
    rect(b, `Skeleton Line A ${i + 1}`, x, 492, 180, 14, '#2A2A2A', null, 2);
    rect(b, `Skeleton Line B ${i + 1}`, x, 522, 110, 14, '#2A2A2A', null, 2);
  }
  ellipse(b, 'Skeleton Avatar Large', 1120, 280, 84, 84, '#2A2A2A', null);
  return b;
}

function componentTvControlsBoard() {
  const b = board('COMPONENT - TV Controls', 1600, 7800, 1440, 700);
  title(b, 'TV Controls', 48, 42);
  note(b, 'TV color-button legend and remote-friendly control affordances.', 48, 88);
  [['Red', C.live, 'Clear'], ['Green', C.green, 'Search'], ['Yellow', C.yellow, 'Sort'], ['Blue', C.blue, 'My List']].forEach(([name, color, label], i) => {
    const x = 80 + i * 250;
    ellipse(b, `TV Button / ${name}`, x, 270, 78, 78, color, C.high);
    text(b, `TV Button Letter / ${name}`, name[0], x + 27, 292, 40, { size: 30, weight: 700, color: name === 'Yellow' ? C.bg : C.high });
    text(b, `TV Button Label / ${name}`, label, x, 374, 160, { size: 20, weight: 700 });
  });
  rect(b, 'Focus Ring Example', 80, 520, 520, 70, 'transparent', C.high, 2);
  text(b, 'Focus Ring Label', 'Remote focus ring / selected action', 110, 542, 440, { size: 20, weight: 700 });
  return b;
}

function publish() {
  removeOldBoards();
  const tokenResult = populateTokens();
  if (penpot.currentPage) penpot.currentPage.name = 'CrispyTivi Design System';
  const widgetbookLinks = {
    'FOUNDATION - Tokens': '[Foundations]/Tokens',
    'COMPONENT - Core Components': '[Core widgets]/*',
    'COMPONENT - Buttons': '[Core widgets]/AsyncFilledButton',
    'COMPONENT - Badges': '[Core widgets]/LiveBadge + ContentStatusBadge',
    'COMPONENT - Chips': '[Core widgets]/MetaChip + GenrePillRow',
    'COMPONENT - Headers': '[Core widgets]/SectionHeader',
    'COMPONENT - Surfaces': '[Core widgets]/GlassSurface + GlassmorphicSheet',
    'COMPONENT - State Widgets': '[Core widgets]/Empty/Loading/Error',
    'COMPONENT - Skeletons': '[Core widgets]/SkeletonLoader',
    'COMPONENT - TV Controls': '[Core widgets]/TvColorButtonLegend',
    'COMPONENT - Media Cards': '[Core widgets]/GeneratedPlaceholder + WatchProgressBar + media overlays',
    'PATTERN - Navigation and TV Focus': '[Core navigation]/Navigation shell + [Core widgets]/TvMasterDetailLayout',
    'PATTERN - EPG Timeline': '[Feature fixtures]/EPG provider harness',
    'PATTERN - Player OSD': '[Player widgets]/OsdIconButton + subtitle controls',
    'SCREEN - Representative Layouts': '[Feature fixtures]/Home/Live TV/Settings/Multiview provider harnesses',
    'FEATURE - Live TV Widgets': '[Feature widgets]/ChannelListItem + ChannelGridItem',
    'FEATURE - Settings Widgets': '[Feature widgets]/SettingsBadge + SettingsCard',
    'FEATURE - VOD Widgets': '[Feature widgets]/QualityBadge + CircularAction + EpisodeTile + ExpandableSynopsis',
    'FEATURE - Player Widgets': '[Player widgets]/OsdIconButton + subtitle controls',
  };
  const boards = [
    foundations(),
    components(),
    mediaPatterns(),
    navigationPatterns(),
    epgPattern(),
    playerPattern(),
    screenTemplates(),
    featureWidgets(),
    settingsWidgets(),
    vodWidgets(),
    playerWidgets(),
    componentButtonBoard(),
    componentBadgeBoard(),
    componentChipBoard(),
    componentHeaderBoard(),
    componentSurfaceBoard(),
    componentStateBoard(),
    componentSkeletonBoard(),
    componentTvControlsBoard(),
  ];
  boards.forEach((b) => {
    b.setSharedPluginData('crispy-tivi', 'artifact', 'editable-design-system');
    b.setSharedPluginData('crispy-tivi', 'source', 'Flutter Crispy tokens + Widgetbook annotated use cases');
    b.setSharedPluginData('crispy-tivi', 'widgetbook', widgetbookLinks[b.name] || 'coverage-matrix');
  });
  return {
    status: 'published-editable-design-system',
    tokenSet: tokenResult,
    boards: boards.map((b) => b.name),
  };
}

return publish();
