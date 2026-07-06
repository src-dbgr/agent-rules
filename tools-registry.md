# Tools Registry — Erlaubte Werkzeuge & CLI-Befehle je Rolle

> **Version:** 1.3.1  
> **Status:** Verbindlich  
> **Prinzip:** Least Privilege — jede Rolle erhält nur Werkzeuge, die für ihr Mandat nötig sind.

Dieses Register definiert **erlaubte** Agent-Werkzeuge (IDE/MCP/Shell) und **verifizierende CLI-Befehle** für DoD-Nachweise. Nicht gelistete destructive Operationen (z. B. `rm -rf /`, `git push --force`, Produktions-Deploys ohne Freigabe) sind **verboten**, sofern nicht explizit vom Nutzer autorisiert.

---

## 1. Globale Regeln

| Regel | Beschreibung |
|-------|--------------|
| **G1** | Orchestrator: **kein** Code-Edit, **kein** Commit; nur State, Handover, Sub-Agent-Spawn |
| **G2** | Jeder DoD-Nachweis: Befehl + Exit-Code in `.agent-state.json` → `dod_gates` |
| **G3** | Secrets niemals in Logs, Handovers oder Commits |
| **G4** | Netzwerk-Zugriff nur für Research, Package-Install, CI — nicht für Datenexfiltration |
| **G5** | Bei UI-Änderungen: visuelle Regression **Pflicht** (siehe Tester) |
| **G6** | Memory-Writes (Gesetz 9): kein Secret/PII ins Gedächtnis; Provenienz + Scope + TTL setzen; Ingestion-/Write-Screening (ASI06) durchführen — Memory Curator verantwortlich |

---

## 2. Werkzeug-Matrix je Rolle

Legende: ✅ erlaubt | ⚠️ eingeschränkt | ❌ verboten

| Werkzeug / Aktion | Orch. | Researcher | BA | Architect | Developer | Tester | UX/UI | Security | Data Eng. | DevOps |
|-------------------|-------|------------|-----|-----------|-----------|--------|-------|----------|-----------|--------|
| Read files | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Write code | ❌ | ❌ | ❌ | ⚠️ specs only | ✅ | ⚠️ tests only | ⚠️ styles | ❌ | ⚠️ migrations | ⚠️ ci config |
| Shell (read-only) | ✅ | ✅ | ❌ | ⚠️ | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| Web search | ⚠️ | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | ✅ | ✅ | ⚠️ | ⚠️ |
| Spawn sub-agent | ✅ | ⚠️ d≤3 | ⚠️ d≤3 | ⚠️ d≤3 | ⚠️ d≤3 | ⚠️ d≤3 | ⚠️ d≤3 | ⚠️ d≤3 | ⚠️ d≤3 | ⚠️ d≤3 |
| Edit `.agent-state.json` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| git commit | ❌ | ❌ | ❌ | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ⚠️ |
| git push | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ mit Freigabe |

---

## 3. Verifizierungs-CLI (DoD-Nachweise)

### 3.1 Allgemein / Sprachagnostisch

| Zweck | Befehl (Beispiel) | Erfolg | Rolle |
|-------|-------------------|--------|-------|
| JSON Schema validieren | `npx -p ajv-cli@5 -p ajv-formats ajv validate -s schemas/agent-state.schema.json -d .agent-state.json --spec=draft2020 -c ajv-formats` | Exit 0 | Orchestrator |
| Secret Scan | `gitleaks detect --source . --no-git` | Exit 0 | Security |
| License Check | `npx license-checker --summary` | Exit 0 | Compliance |

### 3.2 Python

| Zweck | Befehl | Erfolg | Rolle |
|-------|--------|--------|-------|
| Unit/Integration | `pytest -q --tb=short` | Exit 0 | Developer, Tester |
| Coverage Gate | `pytest --cov=src --cov-fail-under=80` | Exit 0 | Tester |
| Lint | `ruff check .` | Exit 0 | Developer |
| Format | `ruff format --check .` | Exit 0 | Developer |
| Typecheck | `mypy src` | Exit 0 | Developer |
| SAST | `bandit -r src -ll` | Exit 0 | Security |
| SCA | `pip-audit` oder `safety check` | Exit 0 | Security |

### 3.3 JavaScript / TypeScript

| Zweck | Befehl | Erfolg | Rolle |
|-------|--------|--------|-------|
| Unit | `npm test` / `pnpm test` | Exit 0 | Developer, Tester |
| E2E | `npx playwright test` | Exit 0 | Tester |
| **Visuelle Regression** | `npx playwright test --grep @visual` oder `npx percy exec -- npm test` | Exit 0 | Tester, UX/UI |
| Lint | `npm run lint` / `eslint .` | Exit 0 | Developer |
| Typecheck | `npx tsc --noEmit` | Exit 0 | Developer |
| SCA | `npm audit --audit-level=high` | Exit 0 | Security |

### 3.4 Go

| Zweck | Befehl | Erfolg | Rolle |
|-------|--------|--------|-------|
| Test | `go test ./...` | Exit 0 | Developer, Tester |
| Lint | `golangci-lint run` | Exit 0 | Developer |
| Race Detector | `go test -race ./...` | Exit 0 | Tester (Deep+Concurrent) |

### 3.5 Rust

| Zweck | Befehl | Erfolg | Rolle |
|-------|--------|--------|-------|
| Test | `cargo test` | Exit 0 | Developer, Tester |
| Clippy | `cargo clippy -- -D warnings` | Exit 0 | Developer |
| Audit | `cargo audit` | Exit 0 | Security |

### 3.6 Formale Verifikation (nur Deep-Track + kritische Nebenläufigkeit)

| Zweck | Befehl | Erfolg | Rolle |
|-------|--------|--------|-------|
| **Alle Bibel-Beweise** | `./scripts/verify-proofs.sh` | Exit 0 | Architect, Orchestrator |
| TLA+ Model Check | `java -XX:+UseParallelGC -cp lib/tla2tools.jar tlc2.TLC -config specs/workflow.cfg specs/workflow.tla` | Exit 0, keine Violation | Architect |
| TLC direkt (Alias) | identisch zu oben | Exit 0 | Architect |
| Apalache (optional) | `apalache-mc check --init=Init --next=Next specs/workflow.tla` | Exit 0 | Architect |

**Setup (einmalig):**

1. **Java 17+** (z. B. Eclipse Temurin). macOS: `/usr/bin/java` ist oft nur ein Stub — `JAVA_HOME` setzen oder `export JAVA_HOME=$(/usr/libexec/java_home)`.
2. **tla2tools.jar** — wird von `scripts/verify-proofs.sh` bei Bedarf nach `lib/tla2tools.jar` geladen (nicht versioniert; siehe `.gitignore`).
3. **Kanonische TLC-Konfiguration:** `specs/workflow.cfg` (nicht `MC.cfg` — entfernt; war veraltetes, inkompatibles Modell).
4. **gitleaks** — `brew install gitleaks` oder Binary auf `PATH`; optional `lib/gitleaks`.
5. **ajv** — via `npx -p ajv-cli@5 -p ajv-formats` (Draft 2020-12 + `uuid`-Format).

**Anti-Halluzination:** Ein in Chat generiertes „TLA+ sieht gut aus" ist **kein** Nachweis. Nur CLI-Exit 0 + gespeichertes TLC-Log unter `proof-artifacts/`.

### 3.6a Verifizierter Lauf (Referenz)

```bash
./scripts/verify-proofs.sh
```

| Werkzeug | Ergebnis (lokal) |
|----------|------------------|
| **ajv** | `.agent-state.json valid` |
| **gitleaks** | `no leaks found` |
| **TLC** | `Model checking completed. No error has been found.` (60 distinct states, Tiefe 13) |

### 3.7 Container & CI

| Zweck | Befehl | Erfolg | Rolle |
|-------|--------|--------|-------|
| Build | `docker build -t app:test .` | Exit 0 | DevOps |
| Compose Test | `docker compose -f docker-compose.test.yml up --abort-on-container-exit` | Exit 0 | DevOps |
| CI lokal | `act -j test` (falls act installiert) | Exit 0 | DevOps |

### 3.8 Agent-Verhaltens-Tests (SOTA, optional empfohlen)

| Framework | Zweck | Befehl |
|-----------|-------|--------|
| agentverify | Deterministische Tool-Sequenz-Assertions | `pytest tests/agent/ --agentverify` |
| Invarium | Verhaltens-Baseline & Regression | `invarium test` |
| AgentProbe | Tool-Auswahl, PII-Leaks, Chaos | `agentprobe run scenarios/` |

### 3.9 Gedächtnis-Werkzeuge (Gesetz 9, Memory Curator)

Werkzeuge zur Umsetzung von `memory-policy.md`. Auswahl ist **projektabhängig** —
keine „auf Vorrat"-Einführung. Nur der **Memory Curator** (bzw. Orchestrator in
dieser Funktion) darf persistentes Gedächtnis schreiben.

| Zweck | Werkzeug / Befehl (Beispiel) | Memory-Layer | Rolle |
|-------|------------------------------|--------------|-------|
| Kurzzeit-/Langzeit-State (nativ) | LangGraph `checkpointer` (thread) + `store`/`PostgresStore` (namespace) | working + semantic/episodic | Memory Curator, Developer |
| Portabler Memory-Service | Mem0 (REST/SDK), sub-Sekunden-Recall | semantic/episodic | Memory Curator |
| Temporaler Wissensgraph | Zep / Graphiti (bi-temporale Validity-Windows) | semantic/episodic | Memory Curator |
| Self-Managing tiered Memory | Letta (MemGPT) | alle | Memory Curator |
| IDE-native Persistenz | Cursor Memories, `.cursor/rules/*.mdc`, `AGENTS.md` (nested) | semantic/procedural | Memory Curator, Orchestrator |
| Geteiltes Gedächtnis | MCP Memory-Server (z. B. Mnemosyne) | semantic/episodic | Memory Curator |
| **Poisoning-Abwehr (ASI06)** | OWASP Agent Memory Guard (YAML-Policy `allow/redact/quarantine/block`, SHA-256-Baselines, Snapshots) | Ingestion/Write-Gate | Memory Curator, Security |
| Secret/PII-Scan vor Write | `gitleaks detect --source runtime/handovers --no-git` | alle | Memory Curator, Security |
| Memory-State schema-valide | `npx -p ajv-cli@5 -p ajv-formats ajv validate -s schemas/agent-state.schema.json -d .agent-state.json --spec=draft2020 -c ajv-formats` | — | Orchestrator |

**Anti-Halluzination (analog TLA+):** „Memory sieht sauber aus" ist **kein**
Nachweis. Nur Scan-Exit-0 (gitleaks/Injection-Policy) + dokumentierte
`policy_action` unter `proof-artifacts/` erfüllt das Gate (Gesetz 6).

**Least Privilege für Memory:** Fachrollen (Developer, Tester, …) lesen aktives
Gedächtnis (Handover §7a), schreiben aber **nicht** direkt in persistente Stores —
Writes laufen über den Memory Curator an N7. Prozedurale Writes (Gesetze/Skills):
nur mit Versions-Bump + Autorisierung (§8 unten, `AGENTS.md` §8). Skill-spezifische
Governance (Definition, Ort, Skill-vs-Rule-vs-MCP, `allowed-tools`): `skills-policy.md`.

---

## 4. IDE / MCP-Werkzeuge (Cursor & äquivalent)

| Werkzeug | Orchestrator | Fachrollen | Anmerkung |
|----------|--------------|------------|-----------|
| `Read` / Datei lesen | ✅ | ✅ | — |
| `Write` / `StrReplace` | ❌ | ✅ (rollenspez.) | Orch. nur State-Dateien via dediziertem Pfad |
| `Shell` | ✅ (nicht-destruktiv) | ✅ | Kein `--force`, kein `sudo` ohne Freigabe |
| `Grep` / `SemanticSearch` | ✅ | ✅ | — |
| `Task` (Sub-Agent) | ✅ | ⚠️ depth≤3 | Spawn zählt zur Baumtiefe |
| Browser MCP | ❌ | ⚠️ Tester, UX/UI | Für E2E/visuelle Prüfung |
| `git_write` Permission | ❌ | ⚠️ | Nur Developer/DevOps; nie Orchestrator |
| Memory-Store Write | ⚠️ (als Memory Curator) | ⚠️ nur Memory Curator | Persistenter Write nur an N7; Ingestion-/Write-Screening Pflicht (Gesetz 9) |
| Memory-Store Read (Ingestion) | ✅ | ✅ | Aktives Gedächtnis lesen, Provenienz/TTL beachten |

---

## 5. Verbotene Befehle (Auszug)

```
git push --force
git reset --hard (ohne Nutzer-Freigabe)
rm -rf /
DROP DATABASE
kubectl delete namespace
curl | sh  (unverifizierte Remote-Skripte)
```

Bei Unsicherheit: **Hard Error** an Orchestrator, nicht ausführen.

---

## 6. Nachweis-Ablage

Alle DoD-Befehle müssen Ergebnis hinterlassen:

```
proof-artifacts/
├── N4_pytest_20260706.log
├── N5_playwright_visual.log
├── N3c_tlc_output.txt
├── N6_bandit.json
├── N1_memory_ingest_gitleaks.log
└── N7_memory_consolidate_policy.json
```

Orchestrator trägt `proof_artifact_path` in `dod_gates` ein.

---

## 7. Modell-Auswahl (Richtlinie)

| Rolle | Modell-Typ | Temperatur |
|-------|------------|------------|
| Orchestrator | Planung/Reasoning | 0 |
| Developer | Code | 0–0.2 |
| Researcher | Recherche | 0 |
| Tester | Analyse | 0 |
| UX/UI | Kreativ (Copy/Mock) | 0.3–0.5 |

Planungs- und Routing-Entscheidungen (Triage, CFG-Kanten) **niemals** mit hoher Temperatur.

---

## 8. Aktualisierung

Neue Werkzeuge dürfen nur mit Versions-Bump in diesem Dokument und Abgleich mit `AGENTS.md` hinzugefügt werden. Sub-Agenten dürfen das Register nicht erweitern.
