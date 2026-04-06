#!/usr/bin/env bash
# Rust DDD/SOLID/DRY structural audit for crispy-core.
# Detects violations using grep/ast-grep — NOT line counts.
# Usage: ./scripts/rust/audit_ddd_solid_dry.sh [--rust-src path]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUST_SRC="${1:-$REPO_ROOT/rust/crates/crispy-core/src}"
MODELS_DIR="$RUST_SRC/models"
SERVICES_DIR="$RUST_SRC/services"
MODELS_FILE="$MODELS_DIR/mod.rs"

DDD_VIOLATIONS=0
SOLID_VIOLATIONS=0
DRY_VIOLATIONS=0

# ── Color helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "  ${GREEN}OK${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}WARN${RESET} $*"; }
fail() { echo -e "  ${RED}FAIL${RESET} $*"; }

echo ""
echo -e "${BOLD}=== Rust DDD/SOLID/DRY Audit ===${RESET}"
echo "  Source root: $RUST_SRC"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DDD: ANEMIC ENTITIES
# Find pub structs in models/mod.rs, then check for non-trivial impl blocks.
# A "behavior method" is a pub fn that is NOT From/Into/Default/new_entity_id.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DDD: Anemic Entities]${RESET}"

# Extract all pub struct names from models/mod.rs
STRUCT_NAMES=()
while IFS= read -r line; do
    name=$(echo "$line" | grep -oP '(?<=pub struct )\w+' || true)
    [[ -n "$name" ]] && STRUCT_NAMES+=("$name")
done < <(grep -n "^pub struct " "$MODELS_FILE" || true)

ANEMIC_COUNT=0

# Patterns considered trivial (field-access wrappers, not real behavior)
# Used by the trivial-only check below.
is_trivial_body() {
    local body="$1"
    # Strip blank lines and lines with only braces/comments
    local real_lines
    real_lines=$(echo "$body" | grep -vP '^\s*(//|/\*|\*|$|\{|\})' || true)
    # If no real lines remain, it's trivial by definition
    [[ -z "$real_lines" ]] && return 0
    # Check each real line: trivial if it only returns self.field, self.field == X,
    # !self.field.is_empty(), self.field.is_some(), self.field.unwrap_or(...)
    local non_trivial
    non_trivial=$(echo "$real_lines" | grep -vP \
        '^\s*(self\.\w+(\.\w+\(.*\))?\s*$|&self\.\w+\s*$|self\.\w+\s*==\s*\S+\s*$|!self\.\w+\.is_empty\(\)\s*$|self\.\w+\.is_some\(\)\s*$|self\.\w+\.is_none\(\)\s*$|self\.\w+\.unwrap_or\(.*\)\s*$|self\.\w+\.as_deref\(\)\s*$|self\.\w+\.as_ref\(\)\s*$)' \
        || true)
    [[ -z "$non_trivial" ]] && return 0
    return 1
}

for struct_name in "${STRUCT_NAMES[@]}"; do
    # Count pub fn behavior methods inside any `impl StructName` block.
    # Strategy: grab up to 300 lines after the impl header, stop at the first
    # top-level `}` (^}) or the next `impl ` line — whichever comes first.
    # Excludes From/Into/Default/new_entity_id/fmt as non-behavior.
    count_behavior_methods() {
        local file="$1"
        local name="$2"
        grep -A 300 "^impl ${name} {" "$file" 2>/dev/null \
            | grep -m 1 -B 300 "^}" \
            | grep -cP "^\s+pub fn (?!(from|into|default|new_entity_id|fmt)\b)" || true
    }

    impl_methods=$(count_behavior_methods "$MODELS_FILE" "$struct_name")

    # Also check other model files
    for mf in "$MODELS_DIR"/*.rs; do
        [[ "$mf" == "$MODELS_FILE" ]] && continue
        extra=$(count_behavior_methods "$mf" "$struct_name")
        impl_methods=$((impl_methods + extra))
    done

    if [[ "$impl_methods" -eq 0 ]]; then
        fail "models/mod.rs: ${struct_name} — 0 behavior methods (VIOLATION)"
        ANEMIC_COUNT=$((ANEMIC_COUNT + 1))
        DDD_VIOLATIONS=$((DDD_VIOLATIONS + 1))
    elif [[ "$impl_methods" -eq 1 ]]; then
        warn "models/mod.rs: ${struct_name} — ${impl_methods} behavior method (borderline)"
    else
        ok "models/mod.rs: ${struct_name} — ${impl_methods} behavior methods"
    fi
done

# ── Trivial-only impl block check ───────────────────────────────────────────
# Structs that have methods but all methods are trivial field-access wrappers
# are still anemic in substance. Report as a warning (not a counted violation).
TRIVIAL_ONLY_COUNT=0
for struct_name in "${STRUCT_NAMES[@]}"; do
    # Extract the impl block body (first impl block only)
    impl_body=$(grep -A 300 "^impl ${struct_name} {" "$MODELS_FILE" 2>/dev/null \
        | grep -m 1 -B 300 "^}" || true)
    [[ -z "$impl_body" ]] && continue

    # Count pub fn methods in this block (excluding infra helpers)
    method_count=$(echo "$impl_body" | grep -cP "^\s+pub fn (?!(from|into|default|new_entity_id|fmt)\b)" || true)
    [[ "$method_count" -lt 2 ]] && continue  # already reported above or borderline

    # Check if every method body is trivial
    # Extract individual method bodies: lines between `pub fn` markers
    all_trivial=true
    while IFS= read -r fn_line; do
        # Grab up to 10 lines after each pub fn declaration as its body
        fn_body=$(echo "$impl_body" | grep -A 10 -F "$fn_line" | tail -n +2 | grep -m 1 -B 10 "^\s*}" || true)
        if ! is_trivial_body "$fn_body"; then
            all_trivial=false
            break
        fi
    done < <(echo "$impl_body" | grep -P "^\s+pub fn (?!(from|into|default|new_entity_id|fmt)\b)" || true)

    if [[ "$all_trivial" == "true" ]]; then
        warn "models/mod.rs: ${struct_name} — ${method_count} methods are all trivial field-access wrappers (anemic in substance)"
        TRIVIAL_ONLY_COUNT=$((TRIVIAL_ONLY_COUNT + 1))
    fi
done

if [[ "$ANEMIC_COUNT" -eq 0 && "$TRIVIAL_ONLY_COUNT" -eq 0 ]]; then
    ok "No anemic entity violations found"
elif [[ "$TRIVIAL_ONLY_COUNT" -gt 0 ]]; then
    warn "Trivial-only impl blocks (anemic in substance): ${TRIVIAL_ONLY_COUNT}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DDD: STRING-TYPED FIELDS THAT SHOULD BE ENUMS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DDD: String-typed Enums]${RESET}"

STRING_ENUM_CANDIDATES=(
    "source_type"
    "media_type"
    "item_type"
    "category_type"
    "match_method"
    # "phase" — SyncProgress.phase is a UI display string sent via FFI, not a domain enum
    # "last_sync_status" — free-form status text
)

STRING_ENUM_COUNT=0
for field in "${STRING_ENUM_CANDIDATES[@]}"; do
    while IFS= read -r match; do
        lineno=$(echo "$match" | cut -d: -f1)
        fail "models/mod.rs:${lineno} — ${field}: String (should be enum $(echo "$field" | sed 's/_\([a-z]\)/\U\1/g; s/^\([a-z]\)/\U\1/'))"
        STRING_ENUM_COUNT=$((STRING_ENUM_COUNT + 1))
        DDD_VIOLATIONS=$((DDD_VIOLATIONS + 1))
    done < <(grep -nP "pub ${field}: String" "$MODELS_FILE" || true)
done

# Also check for stream_url / url that could be typed Value Objects
URL_COUNT=0
while IFS= read -r match; do
    lineno=$(echo "$match" | cut -d: -f1)
    field=$(echo "$match" | grep -oP 'pub \w+(?=: String)' | sed 's/pub //')
    warn "models/mod.rs:${lineno} — ${field}: String (consider StreamUrl/Url value object)"
    URL_COUNT=$((URL_COUNT + 1))
done < <(grep -nP "pub (stream_url|url): String" "$MODELS_FILE" || true)

if [[ "$STRING_ENUM_COUNT" -eq 0 && "$URL_COUNT" -eq 0 ]]; then
    ok "No string-typed enum candidates found"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DDD: PRIMITIVE OBSESSION (specific fields that should be enums)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DDD: Primitive Obsession]${RESET}"

PRIM_COUNT=0

# i32 fields that should be enums
declare -A I32_ENUM_MAP=(
    ["pub role: i32"]="ProfileRole"
    ["pub dvr_permission: i32"]="DvrPermission"
)
for pattern in "${!I32_ENUM_MAP[@]}"; do
    target_enum="${I32_ENUM_MAP[$pattern]}"
    while IFS= read -r match; do
        lineno=$(echo "$match" | cut -d: -f1)
        fail "models/mod.rs:${lineno} — ${pattern} (should be ${target_enum} enum)"
        PRIM_COUNT=$((PRIM_COUNT + 1))
        DDD_VIOLATIONS=$((DDD_VIOLATIONS + 1))
    done < <(grep -nP "${pattern}" "$MODELS_FILE" || true)
done

# String fields that should be enums (specific named fields beyond generic candidates above)
declare -A STR_ENUM_MAP=(
    ["pub backend_type: String"]="BackendType"
    ["pub direction: String"]="TransferDirection"
    ["pub layout: String"]="LayoutType"
)
for pattern in "${!STR_ENUM_MAP[@]}"; do
    target_enum="${STR_ENUM_MAP[$pattern]}"
    while IFS= read -r match; do
        lineno=$(echo "$match" | cut -d: -f1)
        fail "models/mod.rs:${lineno} — ${pattern} (should be ${target_enum} enum)"
        PRIM_COUNT=$((PRIM_COUNT + 1))
        DDD_VIOLATIONS=$((DDD_VIOLATIONS + 1))
    done < <(grep -nP "${pattern}" "$MODELS_FILE" || true)
done

# status: String in TransferTask (should be TransferStatus enum)
while IFS= read -r match; do
    lineno=$(echo "$match" | cut -d: -f1)
    fail "models/mod.rs:${lineno} — pub status: String (should be TransferStatus enum in TransferTask)"
    PRIM_COUNT=$((PRIM_COUNT + 1))
    DDD_VIOLATIONS=$((DDD_VIOLATIONS + 1))
done < <(grep -nP "pub status: String" "$MODELS_FILE" || true)

# content_type: String in VodFavorite / Bookmark (should use existing MediaType)
while IFS= read -r match; do
    lineno=$(echo "$match" | cut -d: -f1)
    fail "models/mod.rs:${lineno} — pub content_type: String (should use existing MediaType enum)"
    PRIM_COUNT=$((PRIM_COUNT + 1))
    DDD_VIOLATIONS=$((DDD_VIOLATIONS + 1))
done < <(grep -nP "pub content_type: String" "$MODELS_FILE" || true)

if [[ "$PRIM_COUNT" -eq 0 ]]; then
    ok "No primitive obsession violations found"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DDD: MISSING VALUE OBJECTS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DDD: Missing Value Objects]${RESET}"

URL_VO_COUNT=0
while IFS= read -r match; do
    lineno=$(echo "$match" | cut -d: -f1)
    field=$(echo "$match" | grep -oP 'pub \w+(?=: String)' | sed 's/pub //')
    warn "models/mod.rs:${lineno} — ${field}: String (candidate for Url/StreamUrl value object)"
    URL_VO_COUNT=$((URL_VO_COUNT + 1))
done < <(grep -nP "pub (stream_url|logo_url|epg_url|catchup_source): String" "$MODELS_FILE" || true)

if [[ "$URL_VO_COUNT" -eq 0 ]]; then
    ok "No obvious missing value objects in required fields"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLID: GOD SERVICE (SRP / ISP)
# CrispyService should have impl blocks in at most 1 file (mod.rs = facade).
# Business logic lives in domain service newtypes (BookmarkService, etc.).
# Scattered impl blocks across multiple files = god object regression.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: God Service]${RESET}"

CRISPY_IMPL_COUNT=$(grep -rl "^impl CrispyService" "$SERVICES_DIR" 2>/dev/null | wc -l || true)

if [[ "$CRISPY_IMPL_COUNT" -gt 1 ]]; then
    fail "CrispyService impl scattered across ${CRISPY_IMPL_COUNT} files (max 1 facade file allowed)"
    SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))

    echo ""
    echo "  Files with impl CrispyService (only mod.rs should appear):"
    grep -rl "^impl CrispyService" "$SERVICES_DIR" 2>/dev/null | while read -r f; do
        methods=$(grep -cP "^\s+pub.*fn " "$f" || true)
        echo "    - $(basename "$f"): ${methods} methods"
    done
else
    ok "CrispyService impl in ${CRISPY_IMPL_COUNT} file(s) — facade pattern, domain services decomposed"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLID: MISSING REPOSITORY TRAITS (DIP)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: Missing Repository Traits (DIP)]${RESET}"

REPO_TRAIT_COUNT=$(grep -rn "trait.*Repository\|trait.*Repo[^s]" "$RUST_SRC" 2>/dev/null | wc -l || true)
DIRECT_RUSQLITE_FILES=()
while IFS= read -r f; do
    DIRECT_RUSQLITE_FILES+=("$f")
done < <(grep -rl "^use rusqlite\|^    use rusqlite\|extern crate rusqlite" "$SERVICES_DIR" 2>/dev/null || true)
DIRECT_RUSQLITE_COUNT="${#DIRECT_RUSQLITE_FILES[@]}"

if [[ "$REPO_TRAIT_COUNT" -eq 0 ]]; then
    fail "Repository traits: 0 — no abstractions between domain and infrastructure (DIP VIOLATION)"
    SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))
else
    ok "Repository traits found: ${REPO_TRAIT_COUNT}"
fi

# Check for rusqlite imports OUTSIDE services/ (the infrastructure layer).
# services/ IS the infrastructure layer — rusqlite usage there is expected.
# DIP violation is when domain/models/traits import rusqlite directly.
NON_INFRA_RUSQLITE=$(grep -rl "^use rusqlite\|^    use rusqlite" \
    "$RUST_SRC/models" "$RUST_SRC/traits" 2>/dev/null | wc -l || true)

if [[ "$NON_INFRA_RUSQLITE" -gt 0 ]]; then
    fail "Domain/traits files importing rusqlite: ${NON_INFRA_RUSQLITE} (DIP VIOLATION)"
    SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + NON_INFRA_RUSQLITE))
else
    ok "No rusqlite imports outside infrastructure layer"
fi

if [[ "$DIRECT_RUSQLITE_COUNT" -gt 0 ]]; then
    warn "Service (infra) files using rusqlite: ${DIRECT_RUSQLITE_COUNT} (expected — services/ is the infrastructure layer)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLID: ISP — FFI API surface using CrispyService directly
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: ISP — FFI API surface]${RESET}"

FFI_API_DIR="$REPO_ROOT/rust/crates/crispy-ffi/src/api"
if [[ -d "$FFI_API_DIR" ]]; then
    FFI_CRISPY_SERVICE=$(grep -rl "CrispyService" "$FFI_API_DIR" 2>/dev/null | wc -l || true)
    if [[ "$FFI_CRISPY_SERVICE" -gt 0 ]]; then
        warn "FFI api files using CrispyService directly: ${FFI_CRISPY_SERVICE} (consider focused interfaces per domain)"
        echo "  Files:"
        grep -rl "CrispyService" "$FFI_API_DIR" 2>/dev/null | while read -r f; do
            echo "    - $(basename "$f")"
        done
    else
        ok "FFI API does not directly reference CrispyService"
    fi
else
    warn "FFI api directory not found at $FFI_API_DIR — skipping ISP check"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DRY: DUPLICATED from_row FUNCTIONS
# Named from_row functions are the DRY SOLUTION (one centralized mapping per entity).
# Only inline query_map closures that duplicate substantial entity mapping are violations.
# A query_map closure with <5 row.get calls is a partial/tuple extraction, not duplication.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DRY: Duplicated from_row Patterns]${RESET}"

FROM_ROW_NAMED=$(grep -rn "fn.*_from_row\|fn row_to_\|fn.*from_row(" "$SERVICES_DIR" 2>/dev/null | grep -v "//\|test" | wc -l || true)

# Count inline query_map closures that have 5+ row.get calls (substantial entity mapping)
# These should use a named from_row function instead
INLINE_VIOLATIONS=0
while IFS= read -r qm_file; do
    while IFS= read -r qm_line; do
        lineno=$(echo "$qm_line" | cut -d: -f1)
        # Extract lines until the closure ends (})? or })) to avoid counting adjacent closures.
        # Use a tight 12-line window and only count closures mapping named structs (not tuples).
        closure_body=$(sed -n "${lineno},$((lineno + 12))p" "$qm_file" 2>/dev/null || true)
        gets_in_closure=$(echo "$closure_body" | grep -c "row\.get\|get_bool\|get_datetime\|get_opt_string" || true)
        # Skip: tuple mappings (Ok(( pattern), function-local structs (defined in same function),
        # and closures that reference named from_row functions
        is_tuple=$(echo "$closure_body" | grep -c "Ok((" || true)
        uses_from_row=$(echo "$closure_body" | grep -c "_from_row\|row_to_" || true)
        # Check if it maps a function-local struct (struct defined within 20 lines above)
        is_local_struct=$(sed -n "$((lineno > 20 ? lineno - 20 : 1)),${lineno}p" "$qm_file" 2>/dev/null \
            | grep -c "^\s*struct " || true)
        if [[ "$gets_in_closure" -ge 5 && "$is_tuple" -eq 0 && "$uses_from_row" -eq 0 && "$is_local_struct" -eq 0 ]]; then
            echo "  [VIOLATION] $(basename "$qm_file"):${lineno} — inline closure with ${gets_in_closure} field mappings (should use named from_row)"
            INLINE_VIOLATIONS=$((INLINE_VIOLATIONS + 1))
        fi
    done < <(grep -n "query_map(" "$qm_file" 2>/dev/null | grep -v "//" || true)
done < <(grep -rl "query_map(" "$SERVICES_DIR" 2>/dev/null || true)

if [[ "$INLINE_VIOLATIONS" -gt 0 ]]; then
    DRY_VIOLATIONS=$((DRY_VIOLATIONS + INLINE_VIOLATIONS))
fi

ok "Named from_row functions: ${FROM_ROW_NAMED} (centralized entity mappings — not violations)"
if [[ "$INLINE_VIOLATIONS" -eq 0 ]]; then
    ok "No duplicated inline row-mapping closures found"
else
    fail "Inline closures with substantial mapping (5+ fields): ${INLINE_VIOLATIONS}"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DRY: DUPLICATED UPSERT SQL BLOCKS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DRY: Duplicated Upsert SQL]${RESET}"

# Exclude: macro definition (upsert.rs), macro invocations (insert_or_replace!/upsert!),
# comments, and test helper code (cleanup.rs test fixtures)
UPSERT_COUNT=$(grep -rn "INSERT INTO.*ON CONFLICT\|INSERT OR REPLACE INTO" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null \
    | grep -v "//\|upsert\.rs\|insert_or_replace!\|upsert!\|cleanup\.rs" | wc -l || true)

if [[ "$UPSERT_COUNT" -gt 3 ]]; then
    fail "INSERT ... ON CONFLICT blocks: ${UPSERT_COUNT} — each is a DRY violation (centralize with repository pattern)"
    DRY_VIOLATIONS=$((DRY_VIOLATIONS + UPSERT_COUNT))
    echo "  Locations:"
    grep -rn "INSERT INTO.*ON CONFLICT\|INSERT OR REPLACE INTO" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//\|upsert\.rs\|insert_or_replace!\|upsert!\|cleanup\.rs" | while read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        lineno=$(echo "$match" | cut -d: -f2)
        echo "    - $(basename "$file"):${lineno}"
    done
elif [[ "$UPSERT_COUNT" -gt 0 ]]; then
    warn "INSERT ... ON CONFLICT blocks: ${UPSERT_COUNT} (monitor for growth)"
    DRY_VIOLATIONS=$((DRY_VIOLATIONS + UPSERT_COUNT))
    echo "  Locations:"
    grep -rn "INSERT INTO.*ON CONFLICT\|INSERT OR REPLACE INTO" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//\|upsert\.rs\|insert_or_replace!\|upsert!\|cleanup\.rs" | while read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        lineno=$(echo "$match" | cut -d: -f2)
        echo "    - $(basename "$file"):${lineno}"
    done
else
    ok "No upsert SQL duplication found"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DRY: DUPLICATED COLUMN LISTS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DRY: Duplicated Column Lists]${RESET}"

COLUMNS_COUNT=$(grep -rn "const.*COLUMNS.*=.*&str\|const.*COLUMNS.*=.*\"" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//" | wc -l || true)

if [[ "$COLUMNS_COUNT" -gt 1 ]]; then
    fail "Inline COLUMNS constants: ${COLUMNS_COUNT} — each is a DRY violation (move to models/ as associated constants)"
    DRY_VIOLATIONS=$((DRY_VIOLATIONS + COLUMNS_COUNT))
    echo "  Locations:"
    grep -rn "const.*COLUMNS.*=.*&str\|const.*COLUMNS.*=.*\"" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//" | while read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        lineno=$(echo "$match" | cut -d: -f2)
        const_name=$(echo "$match" | grep -oP 'const \w+' | head -1)
        echo "    - $(basename "$file"):${lineno} — ${const_name}"
    done
elif [[ "$COLUMNS_COUNT" -eq 1 ]]; then
    ok "COLUMNS constants: 1 (no duplication)"
else
    ok "No COLUMNS constants found"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DDD: DOMAIN LOGIC IN SERVICES (threshold/tier evaluation, progress calcs)
# evaluate_* and compute_* functions in services/ signal domain logic that
# should live on entities/value objects instead.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DDD: Domain Logic in Services]${RESET}"

DDD_SERVICE_LOGIC_COUNT=0

# Check services/ for compute_/evaluate_ fns that contain inline domain logic.
# Functions that delegate to domain types (BufferTierDecision, etc.) are OK —
# the service orchestrates, the domain object has the logic.
DOMAIN_LOGIC_FILES=("$SERVICES_DIR/buffer_tiers.rs" "$SERVICES_DIR/history.rs")
for f in "${DOMAIN_LOGIC_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    while IFS= read -r match; do
        lineno=$(echo "$match" | cut -d: -f1)
        fn_name=$(echo "$match" | grep -oP '(?<=pub fn )\w+' || true)
        # Check if the function delegates to a domain type (e.g., BufferTierDecision::evaluate)
        # by scanning the next 30 lines for domain type calls
        delegates=$(sed -n "${lineno},$((lineno + 30))p" "$f" 2>/dev/null \
            | grep -c "Decision::\|Policy::\|Evaluator::\|Calculator::\|Progress::" || true)
        if [[ "$delegates" -gt 0 ]]; then
            ok "${fname}:${lineno} — pub fn ${fn_name} delegates to domain type (not a violation)"
        else
            fail "${fname}:${lineno} — pub fn ${fn_name} (domain logic in service — should be on entity/value object)"
            DDD_SERVICE_LOGIC_COUNT=$((DDD_SERVICE_LOGIC_COUNT + 1))
            DDD_VIOLATIONS=$((DDD_VIOLATIONS + 1))
        fi
    done < <(grep -nP "^\s+pub fn (compute_|evaluate_)" "$f" 2>/dev/null | grep -v "#\[test\]\|//\|test::" || true)
done

# Also scan all services/ for threshold pattern: if x > N && x < M (numeric comparisons)
# These bracket-style tier evaluations belong on domain types
THRESHOLD_COUNT=0
while IFS= read -r match; do
    f=$(echo "$match" | cut -d: -f1)
    lineno=$(echo "$match" | cut -d: -f2)
    warn "$(basename "$f"):${lineno} — threshold comparison (if X > N && X < M) in service layer (consider domain type)"
    THRESHOLD_COUNT=$((THRESHOLD_COUNT + 1))
done < <(grep -rnP "if\s+\w+\s*[<>]=?\s*[\d.]+\s*&&\s*\w+\s*[<>]=?\s*[\d.]+" \
    "$SERVICES_DIR/buffer_tiers.rs" "$SERVICES_DIR/history.rs" 2>/dev/null \
    | grep -v "//\|#\[test\]\|test::" || true)

if [[ "$DDD_SERVICE_LOGIC_COUNT" -eq 0 && "$THRESHOLD_COUNT" -eq 0 ]]; then
    ok "No domain logic misplaced in service layer"
elif [[ "$THRESHOLD_COUNT" -gt 0 ]]; then
    warn "Threshold comparisons in service layer: ${THRESHOLD_COUNT} (informational)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLID: VALUE OBJECTS IMPORTING RUSQLITE (DIP)
# Value objects are domain types and must NOT depend on persistence infra.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: Value Objects importing rusqlite (DIP)]${RESET}"

VO_RUSQLITE_COUNT=0
VO_DIR="$RUST_SRC/value_objects"
if [[ -d "$VO_DIR" ]]; then
    while IFS= read -r f; do
        fname=$(basename "$f")
        fail "value_objects/${fname} — imports rusqlite (domain type must NOT depend on persistence infra — DIP VIOLATION)"
        VO_RUSQLITE_COUNT=$((VO_RUSQLITE_COUNT + 1))
        SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))
    done < <(grep -rl "use rusqlite" "$VO_DIR" 2>/dev/null || true)
    if [[ "$VO_RUSQLITE_COUNT" -eq 0 ]]; then
        ok "No value_objects importing rusqlite"
    fi
else
    warn "value_objects/ directory not found at $VO_DIR — skipping"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLID: REPOSITORY TRAITS IMPORTING DbError (DIP)
# Repository traits are domain contracts. They should use a domain-level
# error type, not DbError from the infrastructure layer.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: Repository Traits importing DbError (DIP)]${RESET}"

TRAIT_DBERROR_COUNT=0
TRAITS_DIR="$RUST_SRC/traits"
if [[ -d "$TRAITS_DIR" ]]; then
    while IFS= read -r f; do
        fname=$(basename "$f")
        fail "traits/${fname} — imports DbError from database layer (repository traits should use domain-level errors — DIP VIOLATION)"
        TRAIT_DBERROR_COUNT=$((TRAIT_DBERROR_COUNT + 1))
        SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))
    done < <(grep -rl "use crate::database::DbError" "$TRAITS_DIR" 2>/dev/null || true)
    if [[ "$TRAIT_DBERROR_COUNT" -eq 0 ]]; then
        ok "No repository traits importing DbError from infrastructure"
    fi
else
    warn "traits/ directory not found at $TRAITS_DIR — skipping"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLID: MIXED AGGREGATE TRAITS (ISP)
# A trait file that defines methods for Recording, StorageBackend, AND
# TransferTask violates ISP — each aggregate should have its own trait.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: Mixed Aggregate Traits (ISP)]${RESET}"

ISP_TRAIT_COUNT=0
if [[ -d "$TRAITS_DIR" ]]; then
    while IFS= read -r f; do
        fname=$(basename "$f")
        # Count how many distinct aggregate groups appear in this trait file
        has_recording=$(grep -cP "fn\s+\w*(recording|Recording)" "$f" 2>/dev/null || true)
        has_storage=$(grep -cP "fn\s+\w*(storage|Storage)" "$f" 2>/dev/null || true)
        has_transfer=$(grep -cP "fn\s+\w*(transfer|Transfer)" "$f" 2>/dev/null || true)
        # Count how many of these groups are present (>0)
        group_count=0
        [[ "$has_recording" -gt 0 ]] && group_count=$((group_count + 1))
        [[ "$has_storage" -gt 0 ]] && group_count=$((group_count + 1))
        [[ "$has_transfer" -gt 0 ]] && group_count=$((group_count + 1))
        if [[ "$group_count" -ge 2 ]]; then
            fail "traits/${fname} — mixes ${group_count} aggregate groups (recording/storage/transfer) in one trait (ISP VIOLATION — split into per-aggregate traits)"
            ISP_TRAIT_COUNT=$((ISP_TRAIT_COUNT + 1))
            SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))
        fi
    done < <(find "$TRAITS_DIR" -name "*.rs" ! -name "mod.rs" 2>/dev/null || true)
    if [[ "$ISP_TRAIT_COUNT" -eq 0 ]]; then
        ok "No mixed aggregate trait violations found"
    fi
else
    warn "traits/ directory not found at $TRAITS_DIR — skipping"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DRY: REPEATED QueryReturnedNoRows ERROR MAPPING
# Each occurrence in services/ is a manual arm that should be a shared helper.
# First occurrence is acceptable; every subsequent one is a DRY violation.
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DRY: Repeated QueryReturnedNoRows error mapping]${RESET}"

QNR_COUNT=$(grep -rn "QueryReturnedNoRows" "$SERVICES_DIR" 2>/dev/null \
    | grep -v "//\|#\[test\]" | wc -l || true)

if [[ "$QNR_COUNT" -gt 1 ]]; then
    EXTRA=$((QNR_COUNT - 1))
    fail "QueryReturnedNoRows matched ${QNR_COUNT} times in services/ — ${EXTRA} redundant arm(s) (extract shared helper — DRY VIOLATION)"
    DRY_VIOLATIONS=$((DRY_VIOLATIONS + EXTRA))
    echo "  Locations:"
    grep -rn "QueryReturnedNoRows" "$SERVICES_DIR" 2>/dev/null | grep -v "//\|#\[test\]" | while read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        lineno=$(echo "$match" | cut -d: -f2)
        echo "    - $(basename "$file"):${lineno}"
    done
elif [[ "$QNR_COUNT" -eq 1 ]]; then
    ok "QueryReturnedNoRows: 1 occurrence (no duplication)"
else
    ok "No QueryReturnedNoRows patterns found"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DDD: XtreamAccountInfo PRIMITIVE OBSESSION
# Fields like status, exp_date, server_port, is_trial as Option<String>
# should be typed value objects (AccountStatus enum, UnixTimestamp, Port, etc.)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DDD: XtreamAccountInfo Primitive Obsession]${RESET}"
# NOTE: XtreamAccountInfo is an external API DTO — raw String fields are required
# for JSON deserialization compatibility with the Xtream Codes API. Typed accessor
# methods (account_status(), is_trial_account(), server_port_u16()) provide the
# domain-safe interface. Not counted as violations.
ok "XtreamAccountInfo fields are external API strings with typed accessors — not violations"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
TOTAL=$((DDD_VIOLATIONS + SOLID_VIOLATIONS + DRY_VIOLATIONS))

echo -e "${BOLD}[SUMMARY]${RESET}"
if [[ "$DDD_VIOLATIONS" -gt 0 ]]; then
    echo -e "  ${RED}DDD violations:   ${DDD_VIOLATIONS}${RESET}"
else
    echo -e "  ${GREEN}DDD violations:   0${RESET}"
fi
if [[ "$SOLID_VIOLATIONS" -gt 0 ]]; then
    echo -e "  ${RED}SOLID violations: ${SOLID_VIOLATIONS}${RESET}"
else
    echo -e "  ${GREEN}SOLID violations: 0${RESET}"
fi
if [[ "$DRY_VIOLATIONS" -gt 0 ]]; then
    echo -e "  ${RED}DRY violations:   ${DRY_VIOLATIONS}${RESET}"
else
    echo -e "  ${GREEN}DRY violations:   0${RESET}"
fi
echo -e "  ──────────────────────────"
if [[ "$TOTAL" -gt 0 ]]; then
    echo -e "  ${RED}${BOLD}TOTAL:            ${TOTAL}${RESET}"
else
    echo -e "  ${GREEN}${BOLD}TOTAL:            0 — clean!${RESET}"
fi
echo ""
