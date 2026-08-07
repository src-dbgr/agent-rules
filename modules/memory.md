# Gedaechtnis — Schichten, Scope, TTL, Provenienz

> Normative Datei zu `LAW-MEMORY` und seinen sechs Unterregeln `LAW-MEMORY.1` bis `LAW-MEMORY.6`.
> Zahlenwerte stehen ausschliesslich in `config/policy-defaults.json`, Feldnamen in
> `schemas/agent-state.schema.json` (Objekt `memory`), Artefakt-Orte und Retention in
> `modules/lifecycle.md`. Dieses Modul regelt **Wissen**, nicht Dateien.

## 1. Kontext ist nicht Gedaechtnis

| | Kontext | Gedaechtnis |
|-|---------|-------------|
| Was | Arbeitsspeicher einer Agenten-Instanz | persistenter Speicher ueber Instanzen, Sessions, Aufgaben hinweg |
| Kosten | teuer je Token, fluechtig | billig, aber wachsende Angriffsflaeche |
| Geregelt in | `modules/context.md#budget` | dieses Modul |
| Umgang | kuratieren, bei Amtsuebergabe verwerfen | gezielt schreiben, gezielt abrufen |

Zwei entgegengesetzte Fehlerklassen sind zu vermeiden: **Amnesie** (nichts wird gelernt) und
**Vergiftung** (unbegrenzt akkumulierter Zustand wird unbegrenzt geglaubt). Beide Regeln unten
adressieren je eine davon; keine darf gegen die andere ausgespielt werden.

**Verboten:** Kontext als Gedaechtnis benutzen — vollstaendige Historie oder ungefilterte
Werkzeugausgaben „fuer alle Faelle" im Fenster halten. Ebenso verboten: durable Erkenntnisse
**nur** im Fenster halten, statt sie an N7 zu schreiben.

## 2. Schichten

Vier Schichten (CoALA-Taxonomie), getrennt nach Lebensdauer, Scope und **Schreib-Risiko**:

| Schicht (`memory.layer`) | Inhalt | Scope-Default | Verankert in |
|--------------------------|--------|---------------|--------------|
| `working` | aktuelles Ziel, Zwischenschritte, aktiver Kontext | `thread` | `modules/context.md#budget` |
| `episodic` | Verlaeufe: Entscheidungen, Sackgassen, Zyklusergebnisse, Uebergabe-Historie | `project` | Zustand (`cycles`, `handovers`), `memory.episodic` |
| `semantic` | dauerhafte Fakten: Konventionen, Architekturfakten, Schnittstellenvertraege | `project` | `AGENTS.md`, Projektregeln, `memory.semantic` |
| `procedural` | *wie* gehandelt wird: Gesetze, Ablauf, Werkzeugrechte, Skills | `global` | dieses Gesetzbuch, `modules/skills.md` |

**Risiko-Ordnung (verbindlich):** `episodic` < `semantic` < `procedural`. Ein Schreibzugriff auf
prozedurales Gedaechtnis aendert das Verhalten aller kuenftigen Agenten und ist die riskanteste
Operation dieses Systems. Er ist **nur** mit Versions-Bump und ausdruecklicher Autorisierung
zulaessig, niemals als Nebeneffekt einer Aufgabe. Skills sind prozedurales Gedaechtnis; ihre
Governance steht in `modules/skills.md`.

## 3. Scope (`LAW-MEMORY.1`, `LAW-MEMORY.2`)

**`LAW-MEMORY.1` — Scoping-Pflicht.** Jeder Eintrag traegt `scope`. Ein Eintrag ohne Scope ist
**ungueltig** und wird nicht abgerufen.

| Scope | Sichtbarkeit | Zulaessig fuer |
|-------|--------------|----------------|
| `thread` | eine Agenten-Instanz | Arbeitsgedaechtnis |
| `project` | alle Agenten dieses Repos | Default fuer `episodic` und `semantic` |
| `user` | ein Nutzer ueber Projekte hinweg | ausschliesslich genuin projektuebergreifende Praeferenzen |
| `global` | alle | prozedurales Gedaechtnis, also die Gesetze selbst |

**`LAW-MEMORY.2` — Kein Cross-Project-Leakage.** `project`-Wissen wird **niemals** ohne
begruendete, dokumentierte Freigabe nach `user` oder `global` promoviert. Build-Kommandos,
Framework-Grenzen oder Pfade dieses Repos in einen nutzerweiten Speicher zu schreiben,
verunreinigt fremde Projekte und ist die haeufigste Leakage-Ursache. Verboten.

## 4. TTL und Staleness (`LAW-MEMORY.3`)

**`LAW-MEMORY.3` — Kein blindes Vertrauen in Altwissen.** Jeder `episodic`- und
`semantic`-Eintrag traegt ein Gueltigkeitsfenster. Abgelaufenes wird **revalidiert oder
expiriert**, nie als wahr angenommen.

Felder je Eintrag (`memory.active[]`, Schema ist verbindlich):

- `created_at` — wann geschrieben.
- `valid_until` — Ablauf; danach ist Revalidierung gegen die Quelle Pflicht, bevor der Eintrag
  eine Entscheidung tragen darf.
- `superseded_by` — Verweis auf den ablösenden Eintrag. Damit bleibt unterscheidbar, was
  **damals** galt und was **jetzt** gilt; der alte Eintrag wird nicht stillschweigend umgeschrieben.
- `last_validated_at` — letzte Bestaetigung gegen Code, Test oder Quelle.

**Praxisregel:** kurze Frist fuer Fakten mit hoher Aenderungsrate (Versionen, aktive Vertraege),
lange oder keine Frist fuer stabile Konventionen — diese dafuer mit `last_validated_at`.
Ein abgelaufener Eintrag darf im Zustand nicht als aktiv stehen; das Aufraeumen ist Teil der
Consolidation (Abschnitt 8).

## 5. Provenienz und Poisoning-Abwehr (`LAW-MEMORY.4`)

**Bedrohung.** Gedaechtnis-Vergiftung (OWASP ASI06, Agentic Applications) unterscheidet sich von
Prompt Injection darin, dass sie **persistiert**: sie ueberlebt Session, Neustart und Aufgabe und
wirkt oft erst spaeter. Drei dokumentierte Vektoren:

1. **Ungepruefte Ingestion** — praeparierte Eintraege gelangen in den Speicher.
2. **Geteilter Kontext** — eine Injektion breitet sich ueber Teilbaeume und Nutzer aus.
3. **Zusammenfassungs-Kontamination** — manipulierter Inhalt wird in eine Zusammenfassung
   destilliert und traegt sich so in kuenftige Entscheidungen.

**`LAW-MEMORY.4` — Provenienz-Pflicht.** Jeder Eintrag traegt `source` und
`trust` aus `{trusted, unverified, untrusted}`. `untrusted` und `unverified` duerfen **nicht**
ohne Verifikation nach `semantic` oder `procedural` promoviert werden; sie werden in Quarantaene
gehalten (`policy_action: quarantine`).

Verbindliche Kontrollen bei Ingestion und vor jedem Write (`memory.poisoning_checks`):

| Kontrolle | Regel | Feld |
|-----------|-------|------|
| Quellen-Pruefung | Herkunft jedes Eintrags klassifiziert | `source_validated` |
| Session-Isolation | `thread`-Wissen nicht ungefiltert nach `project` oder `user` mischen | `session_isolated` |
| Integritaets-Baseline | unveraenderliche Schluessel und Gesetzestexte gegen Pruefsumme | `integrity_baseline` |
| Injection-Erkennung | Injektions-Marker sowie Secret- und PII-Funde vor dem Write | `injection_scan` |
| Durchsetzung | Fund fuehrt zu `allow`, `redact`, `quarantine` oder `block` | `policy_action` |
| Forensik und Rueckweg | Schnappschuss auf einen bekannten guten Stand | `snapshot_ref` |

**Konsequenz aus dem belegten Vorfall (MemoryTrap):** Gedaechtnisinhalt gehoert **nicht**
ungeprueft in die hoechste Vertrauensschicht. Gedaechtnis wird behandelt wie Zugangsdaten und
Ausfuehrungspfade — als Angriffsflaeche, nicht als Wahrheit.

## 6. Secrets und PII (`LAW-MEMORY.5`)

**`LAW-MEMORY.5`.** Geheimnisse, Tokens, Zugangsdaten und personenbezogene Daten werden in
**keine** Schicht geschrieben — auch nicht „nur kurz", auch nicht redigiert-vermutet.
Statt Rohdaten: Referenz oder Pfad. Ein Fund ist ein Sicherheitsvorfall und wird nach
`modules/lifecycle.md` behandelt (Blocker, Stop-the-line, Rotation des Geheimnisses).

## 7. Was speichern, was verwerfen (`LAW-MEMORY.6`)

**`LAW-MEMORY.6` — Selektive Persistenz.** Gedaechtnis ist **kuratiert**, nicht vollstaendig.
„Alles speichern" ist verboten: es erzeugt Kosten, Rauschen und Vergiftungsflaeche zugleich.

| Speichern (`episodic` / `semantic`) | Verwerfen (nie persistieren) |
|-------------------------------------|------------------------------|
| Entscheidungen samt Begruendung (Kern eines ADR) | fluechtige Gedankenketten und Zwischenstaende |
| verifizierte Fakten, Konventionen, Schnittstellenvertraege | rohe oder grosse Werkzeugausgaben (nur Pfad) |
| **Sackgassen und verworfene Ansaetze samt Grund** | Geheimnisse und personenbezogene Daten |
| wiederkehrende Fehlerursachen und ihre Behebung | unverifizierte Behauptungen ohne Provenienz |
| Abnahmekriterien und Nachweise (als Pfad) | Duplikate bereits gespeicherten Wissens |

Die linke Spalte ist der Grund, warum Gedaechtnis ueberhaupt existiert: Sackgassen zu
vergessen heisst, sie zu wiederholen.

## 8. Ingestion und Consolidation {#ingestion}

Gedaechtnis ist an genau **zwei** Knoten verankert; dazwischen wird nicht nachgeladen.
Zustaendig ist die Rolle `memory_curator` (`roles/memory_curator.md`).

**N1 — Ingestion (Bootstrap-Gate):**

1. Prozedurales und semantisches Wissen laden: den Kern und die Pfade der berechneten Leseliste.
2. Episodisches Wissen laden: den eigenen Zustand und, falls die Aufgabe fortgesetzt wird, den
   Uebergabe-Index — **nicht** die Alt-Uebergaben selbst.
3. Kontrollen aus Abschnitt 5 anwenden, Frist aus Abschnitt 4 pruefen, `untrusted` in Quarantaene.
4. Ergebnis nach `memory.active[]` schreiben, mit `layer`, `scope`, `trust`, `source`, `valid_until`.

## 9. Consolidation {#consolidation}

**N7 — Consolidation (Aggregations-Gate), in dieser Reihenfolge:**

1. Kandidaten aus `memory.pending_writes[]` pruefen: Secret- und PII-Scan, Injection-Scan,
   Scope-Korrektheit, Dedup.
2. Durable Learnings schreiben — `episodic` fuer Sackgassen und Fehlerbehebungen, `semantic` fuer
   neu verifizierte Fakten — jeweils mit Provenienz und Frist.
3. Abgelaufenes expirieren oder per `superseded_by` ablösen.
4. Prozedurale Writes nur mit Versions-Bump und Autorisierung, sonst gar nicht.
5. Schnappschuss ablegen und in `snapshot_ref` verweisen (`modules/lifecycle.md#abbruch-und-rollback`).

**Kein Self-Re-Ingest.** Es gibt **kein automatisches Wieder-Einlesen eigener Alt-Ausgaben**.
Archivierte Uebergaben, abgelaufene Berichte und verworfene Zwischenstaende sind Historie, nicht
Kontext. Mechanisch abgesichert: kein Manifest-Pfad und keine Leseliste zeigt in das Archiv.
Wiederaufnahme laeuft ueber Zustand und Index (`modules/lifecycle.md`), nicht ueber Alt-Prosa.

## 10. Nachweise

Jedes Gate dieses Moduls ist ein Kommando, keine Behauptung. Fehlt ein Werkzeug, lautet das
Ergebnis „NICHT NACHGEWIESEN" (Exit `2`) und gilt **nie** als Bestehen (`modules/tools.md#verifizierung`).

| Gate | Nachweis | Erfolg |
|------|----------|--------|
| Zustand schema-valide | `ajv validate -s schemas/agent-state.schema.json -d runtime/state/<orchestrator_id>.json` | Exit `0` |
| kein abgelaufener Eintrag aktiv | `jq '[.memory.active[] \| select(.valid_until != null and (.valid_until \| fromdateiso8601) < now)] \| length'` | Ergebnis `0` |
| kein Secret im Write | `gitleaks detect --no-git --source runtime --redact` | Exit `0` |
| kein Archivpfad in einer Leseliste | `! jq -r '.. \| strings' manifest.json \| grep -q 'runtime/archive'` | Exit `0` |
| Uebergaben valide | `./scripts/validate-handovers.sh runtime/handovers` | Exit `0` |

Ergebnisse liegen unter `proof-artifacts/` und werden im Zustand unter `dod_gates` mit dem
erzielten Exit-Code eingetragen; Schluessel sind Knoten-IDs oder `dod:<name>`.
