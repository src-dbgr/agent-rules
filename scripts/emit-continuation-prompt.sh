#!/usr/bin/env bash
# emit-continuation-prompt.sh — Copy-Paste-Prompt für frischen Orchestrator (LAW-CONTEXT).
# Exit: 0 PASS | 1 FAIL | 2 NICHT NACHGEWIESEN
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT}/prompts/continuation-prompt.md"
POLICY="${ROOT}/config/policy-defaults.json"
STATE=""
OUT=""
PREV_ID=""

die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
skip() { printf 'NICHT NACHGEWIESEN: %s\n' "$*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state) STATE="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --previous-id) PREV_ID="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: emit-continuation-prompt.sh --state runtime/state/<id>.json [--out file] [--previous-id id]"
      exit 0 ;;
    *) die "unbekannt: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || skip "jq fehlt"
command -v python3 >/dev/null 2>&1 || skip "python3 fehlt"
[[ -f "$TEMPLATE" ]] || die "Template fehlt"
[[ -n "$STATE" && -f "$STATE" ]] || die "--state erforderlich"
[[ -f "$POLICY" ]] || die "policy fehlt"

WARN="$(jq -r '.budgets.rotation.percent_warn // 60' "$POLICY")"
HAND="$(jq -r '.budgets.rotation.percent_handoff // 70' "$POLICY")"

emit() {
  python3 - "$TEMPLATE" "$STATE" "$WARN" "$HAND" "${PREV_ID}" <<'PY'
import json, sys, datetime, re, uuid
from pathlib import Path
template_path, state_path, warn, hand, prev = sys.argv[1:6]
state = json.loads(Path(state_path).read_text())
text = Path(template_path).read_text()
m = re.search(r"```\n(.*?)```", text, re.S)
body = m.group(1) if m else text
orch = state.get("orchestrator_id", "UNKNOWN")
prev_id = prev or orch
assignments = state.get("assignments") or []
asn = "; ".join(
    f"{a.get('task_id','?')} | {a.get('role','?')} | {a.get('status')} | node={a.get('cfg_node')}"
    for a in assignments
    if a.get("status") in ("open", "running", "returned", "failed")
) or "(keine offenen)"
findings = []
for b in (state.get("blockers") or [])[:5]:
    if not b.get("resolved_at"):
        findings.append(f"- blocker: {str(b.get('message',''))[:160]}")
for a in (state.get("assumptions") or [])[:5]:
    findings.append(f"- annahme: {str(a.get('statement',''))[:160]}")
findings_txt = "\n".join(findings) or "- (keine Kurz-Findings im State — Ledger + active_node nutzen)"
triage = state.get("triage") or {}
cfg = state.get("cfg") or {}
budget = state.get("budget") or {}
signals = triage.get("signals") or []
if isinstance(signals, list):
    signals = ",".join(map(str, signals))
repl = {
    "orchestrator_id": orch,
    "previous_orchestrator_id": prev_id,
    "original_user_prompt": (state.get("original_user_prompt") or "").strip() or "(fehlt im State)",
    "phase": state.get("phase", "executing"),
    "active_node": cfg.get("active_node", "N2"),
    "change_class": triage.get("change_class") or "feature",
    "signals": signals or "(keine)",
    "assignments_summary": asn,
    "findings_bullets": findings_txt,
    "next_step": f"Setze an Knoten {cfg.get('active_node','N2')} fort; offene Assignments prüfen; nicht blind bei N0 neu starten.",
    "budget_json": json.dumps(budget, ensure_ascii=False),
    "created_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}
out = body
for k, v in repl.items():
    out = out.replace("{{" + k + "}}", str(v))
print(f"CONTEXT_HANDOFF — gesamten Block in einen NEUEN Agent-Chat kopieren.")
print(f"Schwellwerte: Warnung {warn}% · Pflicht-Handoff {hand}% (config/policy-defaults.json).")
print(f"handoff_id: {uuid.uuid4()}")
print()
print("```")
print(out)
print("```")
PY
}

if [[ -n "$OUT" ]]; then
  emit >"$OUT"
  printf 'PASS wrote %s\n' "$OUT" >&2
else
  emit
fi
printf 'PASS emit-continuation-prompt\n' >&2
