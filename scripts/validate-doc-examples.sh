#!/usr/bin/env bash
# Validiert JSON-Beispiele unter examples/ gegen Schemata.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v npx >/dev/null || { echo "NICHT NACHGEWIESEN: npx"; exit 2; }
ajv() { npx -y -p ajv-cli@5 -p ajv-formats ajv validate "$@" --spec=draft2020 -c ajv-formats; }
ajv -s "$ROOT/schemas/agent-state.schema.json" -d "$ROOT/examples/agent-state.example.json"
echo "PASS validate-doc-examples"
