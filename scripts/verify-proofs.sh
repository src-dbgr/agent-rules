#!/usr/bin/env bash
# Verify executable DoD proofs for agent-rules (LAW-DOD).
# Usage: ./scripts/verify-proofs.sh [--allow-skip]
#
# Exit-Semantik (ADR-009 §2, F-033/AK-082/AK-083 - identisch in allen Pruefskripten):
#   0  alle Nachweise gefuehrt und bestanden
#   1  mindestens ein Nachweis GESCHEITERT
#   2  mindestens ein Nachweis NICHT NACHGEWIESEN (Werkzeug fehlt) - ohne --allow-skip
# Ein fehlendes Werkzeug ist ausdruecklich KEIN Bestehen. "All executed proofs passed"
# wird nur ohne jedes SKIP ausgegeben. --allow-skip degradiert 2 -> 0, ist lokal
# gedacht und wird verweigert, wenn $CI gesetzt ist.
# Vorrang bei gemischtem Ergebnis: FAIL (1) vor SKIP (2) - "falsch" ist schwerer als
# "unbewiesen".
#
# Inhalte der TLA+-/Spec-Nachweise sind hier unveraendert; sie gehoeren WP-5.

set -euo pipefail

ALLOW_SKIP=0
for arg in "$@"; do
  case "$arg" in
    --allow-skip) ALLOW_SKIP=1 ;;
    --help|-h) sed -n '2,16p' "$0"; exit 0 ;;
    *) printf 'FAIL: unbekannte Option %s\n' "$arg" >&2; exit 1 ;;
  esac
done
if [[ "$ALLOW_SKIP" -eq 1 && -n "${CI:-}" ]]; then
  printf 'FAIL: --allow-skip ist in CI verboten (config/policy-defaults.json#/enforcement/allow_skip_in_ci)\n' >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="${ROOT}/proof-artifacts"
mkdir -p "$ARTIFACTS"

FAILURES=0
SKIPPED=0
log() { printf '%s\n' "$*"; }
not_proven() { # $1 = Nachweis, $2 = fehlendes Werkzeug
  log "NICHT NACHGEWIESEN: $1 (Werkzeug $2 fehlt)"
  SKIPPED=$((SKIPPED + 1))
}

# --- 1. JSON Schema (ajv) ---
log "==> ajv: validate examples/agent-state.example.json"
if ! command -v npx >/dev/null 2>&1; then
  not_proven "ajv (State-Schema)" "npx/node"
elif npx -y -p ajv-cli@5 -p ajv-formats ajv validate \
  -s schemas/agent-state.schema.json \
  -d examples/agent-state.example.json \
  --spec=draft2020 \
  -c ajv-formats \
  2>&1 | tee "$ARTIFACTS/ajv_agent_state.log"; then
  log "ajv: PASS"
else
  log "ajv: FAIL"
  FAILURES=$((FAILURES + 1))
fi

# --- 2. Secret scan (gitleaks) ---
log ""
log "==> gitleaks: scan repository"
GITLEAKS=""
if command -v gitleaks >/dev/null 2>&1; then
  GITLEAKS="gitleaks"
elif [[ -x "${ROOT}/lib/gitleaks" ]]; then
  GITLEAKS="${ROOT}/lib/gitleaks"
else
  not_proven "gitleaks (Secret-Scan)" "gitleaks"
fi

if [[ -n "$GITLEAKS" ]]; then
  if "$GITLEAKS" detect --source "$ROOT" --no-git \
    2>&1 | tee "$ARTIFACTS/gitleaks_scan.log"; then
    log "gitleaks: PASS"
  else
    log "gitleaks: FAIL"
    FAILURES=$((FAILURES + 1))
  fi
fi

# --- 3. TLA+ model check (TLC) ---
log ""
log "==> TLC: model-check specs/workflow.tla"
TLA_JAR="${ROOT}/lib/tla2tools.jar"
TLA_URL="https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar"

if [[ ! -f "$TLA_JAR" ]]; then
  log "Downloading tla2tools.jar ..."
  mkdir -p "${ROOT}/lib"
  if ! curl -fsSL -o "$TLA_JAR" "$TLA_URL"; then
    rm -f "$TLA_JAR"
    log "Download fehlgeschlagen: $TLA_URL"
  fi
fi

JAVA_BIN=""
if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
  JAVA_BIN="${JAVA_HOME}/bin/java"
elif command -v java >/dev/null 2>&1; then
  if java -version >/dev/null 2>&1; then
    JAVA_BIN="java"
  fi
fi

if [[ -z "$JAVA_BIN" && -x /usr/libexec/java_home ]]; then
  export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    JAVA_BIN="${JAVA_HOME}/bin/java"
  fi
fi

if [[ ! -f "$TLA_JAR" ]]; then
  not_proven "TLC (Modell-Sonde)" "lib/tla2tools.jar"
elif [[ -z "$JAVA_BIN" ]]; then
  not_proven "TLC (Modell-Sonde)" "java"
else
  if "$JAVA_BIN" -XX:+UseParallelGC -cp "$TLA_JAR" tlc2.TLC \
    -config specs/workflow.cfg specs/workflow.tla \
    2>&1 | tee "$ARTIFACTS/tlc_termination.log"; then
    log "TLC: PASS"
  else
    log "TLC: FAIL"
    FAILURES=$((FAILURES + 1))
  fi
fi

log ""
log "Zusammenfassung: $FAILURES gescheitert, $SKIPPED NICHT NACHGEWIESEN."
if [[ "$FAILURES" -gt 0 ]]; then
  log "$FAILURES proof(s) failed."
  exit 1
fi
if [[ "$SKIPPED" -gt 0 ]]; then
  log "NICHT NACHGEWIESEN: $SKIPPED Nachweis(e) wurden nicht ausgefuehrt - das ist kein Bestehen."
  if [[ "$ALLOW_SKIP" -eq 1 ]]; then
    log "Hinweis: --allow-skip degradiert Exit 2 auf 0. SKIP bleibt kein PASS."
    exit 0
  fi
  exit 2
fi
log "All executed proofs passed."
exit 0
