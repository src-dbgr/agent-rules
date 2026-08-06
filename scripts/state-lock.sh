#!/usr/bin/env bash
# state-lock.sh — einfacher Datei-Lock für runtime/state/<id>.json
# Exit: 0 PASS | 1 FAIL | 2 NICHT NACHGEWIESEN
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="" HOLDER="" STATE_ID=""

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --acquire) MODE=acquire; shift ;;
    --release) MODE=release; shift ;;
    --self-test-foreign-lock) MODE=selftest; shift ;;
    --holder) HOLDER="${2:-}"; shift 2 ;;
    --id) STATE_ID="${2:-}"; shift 2 ;;
    *) die "unbekannt: $1" ;;
  esac
done

[[ -n "$MODE" ]] || die "Modus fehlt"
[[ -n "$STATE_ID" ]] || STATE_ID="${HOLDER:-default}"
DIR="${ROOT}/runtime/state"
mkdir -p "$DIR"
LOCK="${DIR}/${STATE_ID}.json.lock"

case "$MODE" in
  acquire)
    [[ -n "$HOLDER" ]] || die "--holder erforderlich"
    if [[ -f "$LOCK" ]]; then
      owner="$(cat "$LOCK")"
      if [[ "$owner" != "$HOLDER" ]]; then
        die "fremder Lock von $owner"
      fi
      printf 'PASS lock bereits gehalten von %s\n' "$HOLDER"
      exit 0
    fi
    printf '%s\n' "$HOLDER" >"$LOCK"
    printf 'PASS lock acquired by %s\n' "$HOLDER"
    ;;
  release)
    [[ -n "$HOLDER" ]] || die "--holder erforderlich"
    if [[ -f "$LOCK" ]]; then
      owner="$(cat "$LOCK")"
      [[ "$owner" == "$HOLDER" ]] || die "Lock gehört $owner"
      rm -f "$LOCK"
    fi
    printf 'PASS lock released\n'
    ;;
  selftest)
    rm -f "${DIR}/_selftest.json.lock"
    printf 'other\n' >"${DIR}/_selftest.json.lock"
    if bash "$0" --acquire --holder self --id _selftest >/dev/null 2>&1; then
      rm -f "${DIR}/_selftest.json.lock"
      die "selftest: fremder Lock wurde übernommen"
    fi
    rm -f "${DIR}/_selftest.json.lock"
    printf 'PASS self-test-foreign-lock\n'
    ;;
esac
