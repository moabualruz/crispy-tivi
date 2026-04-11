#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FLUTTER_APP_DIR="$ROOT_DIR/app/flutter"
cd "$FLUTTER_APP_DIR"

DEVICE_ID="${DEVICE_ID:-emulator-5554}"
TEST_SUITE="${1:-integration_test/main_test.dart}"
TIMEOUT_SECS="${TIMEOUT_SECS:-1800}"
STATUS_EVERY_SECS="${STATUS_EVERY_SECS:-15}"
PKG_NAME="${PKG_NAME:-com.crispytivi.crispy_tivi}"
CREDS_FILE="${CREDS_FILE:-$FLUTTER_APP_DIR/integration_test/test_helpers/test_creds.local.json}"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/.android-sdk}"
export ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${ROOT_DIR}/logs/android/${STAMP}"
mkdir -p "$OUT_DIR"

TEST_LOG="$OUT_DIR/flutter-test.log"
LOGCAT_LOG="$OUT_DIR/logcat.txt"
DUMPSYS_LOG="$OUT_DIR/dumpsys-activity.txt"

if [[ ! -f "$CREDS_FILE" ]]; then
  echo "Missing creds file: $CREDS_FILE" >&2
  exit 1
fi

CREDS_JSON="$(tr -d '\n' < "$CREDS_FILE")"

echo "Android integration run"
echo "  device:  $DEVICE_ID"
echo "  suite:   $TEST_SUITE"
echo "  timeout: ${TIMEOUT_SECS}s"
echo "  logs:    $OUT_DIR"

adb -s "$DEVICE_ID" wait-for-device
adb -s "$DEVICE_ID" logcat -c
adb -s "$DEVICE_ID" shell am force-stop "$PKG_NAME" >/dev/null 2>&1 || true

cleanup() {
  local code=$?
  if [[ -n "${TEST_PID:-}" ]]; then
    kill -TERM "$TEST_PID" >/dev/null 2>&1 || true
    sleep 1
    kill -KILL "$TEST_PID" >/dev/null 2>&1 || true
  fi
  adb -s "$DEVICE_ID" logcat -d >"$LOGCAT_LOG" 2>/dev/null || true
  adb -s "$DEVICE_ID" shell dumpsys activity activities >"$DUMPSYS_LOG" 2>/dev/null || true
  exit "$code"
}
trap cleanup EXIT INT TERM

flutter test "$TEST_SUITE" -d "$DEVICE_ID" \
  --dart-define="CRISPY_TEST_CREDS_JSON=${CREDS_JSON}" \
  >"$TEST_LOG" 2>&1 &
TEST_PID=$!
START_TS="$(date +%s)"

while kill -0 "$TEST_PID" >/dev/null 2>&1; do
  sleep "$STATUS_EVERY_SECS"
  NOW_TS="$(date +%s)"
  ELAPSED="$((NOW_TS - START_TS))"
  APP_PID="$(adb -s "$DEVICE_ID" shell pidof -s "$PKG_NAME" 2>/dev/null | tr -d '\r' || true)"
  TOP_ACTIVITY="$(adb -s "$DEVICE_ID" shell dumpsys activity activities 2>/dev/null | grep -m1 'ResumedActivity:' | tr -d '\r' || true)"
  echo "[android-run] elapsed=${ELAPSED}s app_pid=${APP_PID:-none}"
  if [[ -n "$TOP_ACTIVITY" ]]; then
    echo "[android-run] ${TOP_ACTIVITY}"
  fi
  if (( ELAPSED > TIMEOUT_SECS )); then
    echo "[android-run] timeout reached (${TIMEOUT_SECS}s), aborting runner" >&2
    exit 124
  fi
done

wait "$TEST_PID"
