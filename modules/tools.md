# Werkzeuge — Rechte, Nachweise, Verbote

> Normativ für `LAW-DOD`. Rollenrechte hier; Mandat in `roles/<rolle>.md`.
> Zahlen und Skip-Semantik: `config/policy-defaults.json#/enforcement`.

## Matrix (Auszug)

| Aktion | Orch. | Developer | Tester | Security | DevOps | Memory Curator |
|--------|-------|-----------|--------|----------|--------|----------------|
| Dateien lesen | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Produktionscode schreiben | ❌ | ✅ | ❌ (Tests ✅) | ❌ | ⚠️ CI | ❌ |
| State schreiben | ✅ | ❌ | ❌ | ❌ | ❌ | ⚠️ Memory |
| git commit | ❌ | ⚠️ | ❌ | ❌ | ⚠️ | ❌ |
| git push / PR | ❌ | ⚠️ an `N6b` | ❌ | ❌ | ⚠️ an `N6b` | ❌ |
| Sub-Agent spawnen | ✅ | ⚠️ Tiefe | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| Memory-Store schreiben | ⚠️ als Curator | ❌ | ❌ | ❌ | ❌ | ✅ an `N7` |

⚠️ = eingeschränkt auf Mandat und Knoten. Volle Matrix je Rolle: Rollen-Karte.

## LLM-Auswahl {#llm}

Maßgeblich und **allein** verbindlich: `config/model-policy.json` (`LAW-MODELS`).

1. **Entry Point:** Main-Thread/Orchestrator (`N0`–`N2`, `N7`) startet mit
   `entry_points.orchestrator_main_thread` — Default `grok-4.5-high`, nie Composer/Grok-Low.
   Die Triage-Algebra ist deterministisch; die Erst-Klassifikation nicht.
2. **Sub-Agenten:** Leiter von Rank 1 (Composer) aufwärts; Aufstieg nur mit kurzer
   Begründung im Handover.
3. Einträge unter `never` sind hart verboten (inkl. Composer-as-Orchestrator).
4. API für externe Modelle erschöpft: `fallback_when_external_api_exhausted`
   (Orchestrator bleibt auf Grok High; Sub-Agenten Composer→Grok).
5. Gewähltes Modell in State `model_usage[]` protokollieren (`entry_point` setzen).
6. Datei bei Marktwechsel anpassen — **nicht** in `AGENTS.md` hardcoden.

## Verifizierung {#verifizierung}

Jeder Gate-Nachweis in `dod_gates` braucht:

- `proof_type`, `proof_command`, `proof_exit_code`, optional `proof_artifact_path`
- Exit **0** = bestanden
- Exit **1** = fehlgeschlagen
- Exit **2** = **NICHT NACHGEWIESEN** (Tool fehlt / übersprungen)

`SKIP` ist **nie** `PASS`. `--allow-skip` nur lokal; in CI verboten
(`enforcement.allow_skip_in_ci: false`).

Beispiele (projektabhängig):

| Zweck | Befehl |
|-------|--------|
| Schema | `npx -y -p ajv-cli@5 -p ajv-formats ajv validate -s schemas/agent-state.schema.json -d runtime/state/<id>.json --spec=draft2020 -c ajv-formats` |
| Lawbook | `bash scripts/lint-lawbook.sh --all --strict` |
| Triage | `bash scripts/check-triage.sh` |
| Secrets | `gitleaks detect --source runtime --no-git` |
| GC | `bash scripts/gc-sweep.sh --dry-run` |
| Branches | `bash scripts/branch-hygiene.sh --report` |

Nachweis-Logs unter `proof-artifacts/` (Retention: config).

## Verbote

```
git push --force
git reset --hard          # ohne Nutzerfreigabe
rm -rf / /workspace/.git
DROP DATABASE
curl | sh                 # unverifizierte Remote-Skripte
```

Bei Unsicherheit: Hard Error an Orchestrator, nicht ausführen.

## Betreiber

Empfohlen im Zielprojekt: Node 20+, `jq`, Java 17+ (nur wenn TLA+-Sonde läuft),
`gitleaks` auf PATH. Fehlt ein Pflicht-Tool in CI → Exit 2, Pipeline rot.

## Rollen-Anker

Rechte und Verbote für `researcher`: siehe Matrix oben und `roles/researcher.md`. {#researcher}

Rechte und Verbote für `business_analyst`: siehe Matrix oben und `roles/business_analyst.md`. {#business_analyst}

Rechte und Verbote für `architect`: siehe Matrix oben und `roles/architect.md`. {#architect}

Rechte und Verbote für `developer`: siehe Matrix oben und `roles/developer.md`. {#developer}

Rechte und Verbote für `tester_reviewer`: siehe Matrix oben und `roles/tester_reviewer.md`. {#tester_reviewer}

Rechte und Verbote für `ux_ui_expert`: siehe Matrix oben und `roles/ux_ui_expert.md`. {#ux_ui_expert}

Rechte und Verbote für `security_auditor`: siehe Matrix oben und `roles/security_auditor.md`. {#security_auditor}

Rechte und Verbote für `documentation_specialist`: siehe Matrix oben und `roles/documentation_specialist.md`. {#documentation_specialist}

Rechte und Verbote für `devops_sre`: siehe Matrix oben und `roles/devops_sre.md`. {#devops_sre}

Rechte und Verbote für `data_engineer`: siehe Matrix oben und `roles/data_engineer.md`. {#data_engineer}

Rechte und Verbote für `performance_engineer`: siehe Matrix oben und `roles/performance_engineer.md`. {#performance_engineer}

Rechte und Verbote für `compliance_governance`: siehe Matrix oben und `roles/compliance_governance.md`. {#compliance_governance}

Rechte und Verbote für `memory_curator`: siehe Matrix oben und `roles/memory_curator.md`. {#memory_curator}

Rechte und Verbote für `sub_orchestrator`: siehe Matrix oben und `roles/sub_orchestrator.md`. {#sub_orchestrator}

