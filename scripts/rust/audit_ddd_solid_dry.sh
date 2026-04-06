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

if [[ "$ANEMIC_COUNT" -eq 0 ]]; then
    ok "No anemic entity violations found"
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
    "phase"
    "last_sync_status"
)

STRING_ENUM_COUNT=0
for field in "${STRING_ENUM_CANDIDATES[@]}"; do
    while IFS= read -r match; do
        lineno=$(echo "$match" | cut -d: -f1)
        content=$(echo "$match" | cut -d: -f2-)
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
# Count distinct files containing `impl CrispyService`
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: God Service]${RESET}"

CRISPY_IMPL_COUNT=$(grep -rl "^impl CrispyService" "$SERVICES_DIR" 2>/dev/null | wc -l || true)
CRISPY_IMPL_METHODS=$(grep -rh "^\s*pub.*fn " "$SERVICES_DIR" 2>/dev/null \
    | grep -v "//\|#\[" | wc -l || true)

if [[ "$CRISPY_IMPL_COUNT" -gt 0 ]]; then
    fail "CrispyService impl blocks across files: ${CRISPY_IMPL_COUNT} (target: 0 — split into domain services)"
    fail "Estimated CrispyService methods: ~${CRISPY_IMPL_METHODS} (all in one god struct)"
    SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))

    echo ""
    echo "  Files with impl CrispyService:"
    grep -rl "^impl CrispyService" "$SERVICES_DIR" 2>/dev/null | while read -r f; do
        methods=$(grep -cP "^\s+pub.*fn " "$f" || true)
        echo "    - $(basename "$f"): ${methods} methods"
    done
else
    ok "No god service violations (CrispyService not found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLID: MISSING REPOSITORY TRAITS (DIP)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SOLID: Missing Repository Traits (DIP)]${RESET}"

REPO_TRAIT_COUNT=$(grep -rn "trait.*Repository\|trait.*Repo[^s]" "$RUST_SRC" 2>/dev/null | wc -l || true)
DIRECT_RUSQLITE_COUNT=$(grep -rl "^use rusqlite\|^    use rusqlite\|extern crate rusqlite" "$SERVICES_DIR" 2>/dev/null | wc -l || true)

if [[ "$REPO_TRAIT_COUNT" -eq 0 ]]; then
    fail "Repository traits found: 0 (target: 6+ — one per aggregate: Channel, VodItem, Source, Profile, EpgEntry, etc.)"
    SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))
else
    ok "Repository traits found: ${REPO_TRAIT_COUNT}"
fi

if [[ "$DIRECT_RUSQLITE_COUNT" -gt 0 ]]; then
    fail "Service files importing rusqlite directly: ${DIRECT_RUSQLITE_COUNT} (target: 0 — use repository abstractions)"
    SOLID_VIOLATIONS=$((SOLID_VIOLATIONS + 1))
    echo "  Violating files:"
    grep -rl "^use rusqlite\|^    use rusqlite\|extern crate rusqlite" "$SERVICES_DIR" 2>/dev/null | while read -r f; do
        echo "    - $(basename "$f")"
    done
else
    ok "No services import rusqlite directly"
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
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DRY: Duplicated from_row Patterns]${RESET}"

FROM_ROW_COUNT=$(grep -rn "fn.*_from_row\|fn row_to_\|fn.*from_row(" "$SERVICES_DIR" 2>/dev/null | grep -v "//\|test" | wc -l || true)

if [[ "$FROM_ROW_COUNT" -gt 1 ]]; then
    fail "from_row functions: ${FROM_ROW_COUNT} (target: 1 macro or trait impl — e.g. impl FromRow for T)"
    DRY_VIOLATIONS=$((DRY_VIOLATIONS + 1))
    echo "  Locations:"
    grep -rn "fn.*_from_row\|fn row_to_\|fn.*from_row(" "$SERVICES_DIR" 2>/dev/null | grep -v "//" | while read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        lineno=$(echo "$match" | cut -d: -f2)
        fn_name=$(echo "$match" | grep -oP 'fn \w+' | head -1)
        echo "    - $(basename "$file"):${lineno} — ${fn_name}"
    done
else
    ok "from_row functions: ${FROM_ROW_COUNT} (no duplication)"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# DRY: DUPLICATED UPSERT SQL BLOCKS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[DRY: Duplicated Upsert SQL]${RESET}"

UPSERT_COUNT=$(grep -rn "INSERT INTO.*ON CONFLICT\|INSERT OR REPLACE INTO" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//" | wc -l || true)

if [[ "$UPSERT_COUNT" -gt 3 ]]; then
    fail "INSERT ... ON CONFLICT (upsert) blocks: ${UPSERT_COUNT} (target: centralized — consider a macro or generic upsert fn)"
    DRY_VIOLATIONS=$((DRY_VIOLATIONS + 1))
    echo "  Locations:"
    grep -rn "INSERT INTO.*ON CONFLICT\|INSERT OR REPLACE INTO" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//" | while read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        lineno=$(echo "$match" | cut -d: -f2)
        echo "    - $(basename "$file"):${lineno}"
    done
elif [[ "$UPSERT_COUNT" -gt 0 ]]; then
    warn "INSERT ... ON CONFLICT blocks: ${UPSERT_COUNT} (acceptable, monitor for growth)"
    echo "  Locations:"
    grep -rn "INSERT INTO.*ON CONFLICT\|INSERT OR REPLACE INTO" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//" | while read -r match; do
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
    warn "Inline COLUMNS constants: ${COLUMNS_COUNT} (consider moving to models/ as associated constants)"
    echo "  Locations:"
    grep -rn "const.*COLUMNS.*=.*&str\|const.*COLUMNS.*=.*\"" "$SERVICES_DIR" "$RUST_SRC/database" 2>/dev/null | grep -v "//" | while read -r match; do
        file=$(echo "$match" | cut -d: -f1)
        lineno=$(echo "$match" | cut -d: -f2)
        const_name=$(echo "$match" | grep -oP 'const \w+' | head -1)
        echo "    - $(basename "$file"):${lineno} — ${const_name}"
    done
else
    ok "COLUMNS constants: ${COLUMNS_COUNT} (no duplication)"
fi
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
