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
  2>/dev/null \
  | grep -v "// DDD exception" \
  | grep -v "crispy_player\.dart" \
  | grep -v "remote_action\.dart" \
  || true)

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
  2>/dev/null \
  | grep -v "// DDD exception" \
  | grep -v "crispy_player\.dart" \
  | grep -v "remote_action\.dart" \
  || true)

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
# DDD: Domain importing data/infrastructure layer
# ─────────────────────────────────────────────────────────────
echo "[DDD: Domain Importing Data/Infrastructure Layer]"
infra_in_domain=$(grep -rn \
  -e "import.*data/" \
  -e "import.*datasources/" \
  -e "import.*presentation/" \
  -e "import.*providers/" \
  -e "import 'package:dio" \
  -e "import 'package:sqflite" \
  -e "import 'package:shared_preferences" \
  "$LIB/features/"*/domain/ \
  "$LIB/core/domain/" \
  2>/dev/null \
  | grep -v "// DDD exception" \
  | grep -v "crispy_player\.dart" \
  | grep -v "remote_action\.dart" \
  | grep -v "_test\.dart" \
  || true)

if [ -n "$infra_in_domain" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  ${file#"$REPO_ROOT/"}:$lineno — $content"
    ddd_count=$((ddd_count + 1))
  done <<< "$infra_in_domain"
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DDD: Application layer importing Presentation layer
# ─────────────────────────────────────────────────────────────
echo "[DDD: Application Layer Importing Presentation Layer]"
app_to_pres=$(grep -rn "import.*presentation/" \
  "$LIB/features/"*/application/ \
  "$LIB/core/application/" \
  2>/dev/null \
  | grep -v "// DDD exception" \
  || true)

if [ -n "$app_to_pres" ]; then
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    lineno=$(echo "$line" | cut -d: -f2)
    content=$(echo "$line" | cut -d: -f3- | sed 's/^ *//')
    echo "  ${file#"$REPO_ROOT/"}:$lineno — $content"
    ddd_count=$((ddd_count + 1))
  done <<< "$app_to_pres"
else
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DDD: Anemic Domain Entities
# ─────────────────────────────────────────────────────────────
echo "[DDD: Anemic Domain Entities (no real behavior methods)]"
anemic_found=0

# Boilerplate patterns to exclude (not real domain behavior):
#   - copyWith(  toString(  hashCode  operator ==  fromJson  toJson
#   - plain constructors: ClassName(  or  factory ClassName(
# Real behavior = any named getter (bool get foo =>) or method with a body
# that is NOT one of the boilerplate names above.
# Skip: enum files (legitimate data-only), files <30 lines (simple VOs)
while IFS= read -r entity_file; do
  # Skip enum files — enums are legitimately data-only value objects
  if grep -qE "^enum\s" "$entity_file" 2>/dev/null; then
    continue
  fi

  # Skip very small files (<30 lines) — simple value objects
  file_lines=$(wc -l < "$entity_file" 2>/dev/null || echo 0)
  file_lines=$(echo "$file_lines" | tr -d '[:space:]')
  if [ "$file_lines" -lt 30 ]; then
    continue
  fi

  # Count lines that look like real domain behavior:
  #   getters:  "  bool get isSignedIn =>" or "  Duration get duration {"
  #   methods:  "  void cancel() {" / "  List<X> active() {"
  # Exclude boilerplate names explicitly.
  has_behavior=$(grep -cP \
    "^\s+[A-Za-z?<>\[\]]+\s+get\s+(?!hashCode)[a-z][a-zA-Z]*\s*(=>|\{)|^\s+(Future|Stream|List|Map|Set|bool|int|double|String|void|[A-Z][a-zA-Z<>?\[\]]+)\s+(?!copyWith|toString|toJson|fromJson|hashCode)[a-z][a-zA-Z]*\s*\([^)]*\)\s*(=>|\{|async)" \
    "$entity_file" 2>/dev/null || true)
  # Strip whitespace/newlines so integer comparison is safe
  has_behavior=$(echo "$has_behavior" | tr -d '[:space:]')
  has_behavior=${has_behavior:-0}

  if [ "$has_behavior" -eq 0 ]; then
    echo "  [ANEMIC] ${entity_file#"$REPO_ROOT/"}"
    ddd_count=$((ddd_count + 1))
    anemic_found=1
  fi
done < <(find "$LIB/features" "$LIB/core" \
  -path "*/domain/entities/*.dart" \
  ! -name "*.g.dart" ! -name "*.freezed.dart" 2>/dev/null)

if [ "$anemic_found" -eq 0 ]; then
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
  --exclude="cache_service*.dart" \
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
# SOLID: God Classes (CacheService) — counted as violations
# ─────────────────────────────────────────────────────────────
echo "[SOLID: God Classes (CacheService)]"
total_lines=0
total_public_methods=0
for f in "$LIB/core/data/cache_service"*.dart; do
  [ -f "$f" ] || continue
  lines=$(wc -l < "$f")
  total_lines=$((total_lines + lines))
  methods=$(grep -cE "^\s+(Future|Stream|List|Map|bool|int|double|String|void|[A-Z][a-zA-Z]+)[^_]*\s+[a-z][a-zA-Z]+(Async)?\s*[(<]" "$f" 2>/dev/null || echo 0)
  methods=$(echo "$methods" | tr -d '[:space:]')
  methods=${methods:-0}
  total_public_methods=$((total_public_methods + methods))
  fname="${f#"$REPO_ROOT/"}"
  if [ "$lines" -gt 400 ]; then
    echo "  [VIOLATION] $fname: $lines lines (target: <400)"
    solid_count=$((solid_count + 1))
  else
    echo "  $fname: $lines lines, ~$methods public methods"
  fi
done
echo "  TOTAL: $total_lines lines, ~$total_public_methods public methods"
echo ""

# ─────────────────────────────────────────────────────────────
# SOLID: Missing Repository Interfaces / DIP violations
# ─────────────────────────────────────────────────────────────
echo "[SOLID: Missing Repository Interfaces (DIP)]"
repo_interfaces=$(find "$LIB/features" -path "*/domain/repositories/*.dart" 2>/dev/null | wc -l)
features_with_repos=$(find "$LIB/features" -path "*/domain/repositories/*.dart" 2>/dev/null \
  | sed 's|.*/features/||; s|/domain.*||' | sort -u)
features_with_repos_count=$(echo "$features_with_repos" | grep -c . 2>/dev/null || echo 0)
total_features=$(ls -d "$LIB/features"/*/ 2>/dev/null | wc -l)

echo "  Repository interface files: $repo_interfaces (across $features_with_repos_count features)"
echo "  Total features: $total_features"
echo "  Features with repo interfaces: $(echo "$features_with_repos" | tr '\n' ' ')"

# DIP violation: provider in a feature that HAS a repo interface imports CacheService directly
while IFS= read -r provider_file; do
  feature=$(echo "$provider_file" | sed 's|.*/features/||; s|/presentation.*||')
  if echo "$features_with_repos" | grep -qx "$feature"; then
    echo "  [DIP VIOLATION] ${provider_file#"$REPO_ROOT/"} (feature '$feature' has repo interface but bypasses it)"
    solid_count=$((solid_count + 1))
  fi
done < <(grep -rl "import.*cache_service" \
  "$LIB/features/"*/presentation/providers/ \
  2>/dev/null || true)
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
# SOLID: Large Provider Files (SRP, >300 lines)
# ─────────────────────────────────────────────────────────────
echo "[SOLID: Large Provider Files (SRP >300 lines)]"
found_large_providers=0
while IFS= read -r f; do
  lines=$(wc -l < "$f")
  if [ "$lines" -gt 300 ]; then
    echo "  ${f#"$REPO_ROOT/"}: $lines lines (target: <300)"
    solid_count=$((solid_count + 1))
    found_large_providers=1
  fi
done < <(find "$LIB/features" \
  -path "*/presentation/providers/*.dart" \
  ! -name "*.g.dart" ! -name "*.freezed.dart" 2>/dev/null)

if [ "$found_large_providers" -eq 0 ]; then
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# SOLID: Widgets importing data layer directly (bypassing providers)
# ─────────────────────────────────────────────────────────────
echo "[SOLID: Widgets Importing Data Layer Directly (bypassing providers)]"
found_widget_data=0
while IFS= read -r f; do
  matches=$(grep -nE "import.*(data/|_service['\"]|_repository['\"])" "$f" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    while IFS= read -r match; do
      lineno=$(echo "$match" | cut -d: -f1)
      content=$(echo "$match" | cut -d: -f2- | sed 's/^ *//')
      echo "  ${f#"$REPO_ROOT/"}:$lineno — $content"
      solid_count=$((solid_count + 1))
      found_widget_data=1
    done <<< "$matches"
  fi
done < <(find "$LIB/features" \
  -path "*/presentation/widgets/*.dart" \
  ! -name "*.g.dart" ! -name "*.freezed.dart" 2>/dev/null)

if [ "$found_widget_data" -eq 0 ]; then
  echo "  (none found)"
fi
echo ""

# ─────────────────────────────────────────────────────────────
# DRY: Duplicate Serialization (fromJson in domain AND map fn in cache_service)
# ─────────────────────────────────────────────────────────────
echo "[DRY: Duplicate Serialization]"
dry_found=0

while IFS= read -r line; do
  domain_file=$(echo "$line" | cut -d: -f1)
  domain_lineno=$(echo "$line" | cut -d: -f2)
  classname=$(echo "$line" | grep -oE "factory ([A-Za-z]+)\.fromJson" | awk '{print $2}' | cut -d. -f1)
  if [ -z "$classname" ]; then
    continue
  fi

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
echo "[DRY: Hand-written copyWith in Domain Entities (INFO — structural boilerplate, not knowledge duplication)]"
# NOTE: Each entity's copyWith has unique fields specific to that entity.
# Per DRY: "two identical code blocks representing independent concepts
# that evolve separately are fine." Not counted as violations.
copyWith_files=$(grep -rln "copyWith(" \
  "$LIB/features/"*/domain/entities/ \
  "$LIB/core/domain/entities/" \
  2>/dev/null || true)

if [ -n "$copyWith_files" ]; then
  count=0
  while IFS= read -r f; do
    echo "  [INFO] ${f#"$REPO_ROOT/"}"
    count=$((count + 1))
  done <<< "$copyWith_files"
  echo "  ($count file(s) — Freezed codegen candidate; not counted as violations)"
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
