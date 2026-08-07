#!/usr/bin/env bash
# snapshot.sh — State-Snapshot create/restore (LAW-LIFECYCLE)
# Exit: 0 PASS | 1 FAIL | 2 NICHT NACHGEWIESEN
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="" STATE="" TASK="default"

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
skip() { printf 'NICHT NACHGEWIESEN: %s\n' "$*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    create|--create) MODE=create; shift ;;
    restore|--restore) MODE=restore; shift ;;
    --latest) LATEST=1; shift ;;
    --state) STATE="${2:-}"; shift 2 ;;
    --task) TASK="${2:-}"; shift 2 ;;
    *) die "unbekannt: $1" ;;
  esac
done

command -v gzip >/dev/null 2>&1 || skip "gzip fehlt"
[[ -n "$MODE" ]] || die "create|restore erforderlich"

ARCH="${ROOT}/runtime/archive/${TASK}"
mkdir -p "$ARCH"

case "$MODE" in
  create)
    [[ -n "$STATE" && -f "$STATE" ]] || die "--state <path> erforderlich"
    ts="$(date -u +%Y%m%dT%H%M%SZ)"
    out="${ARCH}/state-${ts}.json.gz"
    gzip -c "$STATE" >"$out"
    printf 'PASS snapshot %s\n' "$out"
    ;;
  restore)
    latest="$(ls -1t "${ARCH}"/state-*.json.gz 2>/dev/null | head -1 || true)"
    [[ -n "$latest" ]] || die "kein Snapshot in $ARCH"
    [[ -n "$STATE" ]] || die "--state <ziel> erforderlich"
    mkdir -p "$(dirname "$STATE")"
    gzip -dc "$latest" >"$STATE"
    printf 'PASS restored %s -> %s\n' "$latest" "$STATE"
    ;;
esac
