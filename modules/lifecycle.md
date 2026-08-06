# Lebenszyklus — Artefakte, Retention, Handover-Format

> Normative Datei zu `LAW-LIFECYCLE`, `LAW-STATE` und zum Handover-Format.
> Alle Zahlenwerte stehen ausschliesslich in `config/policy-defaults.json` (Abschnitte `caps`, `gc`);
> dieser Text nennt sie als „Default (siehe config)" und niemals als Ziffer.
> Struktur, Pfade und Ladebedingungen stehen in `manifest.json` (Abschnitte `runtime_layout`, `documents`).

## 1. Runtime-Layout {#runtime-layout}

Regel: Jedes erzeugte Artefakt hat **genau einen** Ort, eine Namenskonvention und ein Lebensende.
Alles unter `runtime/` ist **ephemer und vollstaendig gitignoriert**; wer etwas behalten will, promoviert es
(Abschnitt 5). Was nicht promoviert wurde, gilt als verworfen.

| Ort | Inhalt | Namenskonvention | Lebensende |
|-----|--------|------------------|-----------|
| `runtime/state/` | genau ein Zustand je Orchestrator, plus Lock-Datei | `runtime/state/<orchestrator_id>.json`, Lock `runtime/state/<orchestrator_id>.json.lock` | Terminalzustand |
| `runtime/handovers/` | aktive Uebergaben | `runtime/handovers/<handover_id>.md` | Knoten-Abschluss |
| `runtime/handovers/` | Index der Uebergaben | runtime/handovers/index.jsonl (append-only) | Retention-Klasse `handover_index` |
| `runtime/reports/` | Berichte der Rollen (Recherche, Anforderungen, Architektur, Audit) | `runtime/reports/<id>-<art>.md` | Retention-Klasse `report` |
| `runtime/archive/` | komprimierte Uebergaben und Zustands-Schnappschuesse | `runtime/archive/<task>/state-<zeit>.json.gz` | Retention-Klassen `archived_handover`, `state_snapshot` |
| `runtime/tmp/` | Scratch, Werkzeugausgaben, Zwischenstaende | frei, aber unter `runtime/tmp/` | Retention-Klasse `scratch`, zusaetzlich bei Knoten-Abschluss |
| `runtime/` | Audit-Spur der Zustandsuebergaenge | runtime/audit.jsonl (append-only) | Retention-Klasse `audit_log` |
| `proof-artifacts/` | Nachweise je Gate | `proof-artifacts/<gate>_<zeit>.log` | Retention-Klasse `proof_artifact`, keep-latest je Gate |

Verbindliche Zusatzregeln:

1. **Ein Zustand je Orchestrator** (`LAW-STATE`): der Pfad enthaelt die `orchestrator_id`; parallele Agenten
   im selben Arbeitsbaum kollidieren dadurch nicht. Vor dem ersten Schreiben wird der Lock erworben
   (`./scripts/state-lock.sh --acquire --holder <orchestrator_id>`). Ein **fremder** Lock ist ein Hard Error:
   nicht ueberschreiben, sondern Blocker-Eintrag und Terminalzustand `t_blocked`.
2. **Ein Handover-Pfad.** Flache Ablagen direkt unter der Laufzeitwurzel sind ungueltig, ebenso ein eigenes
   Log-Verzeichnis (Werkzeugausgaben gehoeren nach `runtime/tmp/`) und ein Zustand im Repo-Wurzelverzeichnis.
   Die abschliessende Liste erlaubter Orte ist `manifest.json#/runtime_layout`, die der ausdruecklich verbotenen
   `manifest.json#/forbidden_runtime_paths`; jede Nennung eines anderen Pfades in Doku oder Skript ist ein
   Linter-Fehler (`./scripts/lint-lawbook.sh --runtime-paths-declared`).
3. **Anzahl aktiver Uebergaben** = Anzahl laufender Sub-Agenten, hoechstens `budgets.max_concurrent_handovers`
   (Default siehe config). Eine Datei ohne laufenden Sub-Agenten ist eine Leiche und wird beim Sweep entfernt.
4. **Neue Verzeichnisse sind unzulaessig**, solange sie nicht in `manifest.json#/runtime_layout` stehen.
   Erweiterung ist eine bewusste Aenderung der Struktur-Quelle, kein Nebeneffekt eines Laufs.

## 2. Index statt Verzeichnis-Scan

Regel: Zur Orientierung wird **der Index gelesen, nie das Verzeichnis durchsucht** und nie ein altes
Handover geoeffnet. Genau hier entsteht sonst die Kontext-Verschmutzung, die dieses Modul verhindert.

- **Verboten:** die Laufzeitwurzel blind zu globben, aufzulisten oder einzulesen („was liegt hier noch?"),
  ebenso das Lesen von Geschwister-Handovern oder von Archivinhalten (`LAW-ISOLATION`, Abschnitt 4).
- **Erlaubt:** der eigene Zustand, das eigene Handover, der Index, und die Pfade der berechneten Leseliste.
- **Index-Format:** eine Zeile je Uebergabe, gueltiges JSON, mit den Feldern
  `id`, `node`, `role`, `created_at`, `expires_at`, `path`, `bytes`. Optional zusaetzlich
  `reason`, `from_agent_id`, `to_agent_id`, `status`, `gc_id`. Derselbe Satz steht im Zustand unter
  `handovers[]` — der Index ist die Datei, der Zustand die maschinenlesbare Sicht darauf.
- **Append-only.** Die einzige erlaubte Nicht-Anhaenge-Operation ist das Entfernen von Zeilen, deren Datei
  der Sweep geloescht hat; sie geschieht ausschliesslich im Schreibmodus des Sweeps und wird berichtet.
- **Nachweise:** `./scripts/gc-sweep.sh --check-index` (jede Zeile valide, Pflichtfelder vorhanden) und
  `./scripts/gc-sweep.sh --check-index-consistency` (jede aktive Datei genau ein Eintrag und umgekehrt).

## 3. Retention {#retention}

Regel: Retention gilt **je Artefakt-Klasse** und wirkt ueber **zwei** Achsen gleichzeitig — **Alter** und
**Anzahl**. Die Klassen, ihre Glob-Muster und beide Caps stehen in `config/policy-defaults.json#/gc/artifacts`;
Bedeutung der Nullwerte in `#/gc/conventions` (kein Alters- bzw. kein Mengen-Cap).

1. **Retention wird beim Schreiben festgelegt, nie retroaktiv.** Wer ein Artefakt anlegt, setzt `created_at`,
   `expires_at` und `gc_id` (Retention-Klasse) im Register — im Index fuer Uebergaben, unter `artifacts` im
   Zustand fuer alles Uebrige. Eine spaetere Policy-Aenderung verlaengert oder verkuerzt bestehende
   Ablaufdaten nicht; sie wirkt auf kuenftige Artefakte.
2. **keep-latest.** Klassen mit `keep_latest_per_key` behalten je Schluessel den jeuengsten Eintrag, auch wenn
   er ueber dem Alters-Cap liegt. Schluessel ist bei Nachweisen das Gate (Dateiname vor dem ersten `_`), bei
   Schnappschuessen das Aufgabenverzeichnis. Damit bleibt der letzte gruene Nachweis je Gate erhalten.
3. **Pflicht-Sweep an zwei Knoten** (`gc.sweep.run_at_nodes`): an **N1** im Berichtsmodus, an **N7** im
   Schreibmodus. Der Sweep ist Teil des Gates; ohne ausgefuehrten Sweep ist N7 nicht abgeschlossen (`LAW-DOD`).
4. **Berichtsmodus ist Default** (`gc.sweep.default_mode`): ohne Schreib-Flag wird **nichts** geloescht.
5. **Fail-safe, nicht fail-silent** (`gc.sweep.on_policy_error`): fehlt die Konfiguration, ist sie unlesbar
   oder unvollstaendig, endet der Sweep mit Exit ungleich 0, loescht nichts und traegt einen Blocker ein.
6. **Harte Grenzen des Sweeps.** Er operiert nur unter `runtime/` und `proof-artifacts/`, fasst keine
   versionierte Datei an, folgt keinem Symlink und akzeptiert kein `..` im Pfad. Verletzt ein Glob der
   Konfiguration diese Grenze, bricht der Lauf ab, statt ihn zu „reparieren".
7. **Einmaliger Initial-Sweep beim Umstieg.** Weil Retention nicht retroaktiv wirkt, tragen Alt-Artefakte
   aus der Zeit vor v2.0 kein `expires_at`. Der Umstieg fuehrt deshalb **einmal** aus:
   `./scripts/gc-sweep.sh --report` (Bestandsaufnahme), Promotion des Behaltenswerten (Abschnitt 5),
   danach `./scripts/gc-sweep.sh --apply --initial`. Alt-Artefakte ohne Register-Eintrag werden dabei nach
   Dateialter bewertet; das ist eine bewusste Naeherung und nur fuer diesen einen Lauf zulaessig.

Nachweise: `./scripts/gc-sweep.sh --report` (Kandidatenliste ohne Wirkung), `--apply` (Wirkung),
`--check-keep-latest` (kein jeuengster Eintrag einer Klasse steht auf der Loeschliste).

## 4. Kein Wieder-Einlesen eigener Alt-Ausgaben

Regel: Ein Agent liest **keine eigenen Alt-Ausgaben** automatisch wieder ein. Abgelaufene, archivierte oder
verworfene Artefakte sind kein Kontext, sondern Historie.

- Mechanisch abgesichert: kein Pfad einer Leseliste und kein Manifest-Eintrag zeigt auf `runtime/archive/`.
  Archive sind damit nie Teil einer berechneten Leseliste.
- Wiederaufnahme einer Aufgabe erfolgt ueber den Zustand und den Index, nicht ueber Alt-Prosa.
- Abgelaufene Artefakte: entweder gegen die Quelle **revalidieren** (dann neues `expires_at` und neuer
  Register-Eintrag) oder **verwerfen**. Ein abgelaufenes Artefakt „weil es noch da ist" zu verwenden, ist ein
  Regelverstoss; die Gedaechtnis-Seite dieser Regel steht in `modules/memory.md`.
- Begruendung: selbst erzeugte, veraltete Zwischenstaende sind Distraktoren und der belegte Vektor fuer
  Selbst-Kontamination (OWASP ASI06). Deshalb ist dies eine Verbots-, keine Empfehlungsregel.

## 5. Promotion {#promotion}

Regel: Promotion ist ein **benannter, bewusster Schritt an N7** — kein Default und kein Nebeneffekt.
Wer sie unterlaesst, verliert das Artefakt beim naechsten Sweep. Das ist der Preis dafuer, dass `runtime/`
ignoriert wird.

| Quelle (ephemer) | Ziel (versioniert) | Cap |
|------------------|--------------------|-----|
| Architekturentscheidung | `docs/adr/` als `NNNN-<slug>.md` | `caps.promoted_adr_max_lines` |
| Audit-, Review- oder Recherchebericht | `docs/review/` als `<datum>-<slug>.md` | `caps.promoted_review_max_lines` |
| Anforderungen eines Release | `docs/review/` | `caps.promoted_review_max_lines` |

Pflichten je promoviertem Dokument:

1. **Kennzeichnung in der ersten Zeile nach dem Titel:** „nicht-normativ · nicht beim Bootstrap lesen".
   Promoviertes Wissen ist Gedaechtnis fuer Menschen, nicht Instruktion fuer Agenten.
2. **Ladebedingung** `on_demand_human` im Manifest — kein `docs/`-Pfad steht in einer Leseliste.
3. **Eintrag `promoted_to`** im Artefakt-Register des Zustands, damit der Sweep die Quelle loeschen darf.
4. **Keine Norm in `docs/`.** Wird beim Promovieren eine Regel entdeckt, die fehlt, gehoert sie in das
   zustaendige Modul — nicht in den Bericht.

## 6. Handover {#handover}

Regel: Ein Handover ist **eine** Datei: Markdown mit schema-validiertem YAML-Frontmatter. Kein Freitext ohne
Frontmatter, kein zweites Artefakt daneben, keine Volltexte im Body.

- **Frontmatter:** Pflichtfelder, Enums und bedingte Pflichten stehen in `schemas/handover.schema.json`;
  die Pflichtfelder eines Delegationsbriefs sind in `modules/context.md#delegationsbrief` normiert.
  Ein Delegationsbrief ohne Abnahmekriterien und ohne Startpunkt ist kein Delegationsbrief.
- **Body:** hoechstens drei Abschnitte — Auftrag, Erkenntnisse, Startpunkt. Vorlage: `templates/handover.md`.
- **Groessen-Caps:** `caps.handover_max_lines` und `caps.handover_max_bytes` fuer das **gesamte** Dokument
  (Frontmatter plus Body), `caps.subagent_return_max_lines` fuer die Rueckgabe eines Sub-Agenten.
  Beides ist Default (siehe config) und wird gemessen, nicht geschaetzt.
- **Regel `no-inline-logs`:** grosse Werkzeugausgaben, Diffs und Fehlerlogs werden als **Pfad** referenziert
  (`artifacts[]`, `dead_ends[].artifact`), nie eingebettet. Ein Handover ist eine Instruktion, kein Protokoll.
- **Ablauf:** `expires_at` wird beim Schreiben gesetzt (Retention-Klasse `active_handover`), Indexeintrag
  ebenfalls. Nach Knoten-Abschluss wird die Datei archiviert oder geloescht — nicht liegengelassen.
- **Nachweis:** `./scripts/validate-handovers.sh runtime/handovers` prueft Frontmatter, Caps und
  `no-inline-logs`. Ohne pruefbare Datei meldet das Skript „NICHT NACHGEWIESEN" (Exit `2`) — nie Erfolg.

## 7. Geheimnisse in Artefakten und Logs

Regel: Werkzeugausgaben sind eine belegte Leckstelle (CWE-532: Einbringen sensibler Daten in Logdateien).

1. **Vor jeder Archivierung** laeuft ein Geheimnis-Scan (`gc.conventions.secret_scan_before_archive`).
   Findet er etwas, wird **nicht** archiviert; das Artefakt wird bereinigt oder verworfen.
2. **Fehlt der Scanner**, ist das Ergebnis „NICHT NACHGEWIESEN" (Exit `2`) — kein Bestehen. Die Skripte
   fuehren zusaetzlich eine eingebaute Musterpruefung aus, die scheitern kann, aber nichts beweist.
3. **Nie im Klartext** in Handover, Bericht, Index oder Zustand: Tokens, Schluessel, Zugangsdaten,
   personenbezogene Daten. Stattdessen Pfad oder Referenz.
4. **Fundstelle wird behandelt wie ein Sicherheitsvorfall:** Blocker-Eintrag, Stop-the-line, Rotation des
   betroffenen Geheimnisses — Loeschen der Logzeile allein genuegt nicht.

## 8. Abbruch und Rollback {#abbruch-und-rollback}

Regel: Jeder irreversible Schritt hat vorher einen Rueckweg. „Irreversibel" ist am Flag `irrev` erkennbar
(siehe `modules/triage.md`) und umfasst Loeschungen, Abschaltungen und Migrationen.

| Situation | Pflicht |
|-----------|---------|
| vor einem irreversiblen Schritt | `./scripts/snapshot.sh create runtime/state/<orchestrator_id>.json` |
| vor jeder Amtsuebergabe | Schnappschuss, dann Uebergabe (siehe `modules/context.md#amtsuebergabe`) |
| Ruecknahme eines Zustands | `./scripts/snapshot.sh restore --latest --apply`; die ersetzte Datei wandert nach `runtime/tmp/` |
| Terminalzustand `t_abort` | Schnappschuss bleibt, `runtime/tmp/` wird geleert, Grund steht in `blockers`, der Arbeitsbranch bleibt bestehen |
| Terminalzustand `t_blocked` | Arbeitsstand, Branch und Schnappschuss bleiben; der Lauf ist wiederaufnehmbar |

Der Schnappschuss liegt unter `runtime/archive/<task>/` (Retention-Klasse `state_snapshot`, keep-latest) und
ist damit selbst der Retention unterworfen — ein Rueckweg, der unbegrenzt waechst, waere nur eine andere
Form von Muell. Die Definition der Terminalzustaende steht in `modules/workflow.md`.
