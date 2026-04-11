/*
 * Verify CrispyTivi v2 app-overhaul Penpot page against the approved current design.
 *
 * This script is intentionally manifest-locked to the approved live Penpot file/page
 * so it cannot silently overwrite the current design with stale generated boards.
 *
 * Authority:
 * - design currently approved in Penpot file/page referenced by the product owner
 * - docs/overhaul/plans/v2-conversation-history-full-spec.md
 * - local reference images in design/reference-images/
 */

const EXPECTED_PAGE = {
  id: 'ec16cff3-941d-80ee-8007-d9645092a3ef',
  name: 'Page 1',
};

const EXPECTED_TOKEN_SET = {
  name: 'CrispyTivi vNext',
  count: 25,
};

const EXPECTED_BOARDS = [
  { name: 'FOUNDATION - vNext Tokens', x: 0, y: 0, width: 1440, height: 1040, children: 35 },
  { name: 'FOUNDATION - Layout and Windowing', x: 1600, y: 0, width: 1440, height: 1040, children: 18 },
  { name: 'COMPONENT - Navigation and Focus Controls', x: 3200, y: 0, width: 1440, height: 1040, children: 17 },
  { name: 'COMPONENT - Surfaces and Widget Feel', x: 0, y: 1120, width: 1440, height: 1040, children: 11 },
  { name: 'SCREEN - Home Shell', x: 1600, y: 1120, width: 1440, height: 1120, children: 53 },
  { name: 'SCREEN - Settings and Sources Flow', x: 3200, y: 1120, width: 1440, height: 1040, children: 38 },
  { name: 'SCREEN - Live TV Channels', x: 0, y: 2300, width: 1440, height: 1020, children: 34 },
  { name: 'SCREEN - Live TV Guide', x: 1600, y: 2300, width: 1440, height: 1020, children: 15 },
  { name: 'SCREEN - Media Browse and Detail', x: 3200, y: 2300, width: 1440, height: 1020, children: 59 },
  { name: 'SCREEN - Search and Handoff', x: 0, y: 3400, width: 1440, height: 900, children: 21 },
  { name: 'FEATURE - Source Selection and Health', x: 1600, y: 3400, width: 1440, height: 900, children: 22 },
  { name: 'FEATURE - Favorites, History, and Recommendations', x: 3200, y: 3400, width: 1440, height: 900, children: 17 },
  { name: 'FEATURE - Mock Player and Full Player Gate', x: 0, y: 4380, width: 1440, height: 900, children: 32 },
  { name: 'PATTERN - Left and Right Menus', x: 1600, y: 4380, width: 1440, height: 900, children: 32 },
];

function listCurrentBoards() {
  const page = penpot.currentPage;
  return (page?.root?.children || [])
    .filter((child) => child.type === 'board')
    .map((board) => ({
      name: board.name,
      x: board.x,
      y: board.y,
      width: board.width,
      height: board.height,
      children: board.children?.length || 0,
      artifact: board.getSharedPluginData?.('crispy-tivi', 'artifact') || null,
      source: board.getSharedPluginData?.('crispy-tivi', 'source') || null,
    }))
    .filter((board) => board.artifact === 'app-overhaul-design-system');
}

function tokenInfo() {
  const sets = penpot.library.local.tokens.sets || [];
  const set = sets.find((candidate) => candidate.name === EXPECTED_TOKEN_SET.name);
  return set
    ? { name: set.name, active: set.active, count: set.tokens?.length || 0 }
    : null;
}

function diffBoards(actualBoards) {
  const actualByName = new Map(actualBoards.map((board) => [board.name, board]));
  const missing = [];
  const mismatched = [];

  for (const expected of EXPECTED_BOARDS) {
    const actual = actualByName.get(expected.name);
    if (!actual) {
      missing.push(expected.name);
      continue;
    }
    const fields = ['x', 'y', 'width', 'height', 'children'];
    const delta = {};
    for (const field of fields) {
      if (actual[field] !== expected[field]) delta[field] = { expected: expected[field], actual: actual[field] };
    }
    if (Object.keys(delta).length > 0) mismatched.push({ name: expected.name, delta });
  }

  const unexpected = actualBoards
    .filter((board) => !EXPECTED_BOARDS.some((expected) => expected.name === board.name))
    .map((board) => board.name);

  return { missing, unexpected, mismatched };
}

function verifyApprovedDesign() {
  const currentPage = { id: penpot.currentPage?.id || null, name: penpot.currentPage?.name || null };
  const boards = listCurrentBoards();
  const tokenSet = tokenInfo();
  const boardDiff = diffBoards(boards);
  const aligned =
    currentPage.id === EXPECTED_PAGE.id &&
    currentPage.name === EXPECTED_PAGE.name &&
    tokenSet?.count === EXPECTED_TOKEN_SET.count &&
    boardDiff.missing.length === 0 &&
    boardDiff.unexpected.length === 0 &&
    boardDiff.mismatched.length === 0;

  return {
    status: aligned ? 'aligned-approved-current-design' : 'mismatch-approved-current-design',
    note: aligned
      ? 'Current Penpot app-overhaul page matches the approved manifest; no destructive regeneration was performed.'
      : 'Current Penpot app-overhaul page differs from the approved manifest. Regenerate scripts from the approved page before allowing destructive publish operations.',
    currentPage,
    expectedPage: EXPECTED_PAGE,
    tokenSet,
    expectedTokenSet: EXPECTED_TOKEN_SET,
    boardCount: boards.length,
    expectedBoardCount: EXPECTED_BOARDS.length,
    boardDiff,
    boards,
  };
}

return verifyApprovedDesign();
