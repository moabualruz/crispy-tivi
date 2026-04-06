#!/usr/bin/env bash
# Finds anemic domain entities in models/ — structs with no behavior methods.
#
# An "anemic" entity is a pub struct that has either:
#   - no impl block at all, OR
#   - only derived/conversion methods (From, Into, Default, new_entity_id)
#
# Uses ast-grep when available, falls back to grep-based analysis.
#
# Usage: ./scripts/rust/find_anemic_entities.sh [--rust-src path]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUST_SRC="${1:-$REPO_ROOT/rust/crates/crispy-core/src}"
MODELS_DIR="$RUST_SRC/models"
MODELS_FILE="$MODELS_DIR/mod.rs"

BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}=== Anemic Entity Finder ===${RESET}"
echo "  Models dir: $MODELS_DIR"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Check for ast-grep
# ─────────────────────────────────────────────────────────────────────────────
USE_AST_GREP=false
if command -v ast-grep &>/dev/null; then
    USE_AST_GREP=true
    echo -e "  ${CYAN}ast-grep detected — using structural analysis${RESET}"
else
    echo -e "  ${YELLOW}ast-grep not found — using grep-based analysis${RESET}"
    echo "  Install: cargo install ast-grep  OR  npm install -g @ast-grep/cli"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Collect all public struct names from models/mod.rs and other model files
# ─────────────────────────────────────────────────────────────────────────────
declare -A STRUCT_FILES  # struct_name -> file path

while IFS= read -r line; do
    name=$(echo "$line" | grep -oP '(?<=pub struct )\w+' || true)
    [[ -n "$name" ]] && STRUCT_FILES["$name"]="$MODELS_FILE"
done < <(grep -n "^pub struct " "$MODELS_FILE" 2>/dev/null || true)

for mf in "$MODELS_DIR"/*.rs; do
    [[ "$mf" == "$MODELS_FILE" ]] && continue
    [[ ! -f "$mf" ]] && continue
    while IFS= read -r line; do
        name=$(echo "$line" | grep -oP '(?<=pub struct )\w+' || true)
        [[ -n "$name" ]] && STRUCT_FILES["$name"]="$mf"
    done < <(grep -n "^pub struct " "$mf" 2>/dev/null || true)
done

TOTAL_STRUCTS=${#STRUCT_FILES[@]}
ANEMIC_STRUCTS=()
RICH_STRUCTS=()
BORDERLINE_STRUCTS=()

echo -e "${BOLD}Analyzing ${TOTAL_STRUCTS} structs...${RESET}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Analyze each struct
# ─────────────────────────────────────────────────────────────────────────────
for struct_name in $(echo "${!STRUCT_FILES[@]}" | tr ' ' '\n' | sort); do
    src_file="${STRUCT_FILES[$struct_name]}"
    behavior_count=0
    conversion_count=0

    if $USE_AST_GREP; then
        # Use ast-grep to find impl blocks for this struct with pub fn methods
        # Pattern: impl StructName { ... pub fn method_name(...) }
        # We search all model files for impl blocks

        for mf in "$MODELS_FILE" "$MODELS_DIR"/*.rs; do
            [[ ! -f "$mf" ]] && continue

            # Find all pub fn names inside `impl StructName` blocks
            # ast-grep structural pattern: impl block containing pub fn
            raw_methods=$(ast-grep --lang rust \
                --pattern "impl ${struct_name} { \$\$\$ }" \
                "$mf" 2>/dev/null | grep -oP "pub fn \w+" || true)

            while IFS= read -r fn_decl; do
                [[ -z "$fn_decl" ]] && continue
                fn_name=$(echo "$fn_decl" | grep -oP '(?<=pub fn )\w+')
                # Exclude conversion/boilerplate methods
                if echo "$fn_name" | grep -qP '^(from|into|default|new_entity_id|fmt)$'; then
                    conversion_count=$((conversion_count + 1))
                else
                    behavior_count=$((behavior_count + 1))
                fi
            done <<< "$raw_methods"
        done
    else
        # Grep-based fallback: find impl StructName blocks and extract pub fn lines
        for mf in "$MODELS_FILE" "$MODELS_DIR"/*.rs; do
            [[ ! -f "$mf" ]] && continue

            # Extract content between `impl StructName {` and the matching closing brace
            # Using awk to track brace depth
            impl_content=$(awk "
                /^impl ${struct_name}[^<]/ { found=1; depth=0 }
                found {
                    for(i=1; i<=length(\$0); i++) {
                        c = substr(\$0, i, 1)
                        if (c == \"{\") depth++
                        if (c == \"}\") { depth--; if (depth == 0) { found=0; next } }
                    }
                    if (found) print
                }
            " "$mf" 2>/dev/null || true)

            while IFS= read -r fn_line; do
                fn_name=$(echo "$fn_line" | grep -oP '(?<=pub fn )\w+' || true)
                [[ -z "$fn_name" ]] && continue
                if echo "$fn_name" | grep -qP '^(from|into|default|new_entity_id|fmt)$'; then
                    conversion_count=$((conversion_count + 1))
                else
                    behavior_count=$((behavior_count + 1))
                fi
            done < <(echo "$impl_content" | grep -P "^\s+pub fn " || true)
        done

        # Also check services/ for extension impl blocks on models
        for sf in "$RUST_SRC/services"/*.rs; do
            [[ ! -f "$sf" ]] && continue
            impl_content=$(awk "
                /^impl ${struct_name}[^<]/ { found=1; depth=0 }
                found {
                    for(i=1; i<=length(\$0); i++) {
                        c = substr(\$0, i, 1)
                        if (c == \"{\") depth++
                        if (c == \"}\") { depth--; if (depth == 0) { found=0; next } }
                    }
                    if (found) print
                }
            " "$sf" 2>/dev/null || true)

            while IFS= read -r fn_line; do
                fn_name=$(echo "$fn_line" | grep -oP '(?<=pub fn )\w+' || true)
                [[ -z "$fn_name" ]] && continue
                if echo "$fn_name" | grep -qP '^(from|into|default|new_entity_id|fmt)$'; then
                    conversion_count=$((conversion_count + 1))
                else
                    behavior_count=$((behavior_count + 1))
                fi
            done < <(echo "$impl_content" | grep -P "^\s+pub fn " || true)
        done
    fi

    rel_file="${src_file#$REPO_ROOT/}"

    if [[ "$behavior_count" -eq 0 && "$conversion_count" -eq 0 ]]; then
        ANEMIC_STRUCTS+=("${struct_name}|${rel_file}|0|0|no_impl")
    elif [[ "$behavior_count" -eq 0 ]]; then
        ANEMIC_STRUCTS+=("${struct_name}|${rel_file}|0|${conversion_count}|conversions_only")
    elif [[ "$behavior_count" -le 2 ]]; then
        BORDERLINE_STRUCTS+=("${struct_name}|${rel_file}|${behavior_count}|${conversion_count}|borderline")
    else
        RICH_STRUCTS+=("${struct_name}|${rel_file}|${behavior_count}|${conversion_count}|rich")
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Report: Anemic entities (violations)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}[ANEMIC — 0 behavior methods] (${#ANEMIC_STRUCTS[@]} structs)${RESET}"
if [[ ${#ANEMIC_STRUCTS[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}None found${RESET}"
else
    for entry in "${ANEMIC_STRUCTS[@]}"; do
        IFS='|' read -r name file behavior conv reason <<< "$entry"
        if [[ "$reason" == "no_impl" ]]; then
            echo -e "  ${RED}VIOLATION${RESET} ${name} (${file}) — no impl block at all"
        else
            echo -e "  ${RED}VIOLATION${RESET} ${name} (${file}) — ${conv} conversion method(s) only, 0 behavior"
        fi
    done
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Report: Borderline entities (1-2 behavior methods)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${YELLOW}[BORDERLINE — 1-2 behavior methods] (${#BORDERLINE_STRUCTS[@]} structs)${RESET}"
if [[ ${#BORDERLINE_STRUCTS[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}None found${RESET}"
else
    for entry in "${BORDERLINE_STRUCTS[@]}"; do
        IFS='|' read -r name file behavior conv reason <<< "$entry"
        echo -e "  ${YELLOW}WARN${RESET}      ${name} (${file}) — ${behavior} behavior method(s), ${conv} conversion(s)"
    done
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Report: Rich entities (healthy)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${GREEN}[RICH — 3+ behavior methods] (${#RICH_STRUCTS[@]} structs)${RESET}"
if [[ ${#RICH_STRUCTS[@]} -eq 0 ]]; then
    echo -e "  ${YELLOW}None found — all entities are anemic or borderline${RESET}"
else
    for entry in "${RICH_STRUCTS[@]}"; do
        IFS='|' read -r name file behavior conv reason <<< "$entry"
        echo -e "  ${GREEN}OK${RESET}        ${name} — ${behavior} behavior method(s)"
    done
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}[SUMMARY]${RESET}"
echo "  Total structs analyzed: ${TOTAL_STRUCTS}"
echo -e "  ${RED}Anemic (violations):    ${#ANEMIC_STRUCTS[@]}${RESET}"
echo -e "  ${YELLOW}Borderline (warnings):  ${#BORDERLINE_STRUCTS[@]}${RESET}"
echo -e "  ${GREEN}Rich (healthy):         ${#RICH_STRUCTS[@]}${RESET}"
echo ""

if [[ ${#ANEMIC_STRUCTS[@]} -gt 0 ]]; then
    echo -e "${BOLD}Recommended fixes:${RESET}"
    echo "  1. Add domain methods to anemic entities (validation, business rules)"
    echo "  2. Move row-mapping logic from services/ into model impl blocks"
    echo "  3. Add named constructors replacing Default + field assignment patterns"
    echo "  4. Run: ./scripts/rust/audit_ddd_solid_dry.sh for the full picture"
    echo ""
    exit 1
fi

exit 0
