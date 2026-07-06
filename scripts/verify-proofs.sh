#!/usr/bin/env bash
# Verify executable DoD proofs for agent-rules (Gesetz 6).
# Usage: ./scripts/verify-proofs.sh
# Exit 0 only if all available proofs pass.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARTIFACTS="${ROOT}/proof-artifacts"
mkdir -p "$ARTIFACTS"

FAILURES=0
log() { printf '%s\n' "$*"; }

# --- 1. JSON Schema (ajv) ---
log "==> ajv: validate .agent-state.json"
if npx -y -p ajv-cli@5 -p ajv-formats ajv validate \
  -s schemas/agent-state.schema.json \
  -d .agent-state.json \
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
  log "gitleaks: SKIP (not on PATH; install via 'brew install gitleaks' or place binary at lib/gitleaks)"
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
  curl -fsSL -o "$TLA_JAR" "$TLA_URL"
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

if [[ -z "$JAVA_BIN" ]]; then
  log "TLC: SKIP (Java runtime not found; set JAVA_HOME or install Temurin/OpenJDK)"
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
if [[ "$FAILURES" -eq 0 ]]; then
  log "All executed proofs passed."
  exit 0
else
  log "$FAILURES proof(s) failed."
  exit 1
fi
