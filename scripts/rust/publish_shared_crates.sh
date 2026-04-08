#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHARED_DIR="$ROOT_DIR/rust/shared"

MODE="${1:-dry-run}"
SLEEP_SECS="${PUBLISH_SLEEP_SECS:-20}"

CRATES=(
  "crispy-iptv-types"
  "crispy-m3u"
  "crispy-xmltv"
  "crispy-catchup"
  "crispy-xtream"
  "crispy-stalker"
  "crispy-iptv-tools"
  "crispy-media-probe"
  "crispy-stream-checker"
)

LOCAL_PATCH_ARGS=()
for crate in "${CRATES[@]}"; do
  LOCAL_PATCH_ARGS+=(
    "--config"
    "patch.crates-io.${crate}.path=\"${SHARED_DIR}/${crate}\""
  )
done

usage() {
  cat <<'EOF'
Usage:
  scripts/rust/publish_shared_crates.sh [dry-run|publish|check]

Modes:
  dry-run  Run cargo package --no-verify for each shared crate in dependency order
  publish  Run cargo publish for each shared crate in dependency order
  check    Print the publish order and current crate versions

Environment:
  PUBLISH_SLEEP_SECS   Seconds to sleep between real publishes (default: 20)
EOF
}

crate_version() {
  local crate_dir="$1"
  sed -n 's/^version = "\(.*\)"/\1/p' "$crate_dir/Cargo.toml" | head -n1
}

wait_for_publish() {
  local crate="$1"
  local version="$2"
  local attempts=30

  for ((i = 1; i <= attempts; i++)); do
    if cargo search "$crate" --limit 1 2>/dev/null | grep -q "$version"; then
      return 0
    fi
    sleep "$SLEEP_SECS"
  done

  echo "Timed out waiting for $crate $version to appear via cargo search" >&2
  return 1
}

run_for_crate() {
  local crate="$1"
  local crate_dir="$SHARED_DIR/$crate"
  local version
  version="$(crate_version "$crate_dir")"

  echo "==> $crate ($version)"

  case "$MODE" in
    dry-run)
      # `cargo publish --dry-run` cannot model an unpublished dependency chain
      # across separate repositories because crates later in the sequence still
      # resolve dependencies from crates.io. Package locally here and inject
      # path patches so Cargo resolves the local shared crates in publish order.
      (cd "$crate_dir" && cargo package --no-verify "${LOCAL_PATCH_ARGS[@]}")
      ;;
    publish)
      (cd "$crate_dir" && cargo publish)
      wait_for_publish "$crate" "$version"
      ;;
    check)
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

if [[ "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  usage
  exit 0
fi

echo "Shared crate publish order:"
for crate in "${CRATES[@]}"; do
  echo " - $crate ($(crate_version "$SHARED_DIR/$crate"))"
done

echo

for crate in "${CRATES[@]}"; do
  run_for_crate "$crate"
done
