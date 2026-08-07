#!/usr/bin/env bash
# Branch-Hygiene: Bericht ueber Task-Branches und sicheres Abraeumen (LAW-VCS).
# Normtext und Begruendung: modules/vcs.md — dieses Skript ist die Durchsetzung,
# nicht die Quelle der Regeln. Alle Zahlen kommen aus config/policy-defaults.json.
#
# Aufruf:
#   scripts/branch-hygiene.sh [--report] [--worktrees] [--pr-check auto|gh|off]
#   scripts/branch-hygiene.sh --apply-local [--pr-check off]      # Alias: --write
#   scripts/branch-hygiene.sh --remote <branch> --i-know-what-i-do --confirm-delete-remote <branch>
#   scripts/branch-hygiene.sh --self-test-protections
#
# Dry-Run ist Default: ohne --apply-local/--write wird keine Referenz veraendert.
#
# Exit-Semantik (identisch in allen Pruefskripten, ADR-009 §2):
#   0  PASS                       — Bericht erstellt bzw. Abraeumen regelkonform ausgefuehrt
#   1  FAIL                       — verweigerte Aktion, verletzte Vorbedingung, Fehler
#   2  NICHT NACHGEWIESEN         — noetiges Werkzeug oder noetige Angabe fehlt
# Ein SKIP ist nie ein PASS.
#
# Vier harte Loeschverbote (modules/vcs.md, D-3) — im Code als deny_* markiert:
#   1. niemals der Default-Branch oder ein geschuetzter Branch
#   2. niemals ein unmerged Branch (kein -D, kein --force)
#   3. niemals ein Branch mit offenem PR/MR (nicht feststellbar => Verweigerung)
#   4. niemals eine Remote-Referenz ohne Freigabe-Token UND Bestaetigung
# Zusaetzlich: niemals der aktuelle Branch, niemals ein im State registrierter Branch.
# Das Wiederherstellungsfenster wird nicht verkuerzt: dieses Skript ruft weder
# den Reflog-Verfall noch eine sofortige Objektbereinigung auf.

set -uo pipefail

# Eigener Ort ohne externe Werkzeuge (kein dirname: bei leerem PATH Exit 127).
SELF_PATH="${BASH_SOURCE[0]}"
case "$SELF_PATH" in */*) SELF_DIR="${SELF_PATH%/*}" ;; *) SELF_DIR="." ;; esac
SELF_DIR="$(cd "$SELF_DIR" && pwd)"
SELF="$SELF_DIR/${SELF_PATH##*/}"
LAWBOOK_ROOT="${SELF_DIR%/*}"
CONFIG="${BRANCH_HYGIENE_CONFIG:-$LAWBOOK_ROOT/config/policy-defaults.json}"

MODE="report"
PR_CHECK="auto"
WORKTREES=0
REMOTE_BRANCH=""
CONFIRM_TOKEN=""
CONFIRM_BRANCH=""
REMOTE_NAME="origin"

usage() { sed -n '2,30p' "$SELF"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --report) MODE="report"; shift ;;
    --apply-local|--write) MODE="apply-local"; shift ;;
    --self-test-protections) MODE="self-test"; shift ;;
    --remote) MODE="remote"; REMOTE_BRANCH="${2:-}"; shift 2 || shift ;;
    --confirm-delete-remote) CONFIRM_BRANCH="${2:-}"; shift 2 || shift ;;
    --i-know-what-i-do) CONFIRM_TOKEN="$1"; shift ;;
    --pr-check) PR_CHECK="${2:-auto}"; shift 2 || shift ;;
    --pr-check=*) PR_CHECK="${1#*=}"; shift ;;
    --worktrees) WORKTREES=1; shift ;;
    --remote-name) REMOTE_NAME="${2:-origin}"; shift 2 || shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'FAIL: unbekannte Option %s\n' "$1" >&2; exit 1 ;;
  esac
done
case "$PR_CHECK" in auto|gh|off) ;; *) printf 'FAIL: --pr-check erwartet auto|gh|off\n' >&2; exit 1 ;; esac

FAILURES=0
SKIPPED=0
DELETED=0
KEPT=0
log() { printf '%s\n' "$*"; }
fail() { log "FAIL: $*"; FAILURES=$((FAILURES + 1)); }
not_proven() { log "NICHT NACHGEWIESEN: $1 (Werkzeug $2 fehlt)"; SKIPPED=$((SKIPPED + 1)); }

# --- Werkzeuge ---------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
if ! have git; then not_proven "Branch-Hygiene" "git"; exit 2; fi

# --- Konfiguration (Zahlen-SSoT) --------------------------------------------
MAX_AGE_H=""; MAX_ACTIVE=""; WT_EXPIRE=""; TOKEN_REQ="--i-know-what-i-do"
PROTECTED=("main" "master")
DELETE_REMOTE_ALLOWED="false"
load_config() {
  if [ ! -f "$CONFIG" ]; then fail "Konfiguration fehlt: $CONFIG"; return 1; fi
  if ! have jq; then not_proven "Konfigurationswerte (Alter, aktive Branches, Worktree-Frist)" "jq"; return 1; fi
  MAX_AGE_H="$(jq -r '.vcs.branch_max_age_hours' "$CONFIG")"
  MAX_ACTIVE="$(jq -r '.vcs.max_active_task_branches' "$CONFIG")"
  WT_EXPIRE="$(jq -r '.vcs.worktree_prune_expire_days' "$CONFIG")"
  TOKEN_REQ="$(jq -r '.vcs.require_confirm_token' "$CONFIG")"
  DELETE_REMOTE_ALLOWED="$(jq -r '.vcs.delete_remote_allowed' "$CONFIG")"
  mapfile -t PROTECTED < <(jq -r '.vcs.protected_branches[]' "$CONFIG")
  return 0
}

# --- Repository-Fakten ------------------------------------------------------
in_repo() { git rev-parse --git-dir >/dev/null 2>&1; }
default_branch() {
  local d
  d="$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE_NAME/HEAD" 2>/dev/null)" && { printf '%s\n' "${d#"$REMOTE_NAME"/}"; return 0; }
  for d in main master; do
    git show-ref --verify --quiet "refs/heads/$d" && { printf '%s\n' "$d"; return 0; }
  done
  git symbolic-ref --quiet --short HEAD 2>/dev/null || printf '%s\n' ""
}
registered_branches() { # Branches, die ein laufender Orchestrator im State haelt
  local f
  have jq || return 0
  for f in "$PWD"/runtime/state/*.json; do
    [ -f "$f" ] || continue
    jq -r '(.vcs.branches // [])[].name' "$f" 2>/dev/null
  done
}
worktree_branches() {
  git worktree list --porcelain 2>/dev/null | while read -r key value; do
    [ "$key" = "branch" ] && printf '%s\n' "${value#refs/heads/}"
  done
}
is_protected() {
  local b="$1" p
  [ "$b" = "$DEFAULT" ] && return 0
  for p in "${PROTECTED[@]}"; do
    # shellcheck disable=SC2053
    [[ "$b" == $p ]] && return 0
  done
  return 1
}
is_merged() { # 0 = merged, 1 = unmerged, 2 = nicht feststellbar
  local b="$1" base=""
  if git show-ref --verify --quiet "refs/heads/$DEFAULT"; then base="refs/heads/$DEFAULT"
  elif git show-ref --verify --quiet "refs/remotes/$REMOTE_NAME/$DEFAULT"; then base="refs/remotes/$REMOTE_NAME/$DEFAULT"
  else return 2; fi
  git merge-base --is-ancestor "refs/heads/$b" "$base" 2>/dev/null && return 0
  return 1
}
pr_state() { # gibt "offen" | "keiner" | "unbekannt"
  local b="$1"
  [ "$PR_CHECK" = "off" ] && { printf 'keiner\n'; return 0; }
  have gh || { printf 'unbekannt\n'; return 0; }
  local out
  out="$(gh pr list --head "$b" --state open --json number 2>/dev/null)" || { printf 'unbekannt\n'; return 0; }
  case "$out" in "["*"]") [ "$out" = "[]" ] && printf 'keiner\n' || printf 'offen\n' ;; *) printf 'unbekannt\n' ;; esac
}
age_hours() {
  local ts now
  ts="$(git for-each-ref --format='%(committerdate:unix)' "refs/heads/$1")"
  now="$(date +%s)"
  [ -n "$ts" ] && printf '%s\n' $(( (now - ts) / 3600 )) || printf '?\n'
}

# Entscheidung je Branch. Setzt DECISION und REASON.
decide() {
  local b="$1" merged="$2" pr="$3"
  DECISION="behalten"; REASON=""
  if is_protected "$b"; then DECISION="behalten"; REASON="deny_protected: Default-/geschuetzter Branch"; return; fi
  if [ "$b" = "$CURRENT" ]; then DECISION="behalten"; REASON="deny_current: aktueller Branch"; return; fi
  case " $REGISTERED " in *" $b "*) DECISION="behalten"; REASON="deny_registered: im State registriert (laufender Auftrag)"; return ;; esac
  case " $WT_BRANCHES " in *" $b "*) DECISION="behalten"; REASON="deny_worktree: in einem Worktree ausgecheckt"; return ;; esac
  case "$merged" in
    unmerged) DECISION="behalten"; REASON="deny_unmerged: nicht in $DEFAULT enthalten"; return ;;
    unbekannt) DECISION="behalten"; REASON="deny_unknown_merge: Merge-Status nicht feststellbar"; return ;;
  esac
  if [ "$pr" = "offen" ]; then DECISION="behalten"; REASON="deny_open_pr: offener PR/MR"; return; fi
  if [ "$pr" = "unbekannt" ]; then
    DECISION="behalten"; REASON="deny_pr_unknown: PR-Status nicht feststellbar (gh fehlt) — Verweigerung statt Annahme; --pr-check off uebernimmt die Verantwortung"
    return
  fi
  DECISION="loeschbar"; REASON="lokal loeschbar (gemergt, ungeschuetzt, kein offener PR)"
}

# --- Bericht ----------------------------------------------------------------
report_and_act() {
  in_repo || { not_proven "Branch-Hygiene" "git-Repository im aktuellen Verzeichnis"; return 2; }
  load_config || true
  DEFAULT="$(default_branch)"
  CURRENT="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf '(detached)')"
  REGISTERED="$(registered_branches | tr '\n' ' ')"
  WT_BRANCHES="$(worktree_branches | tr '\n' ' ')"

  log "Branch-Hygiene-Bericht"
  log "  Repository:      $PWD"
  log "  Default-Branch:  ${DEFAULT:-<unbekannt>}"
  log "  Aktiver Branch:  $CURRENT"
  log "  Modus:           $MODE (Dry-Run ist Default; Loeschung nur mit --apply-local)"
  log "  PR-Pruefung:     $PR_CHECK$( [ "$PR_CHECK" = off ] && printf ' (PR-Kriterium abgeschaltet, Verantwortung beim Aufrufer)')"
  log "  Grenzwerte:      Alter/aktive Branches/Worktree-Frist aus ${CONFIG#"$LAWBOOK_ROOT"/}${MAX_AGE_H:+ (${MAX_AGE_H} h / ${MAX_ACTIVE} / ${WT_EXPIRE} d)}"
  log ""
  printf '%-46s %7s %-9s %-10s %s\n' "BRANCH" "ALTER_H" "GEMERGT" "PR" "EMPFEHLUNG"

  local b merged pr age active=0 candidates=0 stale=0
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    case "$(is_merged "$b"; printf '%s' $?)" in
      0) merged="ja" ;;
      1) merged="unmerged" ;;
      *) merged="unbekannt" ;;
    esac
    pr="$(pr_state "$b")"
    age="$(age_hours "$b")"
    decide "$b" "$merged" "$pr"
    is_protected "$b" || active=$((active + 1))
    if [ -n "$MAX_AGE_H" ] && [ "$age" != "?" ] && [ "$age" -gt "$MAX_AGE_H" ] 2>/dev/null && ! is_protected "$b"; then
      stale=$((stale + 1))
    fi
    printf '%-46s %7s %-9s %-10s %s\n' "$b" "$age" "$merged" "$pr" "$DECISION ($REASON)"
    if [ "$DECISION" = "loeschbar" ]; then
      candidates=$((candidates + 1))
      if [ "$MODE" = "apply-local" ]; then
        # Nur der sichere Loeschmodus: -d verweigert selbst noch Unmerged. Kein -D, kein --force.
        if git branch -d "$b" >/dev/null 2>&1; then
          log "  gelöscht (lokal, gemergt): $b"; DELETED=$((DELETED + 1))
        else
          fail "git branch -d $b verweigert — Referenz unveraendert"
        fi
      fi
    else
      KEPT=$((KEPT + 1))
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | LC_ALL=C sort)

  log ""
  log "Zusammenfassung: $candidates Loeschkandidat(en), $KEPT geschuetzt/behalten, $DELETED geloescht."
  if [ -n "$MAX_AGE_H" ]; then
    log "  Ueber der Lebensdauer-Grenze: $stale (Bericht, keine Loeschung)."
    if [ -n "$MAX_ACTIVE" ] && [ "$active" -gt "$MAX_ACTIVE" ]; then
      log "  Hinweis: $active aktive Task-Branches ueber dem Zielwert $MAX_ACTIVE — Bericht, keine Loeschung."
    fi
  fi
  if [ "$MODE" != "apply-local" ]; then
    log "  Keine Referenz veraendert (Dry-Run). Loeschen: $0 --apply-local"
  fi

  if [ "$WORKTREES" -eq 1 ]; then
    log ""
    log "Worktree-Vorschau:"
    if [ "$MODE" = "apply-local" ]; then
      git worktree prune --verbose --expire "${WT_EXPIRE:-14}.days" || fail "worktree prune fehlgeschlagen"
    else
      git worktree prune --dry-run --verbose --expire "${WT_EXPIRE:-14}.days" || fail "worktree prune --dry-run fehlgeschlagen"
    fi
  fi
  return 0
}

# --- Remote-Loeschung (Verbot 4) --------------------------------------------
remote_delete() {
  in_repo || { not_proven "Remote-Loeschung" "git-Repository"; return 2; }
  load_config || true
  DEFAULT="$(default_branch)"
  CURRENT="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || printf '(detached)')"
  local b="$REMOTE_BRANCH"
  [ -n "$b" ] || { fail "--remote braucht einen Branch-Namen"; return 1; }
  if [ "$DELETE_REMOTE_ALLOWED" != "true" ]; then
    fail "deny_remote: Remote-Loeschung ist per Konfiguration untersagt (vcs.delete_remote_allowed=false) — Zustaendigkeit: Mensch oder Plattform"
    return 1
  fi
  if [ "$CONFIRM_TOKEN" != "$TOKEN_REQ" ]; then
    fail "deny_remote: Freigabe-Token fehlt (erwartet $TOKEN_REQ)"
    return 1
  fi
  if [ "$CONFIRM_BRANCH" != "$b" ]; then
    fail "deny_remote: zusaetzliche Bestaetigung fehlt (--confirm-delete-remote $b)"
    return 1
  fi
  if is_protected "$b"; then fail "deny_protected: $b ist Default-/geschuetzter Branch"; return 1; fi
  local pr; pr="$(pr_state "$b")"
  if [ "$pr" != "keiner" ]; then
    fail "deny_open_pr: PR-Status ist '$pr' — bei offenem oder nicht feststellbarem PR wird nicht geloescht"
    return 1
  fi
  # Erreicht nur, wenn Konfiguration, Freigabe-Token (require_confirm_token) und
  # Bestaetigung vorliegen und kein offener PR existiert:
  git push "$REMOTE_NAME" --delete "$b" || { fail "Remote-Loeschung fehlgeschlagen"; return 1; }
  log "gelöscht (remote, freigegeben): $REMOTE_NAME/$b"
  DELETED=$((DELETED + 1))
  return 0
}

# --- Selbsttest der Verbote (AK-064) ----------------------------------------
# Legt ein Wegwerf-Repository an und weist nach, dass jedes Verbot greift.
# Beruehrt das aufrufende Repository nicht.
self_test() {
  local tmp rc out ok=1
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/branch-hygiene-selftest.XXXXXX")" || { fail "mktemp"; return 1; }
  (
    cd "$tmp" || exit 1
    git init -q -b main .
    git config user.email t@example.invalid; git config user.name Test
    printf 'a\n' > f; git add f; git commit -qm init
    git branch develop
    git checkout -qb merged-branch; printf 'b\n' >> f; git commit -qam merged
    git checkout -q main; git merge -q merged-branch
    git checkout -qb unmerged-branch; printf 'c\n' >> f; git commit -qam unmerged
    git checkout -q main
    git checkout -qb current-branch
    mkdir -p runtime/state
    printf '{"vcs":{"default_branch":"main","branches":[{"name":"registered-branch"}]}}\n' > runtime/state/orc-test.json
    git branch registered-branch main
  ) || { fail "Wegwerf-Repo konnte nicht angelegt werden"; rm -rf "$tmp"; return 1; }

  expect_in() { # $1 = Beschreibung, $2 = Muster, $3 = Ausgabe
    if printf '%s' "$3" | grep -q -- "$2"; then log "  PASS: $1"; else log "  FAIL: $1 (Muster '$2' fehlt)"; ok=0; fi
  }

  log "Selbsttest der Loeschverbote (Wegwerf-Repo: $tmp)"
  # 1. Lauf mit aktiver PR-Pruefung: nicht feststellbar => Verweigerung (Verbot 3).
  out="$( cd "$tmp" && "$SELF" --apply-local 2>&1 )"; rc=$?
  expect_in "Verbot 3 — offener PR nicht feststellbar, also keine Loeschung" "deny_pr_unknown" "$out"
  ( cd "$tmp" && git show-ref --verify --quiet refs/heads/merged-branch ) \
    && log "  PASS: gemergter Branch bei unklarem PR-Status erhalten" \
    || { log "  FAIL: gemergter Branch trotz unklarem PR-Status geloescht"; ok=0; }

  # 2. Lauf mit abgeschalteter PR-Pruefung: nur der gemergte darf fallen.
  out="$( cd "$tmp" && "$SELF" --apply-local --pr-check off 2>&1 )"; rc=$?
  expect_in "Verbot 1 — Default-Branch bleibt"      "main .*deny_protected"    "$out"
  expect_in "Verbot 1 — geschuetzter Branch bleibt" "develop .*deny_protected" "$out"
  expect_in "Verbot 2 — unmerged bleibt"            "deny_unmerged"            "$out"
  expect_in "aktueller Branch bleibt"               "deny_current"             "$out"
  expect_in "registrierter Branch bleibt"           "deny_registered"          "$out"

  # 3. Remote-Loeschung ohne Freigabe (Verbot 4).
  out="$( cd "$tmp" && "$SELF" --remote merged-branch 2>&1 )"; rc=$?
  expect_in "Verbot 4 — Remote ohne Freigabe verweigert" "deny_remote" "$out"

  # 4. Refs nachzaehlen: alle geschuetzten erhalten, genau der gemergte weg.
  local b
  for b in main develop unmerged-branch current-branch registered-branch; do
    if ( cd "$tmp" && git show-ref --verify --quiet "refs/heads/$b" ); then
      log "  PASS: Referenz erhalten: $b"
    else
      log "  FAIL: Referenz verloren: $b"; ok=0
    fi
  done
  if ( cd "$tmp" && git show-ref --verify --quiet refs/heads/merged-branch ); then
    log "  FAIL: gemergter Branch wurde von --apply-local nicht geloescht"; ok=0
  else
    log "  PASS: genau der gemergte Branch wurde geloescht"
  fi
  rm -rf "$tmp"
  [ "$ok" -eq 1 ] || FAILURES=$((FAILURES + 1))
  return 0
}

case "$MODE" in
  report|apply-local) report_and_act || true ;;
  remote) remote_delete || true ;;
  self-test) self_test || true ;;
esac

if [ "$FAILURES" -gt 0 ]; then
  log "FAIL: $FAILURES verweigerte oder fehlgeschlagene Aktion(en)."
  exit 1
fi
if [ "$SKIPPED" -gt 0 ]; then
  log "NICHT NACHGEWIESEN: $SKIPPED Pruefung(en) nicht ausgefuehrt — das ist kein Bestehen."
  exit 2
fi
exit 0
