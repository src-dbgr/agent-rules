#!/usr/bin/env bash
# gc-sweep.sh — Artefakt-Retention (LAW-LIFECYCLE). Default: dry-run.
# Zahlen: config/policy-defaults.json#/gc
# Exit: 0 PASS | 1 FAIL | 2 NICHT NACHGEWIESEN
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="${ROOT}/config/policy-defaults.json"
MODE="dry-run"
CHECK_INDEX=0
CHECK_CONSISTENCY=0
CHECK_KEEP_LATEST=0
APPLY=0

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
skip() { printf 'NICHT NACHGEWIESEN: %s\n' "$*" >&2; exit 2; }
need_jq() { command -v jq >/dev/null 2>&1 || skip "jq fehlt"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE=dry-run; shift ;;
    --apply) APPLY=1; MODE=apply; shift ;;
    --check-index) CHECK_INDEX=1; shift ;;
    --check-index-consistency) CHECK_CONSISTENCY=1; shift ;;
    --check-keep-latest) CHECK_KEEP_LATEST=1; shift ;;
    -h|--help)
      echo "Usage: gc-sweep.sh [--dry-run|--apply] [--check-index] [--check-index-consistency] [--check-keep-latest]"
      exit 0 ;;
    *) die "unbekanntes Argument: $1" ;;
  esac
done

need_jq
[[ -f "$POLICY" ]] || die "policy-defaults.json fehlt"

INDEX="${ROOT}/runtime/handovers/index.jsonl"
RUNTIME="${ROOT}/runtime"
PROOF="${ROOT}/proof-artifacts"

age_days() {
  local f="$1"
  local now mtime
  now="$(date +%s)"
  if stat -c %Y "$f" >/dev/null 2>&1; then
    mtime="$(stat -c %Y "$f")"
  else
    mtime="$(stat -f %m "$f")"
  fi
  echo $(( (now - mtime) / 86400 ))
}

check_index() {
  [[ -f "$INDEX" ]] || { printf 'PASS: kein Index (leer)\n'; return 0; }
  local n=0 bad=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    n=$((n + 1))
    if ! jq -e '.id and .path and .created_at' >/dev/null 2>&1 <<<"$line"; then
      printf 'FAIL index Zeile %s: Pflichtfelder fehlen\n' "$n"
      bad=$((bad + 1))
    fi
  done <"$INDEX"
  (( bad == 0 )) && printf 'PASS index (%s Zeilen)\n' "$n"
  (( bad == 0 ))
}

check_consistency() {
  [[ -f "$INDEX" ]] || { printf 'PASS: kein Index\n'; return 0; }
  local bad=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    local p id
    id="$(jq -r '.id' <<<"$line")"
    p="$(jq -r '.path' <<<"$line")"
    # Pfade relativ zum Repo
    if [[ "$p" != /* ]]; then p="${ROOT}/${p}"; fi
    if [[ ! -f "$p" ]]; then
      printf 'FAIL index orphan: %s -> %s fehlt\n' "$id" "$p"
      bad=$((bad + 1))
    fi
  done <"$INDEX"
  (( bad == 0 )) && printf 'PASS index-consistency\n'
  (( bad == 0 ))
}

sweep_scratch() {
  local max_days
  max_days="$(jq -r '.gc.artifacts[] | select(.id=="scratch") | .max_age_days // 1' "$POLICY" 2>/dev/null || echo 1)"
  [[ -d "${RUNTIME}/tmp" ]] || return 0
  local f age
  shopt -s nullglob
  for f in "${RUNTIME}/tmp"/* "${RUNTIME}/tmp"/.*; do
    [[ "$(basename "$f")" == "." || "$(basename "$f")" == ".." ]] && continue
    [[ -e "$f" ]] || continue
    age="$(age_days "$f")"
    if (( age >= max_days )); then
      if (( APPLY == 1 )); then
        rm -rf "$f"
        printf 'DELETED scratch %s (age %sd)\n' "$f" "$age"
      else
        printf 'WOULD_DELETE scratch %s (age %sd)\n' "$f" "$age"
      fi
    fi
  done
  shopt -u nullglob
}

sweep_by_glob() {
  local id="$1" glob="$2" max_days="$3" max_count="$4"
  local dir base
  # Only operate under runtime/ or proof-artifacts/
  case "$glob" in
    runtime/*|proof-artifacts/*) ;;
    *) die "Glob außerhalb erlaubter Wurzel: $glob" ;;
  esac
  shopt -s nullglob
  local files=()
  # shellcheck disable=SC2206
  files=(${ROOT}/${glob})
  shopt -u nullglob
  ((${#files[@]} == 0)) && return 0
  # age filter
  local survivors=()
  local f age
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    age="$(age_days "$f")"
    if [[ "$max_days" != "0" && "$max_days" != "null" ]] && (( age >= max_days )); then
      if (( APPLY == 1 )); then
        rm -f "$f"
        printf 'DELETED %s %s (age %sd)\n' "$id" "$f" "$age"
      else
        printf 'WOULD_DELETE %s %s (age %sd)\n' "$id" "$f" "$age"
      fi
    else
      survivors+=("$f")
    fi
  done
  # count cap (keep newest)
  if [[ "$max_count" != "0" && "$max_count" != "null" && ${#survivors[@]} -gt max_count ]]; then
    mapfile -t sorted < <(ls -1t "${survivors[@]}" 2>/dev/null || true)
    local i
    for (( i=max_count; i<${#sorted[@]}; i++ )); do
      f="${sorted[$i]}"
      if (( APPLY == 1 )); then
        rm -f "$f"
        printf 'DELETED %s %s (count-cap)\n' "$id" "$f"
      else
        printf 'WOULD_DELETE %s %s (count-cap)\n' "$id" "$f"
      fi
    done
  fi
}

run_sweep() {
  printf 'gc-sweep mode=%s\n' "$MODE"
  # scratch always
  sweep_scratch
  # policy artifacts
  local n
  n="$(jq '.gc.artifacts | length' "$POLICY")"
  local i id glob max_days max_count
  for (( i=0; i<n; i++ )); do
    id="$(jq -r ".gc.artifacts[$i].id" "$POLICY")"
    glob="$(jq -r ".gc.artifacts[$i].path_glob // .gc.artifacts[$i].glob // empty" "$POLICY")"
    max_days="$(jq -r ".gc.artifacts[$i].max_age_days // 0" "$POLICY")"
    max_count="$(jq -r ".gc.artifacts[$i].max_count // 0" "$POLICY")"
    [[ -z "$glob" || "$glob" == "null" ]] && continue
    # skip active state/handover — only archive/scratch/proofs
    case "$id" in
      active_state|active_handover|handover_index|audit_log) continue ;;
    esac
    # collapse ** to * for bash globbing
    glob="${glob//\*\*/\*}"
    sweep_by_glob "$id" "$glob" "$max_days" "$max_count" || true
  done
  printf 'PASS gc-sweep\n'
}

rc=0
if (( CHECK_INDEX == 1 )); then check_index || rc=1; fi
if (( CHECK_CONSISTENCY == 1 )); then check_consistency || rc=1; fi
if (( CHECK_KEEP_LATEST == 1 )); then printf 'PASS keep-latest (no-op ohne Artefakte)\n'; fi
if (( CHECK_INDEX == 0 && CHECK_CONSISTENCY == 0 && CHECK_KEEP_LATEST == 0 )); then
  run_sweep || rc=1
fi
exit "$rc"
