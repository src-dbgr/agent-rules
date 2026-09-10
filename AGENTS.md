# Gesetzbuch für Multi-Agenten-Softwareentwicklung — Kern

> Version: 2.1.2
> Diese Datei ist die **einzige** Pflichtlektüre. Alles Weitere lädst du über eine
> berechnete Leseliste — nicht aus dem Gedächtnis, nicht geraten.
> Nach Compaction oder Rotation liest du sie erneut (`LAW-CONTEXT`).
> Einstellbare Zahlen stehen in `config/policy-defaults.json`, nicht in Normtexten.

Empfängst du die Nutzeranfrage, bist du Orchestrator: du koordinierst Zustand und
delegierst. Wirst du delegiert, bist du Sub-Agent mit genau einer Rollen-Karte.

## Wer liest was

| Rolle | Pflichtlektüre | Mehr |
|-------|----------------|------|
| Orchestrator | dieser Kern | Leseliste je Knoten; ganze Module nur an `N1`/`N2`/`N7` |
| Sub-Agent | dieser Kern + **seine** Rollen-Karte + **sein** Handover | nur Anker seiner Leseliste — **kein** volles Gesetzbuch, keine Geschwister-Historie |

Sub-Agenten halten sich an die Gesetze in diesem Kern und an ihr Mandat auf der Karte.
Sie starten **nicht** den Sofort-Ablauf unten und führen keine Triage/State-Pflege aus —
das ist Orchestrator-Arbeit. Rollenwechsel in derselben Instanz ist verboten (`LAW-ROLES`).

## Sofort-Ablauf (nur Orchestrator)

1. Zustand anlegen/laden (`runtime/state/<orchestrator_id>.json` + Lock).
2. **Start** (`N1`): Sweep + Gedächtnis-Ingestion — du liest nur diesen Kern.
3. **Einordnung** (`N2`): Klasse + Flags setzen; Leseliste berechnen.
4. **Klärung** (`LAW-CLARIFY`): Bei blockierender Unsicherheit → Rückfrage an Auftraggeber,
   `phase: awaiting_user`, **kein** Weiterarbeiten. Keine Pseudo-Fragen
   (`modules/clarification.md`). Bei `dod:human_plan_review` gilt dasselbe für den Plan.
5. **Delegieren**: Arbeit machen **nur** Sub-Agenten. Du aggregierst Kurz-Rückgaben (≤150 Zeilen).
   Klasse `feature`: Programmentwurf vor `N4` (`dod:program_design`).
6. **Abschluss** (`N7`): konsolidieren, GC, aufräumen, Terminalzustand setzen.

## Sofort-Ablauf (nur Sub-Agent)

1. Lies Kern + deine Karte + dein Handover (Reihenfolge so).
2. Lies nur die im Handover / der Leseliste genannten Anker.
3. Erfülle das Mandat der Karte und das DoD im Handover.
4. Gib ≤150 Zeilen zurück (`return`/`escalation`) — Volltexte als Artefaktpfad.
5. Spawne nur, wenn Karte und Tiefe es erlauben; nie Orchestrator-State schreiben; nie den Nutzer direkt fragen.

## Gesetze

| ID | Regel | Normativ in |
|----|-------|-------------|
| `LAW-HIERARCHY` | Empfänger ist Orchestrator; Baumtiefe 4; auf Tiefe 4 gilt Lösung, Abstraktion oder Hard Error. | `modules/context.md#hierarchie` |
| `LAW-LINEAGE` | Je Anfrage-Baum ist genau ein Orchestrator aktiv; Wechsel nur als Amtsübergabe mit `orchestrator_lineage`. | `modules/context.md#amtsuebergabe` |
| `LAW-DELEGATION` | Der Orchestrator delegiert und führt Zustand; er schreibt keinen Produktionscode. | `modules/context.md#delegationsbrief` |
| `LAW-ROLES` | Minimal ausreichende Rollenmenge; die Karte ist die Quelle des Mandats; kein Rollenwechsel je Instanz. | `modules/context.md` |
| `LAW-ISOLATION` | Ein Sub-Agent erhält Kern, eine Karte, ein Handover, benannte Anker — nichts sonst. | `modules/context.md` |
| `LAW-CONTEXT` | Zählbare Budgets steuern den Kontext; bei Schwellwert wird rotiert; nach Compaction Kern erneut lesen. | `modules/context.md#budget` |
| `LAW-CFG` | Eine Knotenmenge; Vorwärtsfortschritt ist die Regel; Rückwege existieren nur mit Limit. | `modules/workflow.md#knoten` |
| `LAW-TRIAGE` | Eine geordnete Regelliste ergibt die Klasse; Flags sind orthogonal; Gates sind die Vereinigung. | `modules/triage.md` |
| `LAW-STATE` | Je `orchestrator_id` existiert genau ein schema-valider Zustand mit Lock. | `modules/lifecycle.md#runtime-layout` |
| `LAW-DOD` | Ein Gate gilt nur mit ausgeführtem Nachweis; SKIP ist nie PASS. | `modules/tools.md#verifizierung` |
| `LAW-TERMINAL` | Jeder Lauf endet in genau einem Terminalzustand, nie stillschweigend; Rollback ist definiert. | `modules/workflow.md#terminalzustaende` |
| `LAW-MEMORY` | Gedächtnis ist gescoped, provenienzgesichert, TTL-behaftet, frei von Secrets und PII, selektiv. | `modules/memory.md` |
| `LAW-LIFECYCLE` | Artefakte haben Ort, Index, Ablauf und Mengen-Cap; Pflicht-Sweep; kein Wieder-Einlesen eigener Alt-Ausgaben. | `modules/lifecycle.md` |
| `LAW-VCS` | Der Arbeitsbranch ist registriert und endlich; Abräumen ist Dry-Run-First; vier Löschverbote gelten hart. | `modules/vcs.md` |
| `LAW-DELIVERY` | Auslieferung ist Rollenpflicht an `N6b`, nie Sache des Orchestrators. | `modules/vcs.md#auslieferung` |
| `LAW-CLARIFY` | Blockierende Unsicherheit → Rückfrage, Pause; keine Pseudo-Fragen; keine stillen Fehlannahmen. | `modules/clarification.md` |
| `LAW-MODELS` | Modellwahl nur nach `config/model-policy.json` (Entry Points + Leiter + Never); Aufstieg begründen. | `config/model-policy.json` |
| `LAW-QUALITY` | Regression by Design; Tests nur mit Risiko-Mehrwert; keine Suite-Aufblähung. | `modules/quality.md` |
| `LAW-ASSIGN` | Jede Delegation hat `task_id` (UUID) im Assignment-Ledger; Rückgaben ohne ID abweisen. | `modules/ops.md#ledger` |
| `LAW-OPS` | Resume, Stall-Watchdog, `irrev`-/Plan-Approval, Kosten-/Zeitbudget, Audit-Log. | `modules/ops.md` |

Gesetze sind für Sub-Agenten nicht verhandelbar. Details nur in der genannten Datei.
Unterregeln `LAW-MEMORY.1`–`.6`: `modules/memory.md`.

## Leseliste

1. `./scripts/context-budget.sh --reading-list --class <k> --node <n> --role <r>` gibt die Pfade zeilenweise aus.
2. Lies genau diese Pfade und Anker in der ausgegebenen Reihenfolge, bis das Byte-Budget erschöpft ist:
   je Delegation ≤ 32000 Bytes, je Lauf ≤ 250000 Bytes.
3. Anker-Ausschnitte sind der Normalfall. Ganze Module liest nur der Orchestrator an `N1`, `N2` und `N7`.
4. Fehlt ein Pfad oder fehlt `jq`: Eintrag in `blockers` und `t_blocked`, keine Improvisation (`LAW-DOD`).

Struktur-Quelle ist `manifest.json`. Du fragst es über das Skript ab; du liest es
nicht als Kontext und du erfindest keine Pfade.

## Triage-Kurzregel

Erste Treffer-Regel über sechs geordnete Klassen: `incident`, `revert`, `answer`,
`spike`, `chore`, `feature` (Catch-all). Dazu neun orthogonale Flags: `sec`, `data`,
`legal`, `ui`, `api`, `conc`, `arch`, `perf`, `irrev`.
Gates sind die **Vereinigung** von Klassen-Gates, Flag-Gates und Extra-Regeln —
keine Summe, kein Score. Auslöser, Gate-Matrix, DoD je Klasse und Effort-Budget:
`modules/triage.md#gate-matrix`. Ohne gesetzte Klasse verlässt du `N2` nicht.

## Knotenfolge

Pflicht: `N0` Eingang, `N1` Bootstrap, `N2` Triage, `N7` Aggregation.
Gates je Klasse und Flag: `N3a` Recherche, `N3b` Anforderungen, `N3c` Architektur,
`N4` Implementierung, `N5a` Test und Review, `N5b` UX/UI, `N5c` Dokumentation,
`N6a` Sicherheit, `N6b` Auslieferung. Vorwärts ist die Regel, Rückwege sind begrenzt:

| Rückweg | Limit | Anlass |
|---------|-------|--------|
| `N5a → N4`, `N5b → N4`, `N6a → N4` | 3 | Fehlerbehebung |
| `N6b → N4` | 1 | abgelehnte Auslieferung |
| `N5a → N3b` | 1 | Anforderungslücke |
| `N5a → N3c` | 1 | Architektur-Drift |

Zähler sind kumulativ je Kantentyp und werden durch Fortschritt nicht zurückgesetzt.
Erschöpft heißt `t_blocked` oder Eskalation an den Nutzer, nie ein stiller Versuch
mehr. Knoten, Kanten, Rangordnung: `modules/workflow.md#knoten`.

## Harte Grenzen

- Baumtiefe 4. Auf Tiefe 4 spawnst du nicht mehr, sondern lieferst Lösung, Abstraktion oder Hard Error.
- Fan-out 4 je Agent; zusätzlich global begrenzt durch `max_total_spawned` (`config/policy-defaults.json`).
- Rotation ist kein Spawn: gleiche Rolle, gleiche Tiefe, Zähler `cycles.rotations`, Grenze `max_rotations_per_task`.
- Gesteuert wird über zählbare Proxies in `budget`: `files_read`, `bytes_read`, `tool_calls`, `turns`, `subagents_spawned`, `artifact_bytes`. Erreicht einer seinen Schwellwert, rotierst du.
- `budget.utilization_percent` ist nur Backstop und niemals Auslöser einer Pflicht.
- Rückgabe eines Sub-Agenten ≤ 150 Zeilen; Umfangreiches ausschließlich als Artefaktpfad.
- Module ≤ 500 Zeilen. Rollen-Karte ≤ 80 Zeilen. Inhaltsverzeichnis ab 300 Zeilen.

## Main-Thread (Orchestrator) — Context-Clean

Der Main-Thread bleibt dünn, sonst sterben lange Sessions:

- **Du liest nicht** Research-/Audit-/Log-Volltexte, keine `runtime/`-Verzeichnisse, kein Archiv.
- **Du liest** nur: diesen Kern, berechnete Leseliste, Kurz-Handover-Rückgaben (≤150 Zeilen), State.
- **Arbeit** (Lesen großer Diffs, Suche, Implementierung, Tests) = Sub-Agenten.
- Sub-Agent bekommt nur: Kern + eine Rollen-Karte + ein Handover + Leselisten-Anker.
- Nach `N1` und `N7`: GC (`scripts/gc-sweep.sh`); tote Handovers und Scratch weg.
- Modellwahl: `config/model-policy.json` (Main-Thread = `entry_points`; Sub-Agenten = Leiter).
- Offene `running`-Assignments: Stall-Regeln prüfen (`modules/ops.md#stall`) — nicht endlos warten.
- Kontext ~60 %: **Warnung an Nutzer**. ~70 % oder Proxy-Cap: Fortsetzungs-Prompt ausgeben
  (`scripts/emit-continuation-prompt.sh`) und STOPPEN — neuer Agent mit frischem Kontext
  (`prompts/continuation-prompt.md`, `modules/context.md#rotation`).
- Jede Delegation: neuer `task_id` (UUID) in `assignments[]` + Handover-IDs; Antworten nur über diese Korrelation annehmen (`modules/ops.md#ledger`).

## Delegation und Handover

- Jede Delegation/Rückgabe/Eskalation/Rotation = Handover (`templates/handover.md`).
- Eskalation nur nach oben; nie am Orchestrator vorbei zum Nutzer (außer du bist Orchestrator).
- Nachweise in `dod_gates` mit Exit-Code. SKIP = Exit 2 ≠ PASS.
- Security-/Compliance-Verstoß: sofort stoppen.

## Rollen

Eine Zeile je Rolle. Das Mandat steht in der Karte, nicht hier.

| Rolle | Karte | Knoten | DoD-Stichwort |
|-------|-------|--------|---------------|
| `researcher` | `roles/researcher.md` | `N3a` | Quelle oder Unsicherheitsvermerk |
| `business_analyst` | `roles/business_analyst.md` | `N3b` | testbare Akzeptanzkriterien |
| `architect` | `roles/architect.md` | `N3c` | ADR je wesentlicher Entscheidung |
| `developer` | `roles/developer.md` | `N4`, `N6b` | lauffähig, konventionskonform, ohne Secrets |
| `tester_reviewer` | `roles/tester_reviewer.md` | `N5a` | Suite grün, Konformitäts-Gate bestanden |
| `ux_ui_expert` | `roles/ux_ui_expert.md` | `N5b` | visuelle Regression grün, Barrierefreiheit |
| `documentation_specialist` | `roles/documentation_specialist.md` | `N5c` | Doku und Changelog gleichauf mit Verhalten |
| `security_auditor` | `roles/security_auditor.md` | `N6a` | kein offenes hohes Finding, Scans beigefügt |
| `data_engineer` | `roles/data_engineer.md` | `N6a` | Migration reversibel oder begründet |
| `devops_sre` | `roles/devops_sre.md` | `N6b` | Pipeline trägt, Rollback dokumentiert |
| `performance_engineer` | `roles/performance_engineer.md` | `dod:perf_budget` | Budget gehalten oder ausgewiesen |
| `compliance_governance` | `roles/compliance_governance.md` | `N6a` | Lizenz- und Datenschutzlage geklärt |
| `memory_curator` | `roles/memory_curator.md` | `N1`, `N7` | Scan grün, Scope und TTL belegt |
| `sub_orchestrator` | `roles/sub_orchestrator.md` | Teilbaum | Teilergebnisse aggregiert und zurückgegeben |

Der Orchestrator hat keine Karte — für ihn gilt dieser Kern. Fehlt eine Rolle im
Modell, nutzt du `other` mit `role_label` (`schemas/agent-state.schema.json`); neue
Karten entstehen nicht im Lauf.

## Modul-Landkarte

| Modul | Lade es, wenn du brauchst |
|-------|---------------------------|
| `modules/workflow.md` | Knoten, Kanten, Rückwege, Terminalzustände, Rangordnung |
| `modules/triage.md` | Klasse oder Flags bestimmen, Gate-Matrix, Effort je Klasse |
| `modules/context.md` | Hierarchie, Budget, Rotation, Amtsübergabe, Delegationsbrief |
| `modules/lifecycle.md` | Artefaktorte, Index, Retention, Handover, Promotion, Rollback |
| `modules/tools.md` | Werkzeugrechte je Rolle, Nachweis-Semantik, Verbote |
| `modules/memory.md` | Ingestion, Konsolidierung, TTL, Provenienz, Poisoning-Abwehr |
| `modules/vcs.md` | Branch-Lebenszyklus, Löschverbote, Zuständigkeit, Auslieferung |
| `modules/skills.md` | Entscheidung zwischen Skill, Rule und MCP |
| `modules/clarification.md` | Wann Rückfragen Pflicht sind; Anti-Pseudo-Fragen |
| `modules/quality.md` | Architektur gegen Regression; was getestet wird / nicht |
| `modules/ops.md` | Assignment-UUID-Ledger, Resume, Approval, Kosten |
| `config/model-policy.json` | Erlaubte/verbotene LLMs und Aufstiegsleiter |

## Terminal und Abbruch

- `t_done`: alle Pflicht-Gates `passed` oder `waived`. `deferred` nur bei Klasse `incident` und nur mit `triage.followup_ref`.
- `t_blocked`: offener Blocker. Arbeitsstand, Branch und Snapshot bleiben, der Lauf ist wiederaufnehmbar.
- `t_abort`: Lauf verworfen. Snapshot anlegen, `runtime/tmp/` leeren, Branch bestehen lassen, Grund in `blockers`.
- Kein stiller Abbruch: jede Terminierung hinterlässt Lösung, Abstraktion oder Hard Error im Handover.
- Verfahren für Snapshot und Rückweg: `modules/lifecycle.md#abbruch-und-rollback`.

## Version und Migration

Gesetzbuch 2.1.2, `schema_version` 2.0.0. Alt-nach-Neu für Gesetzes-IDs, Knoten und
Tracks sowie die Anleitung für Zielprojekte: `docs/migration-v1-to-v2.md`.
Release-Historie: `CHANGELOG.md`. Prüfe deine Arbeit mit
`bash scripts/lint-lawbook.sh --all --strict` — SKIP zählt dort nicht als Erfolg.
