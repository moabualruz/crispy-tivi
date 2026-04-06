#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/lib"

# Counters
ddd_count=0
solid_count=0
dry_count=0

echo "=== Dart DDD/SOLID/DRY Audit ==="
echo ""

# ─────────────────────────────────────────────────────────────
# DDD: Domain Flutter Imports
# ─────────────────────────────────────────────────────────────
echo "[DDD: Domain Flutter Imports]"
flutter_in_domain=$(grep -rn "import 'package:flutter" \
  "$LIB/features/"*/domain/ \
  "$LIB/core/domain/" \
  2>/dev/null || true)

if [ -n "$flutter_in_domain" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    import=$(echo "$line" | cut -d: -f3-)
    echo "  ${file#"$REPO_ROOT/"}:$lineno —$import"
    ddd_count=$((ddd_count + 1))
  done <<< "$flutter_in_domain"
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DDD: Serialization in Domain Entities
# ─────────────────────────────────────────────────────────────
echo "[DDD: Serialization in Domain Entities]"
serial_in_domain=$(grep -rn "factory.*fromJson\|Map.*toJson" \
  "$LIB/features/"*/domain/entities/ \
  "$LIB/core/domain/entities/" \
  2>/dev/null || true)

if [ -n "$serial_in_domain" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  ${file#"$REPO_ROOT/"}:$lineno — $content"
    ddd_count=$((ddd_count + 1))
  done <<< "$serial_in_domain"
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DDD: Domain importing Riverpod
# ─────────────────────────────────────────────────────────────
echo "[DDD: Riverpod Imports in Domain]"
riverpod_in_domain=$(grep -rn "import 'package:flutter_riverpod\|import 'package:riverpod" \
  "$LIB/features/"*/domain/ \
  "$LIB/core/domain/" \
  2>/dev/null || true)

if [ -n "$riverpod_in_domain" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    import=$(echo "$line" | cut -d: -f3-)
    echo "  ${file#"$REPO_ROOT/"}:$lineno —$import"
    ddd_count=$((ddd_count + 1))
  done <<< "$riverpod_in_domain"
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DDD: UI logic in Domain (material/IconData/Color/Widget refs)
# ─────────────────────────────────────────────────────────────
echo "[DDD: UI Logic in Domain (material/IconData/Color/Widget)]"
ui_in_domain=$(grep -rn "IconData\|import 'package:flutter/material\|import 'package:flutter/widgets\|: Color\|: Widget\b" \
  "$LIB/features/"*/domain/ \
  "$LIB/core/domain/" \
  2>/dev/null || true)

if [ -n "$ui_in_domain" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  ${file#"$REPO_ROOT/"}:$lineno — $content"
    ddd_count=$((ddd_count + 1))
  done <<< "$ui_in_domain"
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DDD: Business Logic in Data Layer
# ─────────────────────────────────────────────────────────────
echo "[DDD: Business Logic in Data Layer (sort/filter/compute/calculate/detect/guess)]"
biz_in_data=$(grep -rn \
  -E "^\s*(Future|Stream|List|Map|bool|int|double|String)<?\s*[A-Za-z].*>\s+(sort|filter|compute|calculate|detect|guess|rank|score)[A-Za-z]*\s*\(" \
  "$LIB/core/data/" \
  --include="*.dart" \
  --exclude="crispy_backend*.dart" \
  --exclude="ffi_backend*.dart" \
  --exclude="ws_backend*.dart" \
  --exclude="memory_backend*.dart" \
  2>/dev/null || true)

if [ -n "$biz_in_data" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  ${file#"$REPO_ROOT/"}:$lineno — $content"
    ddd_count=$((ddd_count + 1))
  done <<< "$biz_in_data"
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# SOLID: God Classes (CacheService)
# ─────────────────────────────────────────────────────────────
echo "[SOLID: God Classes]"
total_lines=0
total_public_methods=0
for f in "$LIB/core/data/cache_service"*.dart; do
  lines=$(wc -l < "$f")
  total_lines=$((total_lines + lines))
  # Count public method declarations (non-underscore identifiers after return types)
  methods=$(grep -cE "^\s+(Future|Stream|List|Map|bool|int|double|String|void|[A-Z][a-zA-Z]+)[^_]*\s+[a-z][a-zA-Z]+(Async)?\s*[(<]" "$f" 2>/dev/null || echo 0)
  total_public_methods=$((total_public_methods + methods))
  fname=$(basename "$f")
  echo "  $fname: $lines lines, ~$methods public methods"
done
echo "  TOTAL: $total_lines lines, ~$total_public_methods public methods (target: each file <400 lines)"
if [ "$total_lines" -gt 400 ]; then
  solid_count=$((solid_count + 1))
fi
echo ""

# ─────────────────────────────────────────────────────────────
# SOLID: Missing Repository Interfaces
# ─────────────────────────────────────────────────────────────
echo "[SOLID: Missing Repository Interfaces (DIP)]"
repo_interfaces=$(find "$LIB/features" -path "*/domain/repositories/*.dart" 2>/dev/null | wc -l)
features_with_repos=$(find "$LIB/features" -path "*/domain/repositories/*.dart" 2>/dev/null \
  | sed 's|.*/features/||; s|/domain.*||' | sort -u | wc -l)
total_features=$(ls -d "$LIB/features"/*/ 2>/dev/null | wc -l)
providers_importing_cache=$(grep -rl "import.*cache_service" \
  "$LIB/features/"*/presentation/providers/ \
  2>/dev/null | wc -l || echo 0)

echo "  Repository interface files: $repo_interfaces (across $features_with_repos features)"
echo "  Total features: $total_features"
echo "  Providers importing CacheService directly (DIP violation): $providers_importing_cache"
if [ "$providers_importing_cache" -gt 0 ]; then
  solid_count=$((solid_count + providers_importing_cache))
  grep -rl "import.*cache_service" "$LIB/features/"*/presentation/providers/ 2>/dev/null | while read -r f; do
    echo "    ${f#"$REPO_ROOT/"}"
  done || true
fi
echo ""

# ─────────────────────────────────────────────────────────────
# SOLID: Widget SRP violations (>800 lines)
# ─────────────────────────────────────────────────────────────
echo "[SOLID: Widget SRP Violations (>800 lines)]"
found_large=0
while IFS= read -r f; do
  lines=$(wc -l < "$f")
  if [ "$lines" -gt 800 ]; then
    echo "  ${f#"$REPO_ROOT/"}: $lines lines (target: <800)"
    solid_count=$((solid_count + 1))
    found_large=1
  fi
done < <(find "$LIB/features" \
  \( -path "*/presentation/widgets/*.dart" -o -path "*/presentation/screens/*.dart" \) \
  ! -name "*.g.dart" ! -name "*.freezed.dart" 2>/dev/null)

if [ "$found_large" -eq 0 ]; then
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DRY: Duplicate Serialization (fromJson in domain AND map fn in cache_service)
# ─────────────────────────────────────────────────────────────
echo "[DRY: Duplicate Serialization]"
dry_found=0

# Find entities with fromJson in domain/entities
while IFS= read -r line; do
  domain_file=$(echo "$line" | cut -d: -f1)
  domain_lineno=$(echo "$line" | cut -d: -f2)
  # Extract the class name from the factory line: factory ClassName.fromJson
  classname=$(echo "$line" | grep -oE "factory ([A-Za-z]+)\.fromJson" | awk '{print $2}' | cut -d. -f1)
  if [ -z "$classname" ]; then
    continue
  fi

  # Look for matching map function in cache_service files
  cache_match=$(grep -rn "mapTo${classname}\|${classname}ToMap\|_mapTo${classname}\|to${classname}Model\|_to${classname}" \
    "$LIB/core/data/cache_service"*.dart 2>/dev/null | head -1 || true)

  if [ -n "$cache_match" ]; then
    cache_file=$(echo "$cache_match" | cut -d: -f1)
    cache_lineno=$(echo "$cache_match" | cut -d: -f2)
    echo "  $classname: fromJson at ${domain_file#"$REPO_ROOT/"}:$domain_lineno + mapping at ${cache_file#"$REPO_ROOT/"}:$cache_lineno"
    dry_count=$((dry_count + 1))
    dry_found=1
  fi
done < <(grep -rn "factory.*fromJson" \
  "$LIB/features/"*/domain/entities/ \
  "$LIB/core/domain/entities/" \
  2>/dev/null || true)

if [ "$dry_found" -eq 0 ]; then
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DRY: Hand-written copyWith in domain entities
# ─────────────────────────────────────────────────────────────
echo "[DRY: Hand-written copyWith in Domain Entities (Freezed candidates)]"
copyWith_files=$(grep -rln "copyWith(" \
  "$LIB/features/"*/domain/entities/ \
  "$LIB/core/domain/entities/" \
  2>/dev/null || true)

if [ -n "$copyWith_files" ]; then
  count=0
  while IFS= read -r f; do
    echo "  ${f#"$REPO_ROOT/"}"
    count=$((count + 1))
  done <<< "$copyWith_files"
  dry_count=$((dry_count + count))
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────
total=$((ddd_count + solid_count + dry_count))
echo "[SUMMARY]"
echo "  DDD violations:   $ddd_count"
echo "  SOLID violations: $solid_count"
echo "  DRY violations:   $dry_count"
echo "  TOTAL:            $total"
echo ""
