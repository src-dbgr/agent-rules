#!/usr/bin/env bash
# Prüft, dass referenzierte scripts/*.sh existieren.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v rg >/dev/null || { echo "NICHT NACHGEWIESEN: rg"; exit 2; }
bad=0
while IFS= read -r s; do
  [[ -z "$s" ]] && continue
  if [[ ! -f "$ROOT/$s" ]]; then
    echo "FAIL missing script ref: $s"
    bad=1
  fi
done < <(rg -o --no-filename 'scripts/[a-z0-9_-]+\.sh' "$ROOT" --glob '!runtime/**' --glob '!.git/**' | sort -u)
(( bad == 0 )) && echo "PASS check-doc-commands"
exit "$bad"
