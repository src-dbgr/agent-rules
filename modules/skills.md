# Skills — Governance prozeduraler Faehigkeiten

> Normative Datei zur Skill-Governance. Ein Skill ist **prozedurales Gedaechtnis**; die
> Schichten, Scopes und Vertrauensregeln stehen in `modules/memory.md` und werden hier nicht
> wiederholt, sondern angewandt. Das kopierbare Muster ist `templates/skill-template/SKILL.md`.

## 1. Definition

Ein Skill ist ein Ordner mit einer Beschreibungsdatei `SKILL` (YAML-Frontmatter plus Markdown) und
optionalen Skripten und Ressourcen. Er bringt einem Agenten **eine konkrete, wiederholbare,
mehrschrittige Prozedur** bei. Das Format ist ein offener, plattformuebergreifender Standard:
ein spec-konformer Skill laeuft ohne Aenderung in verschiedenen Agenten-Werkzeugen.

**Progressive Disclosure** ist das tragende Prinzip und der Grund, warum Skills das
Kontext-Budget nicht sprengen:

1. **Entdeckung** — nur `name` und `description` sind beim Start im Kontext.
2. **Aktivierung** — der Body wird erst geladen, wenn eine Aufgabe zur `description` passt.
3. **Ressourcen** — gebuendelte Dateien werden nur bei Bedarf nachgeladen.

Frontmatter-Felder: `name` (Pflicht, gleich dem Ordnernamen, Kleinbuchstaben und Bindestriche),
`description` (Pflicht, *was* und *wann*), optional `paths` (Glob-Scoping),
`disable-model-invocation` (nur explizit aufrufbar), `allowed-tools` (Least Privilege),
`metadata`.

## 2. Ort und Scope

Skills leben im **Zielprojekt** oder im Nutzerprofil, **nicht** im Vendor-Clone dieses
Gesetzbuchs.

| Ort | Scope | Wirkung |
|-----|-------|---------|
| `.cursor/skills/<name>/SKILL.md`, `.agents/skills/<name>/SKILL.md` | `project` | mit dem Repo geteilt |
| dieselben Pfade in einem Teilbaum (Monorepo) | `project`, pfad-gescopt | nur bei Dateien dieses Teilbaums |
| die entsprechenden Pfade im Nutzerprofil | `user` | ueber Projekte hinweg — Leakage-Gefahr |
| Varianten anderer Agenten-Werkzeuge | `project` oder `user` | Kompatibilitaet ueber Werkzeuge hinweg |

**`LAW-MEMORY.2` gilt fuer Skills.** Projektspezifische Prozeduren (Deploy-Schritte,
Framework-Grenzen eines Repos) gehoeren in `project`-Scope und **niemals** ungeprueft in den
nutzerweiten Ort. Der `user`-Scope ist ausschliesslich fuer genuin projektuebergreifende
Prozeduren. Kategorien als Unterordner sind erlaubt; der `name` kommt vom Elternordner der
Beschreibungsdatei, nicht von der Kategorie.

## 3. Entscheidung: Skill, Regel, Kern oder Werkzeug

**Heuristik:** Immer-an-Kontext gehoert in eine Regel oder in den Kern. Auf-Abruf-Prozedur wird
ein Skill. Werkzeug-Anbindung ist ein Protokoll-Thema, kein Skill. Einmaliges wird nicht
persistiert.

| Konstrukt | Aktivierung | Typischer Inhalt |
|-----------|-------------|------------------|
| Kern (`AGENTS.md`) und Module | immer bzw. per berechneter Leseliste | Gesetze, Ablauf, Rollen, Werkzeugrechte |
| projektweite Regeldatei | immer oder per Glob | harte Randbedingungen, Stil, pfadgebundene Verbote |
| **Skill** | auf Abruf, per `description` oder expliziten Aufruf | wiederholbare, mehrschrittige Prozedur mit eigenem DoD |
| Werkzeug-Server (Protokoll) | Werkzeugaufruf zur Laufzeit | Anbindung externer Faehigkeiten und Daten |

**Ein Skill ist richtig, wenn alle vier Punkte zutreffen:** die Anweisung ist eine Prozedur mit
Reihenfolge und Abnahmekriterium; sie wird nur bei bestimmten Aufgaben gebraucht; sie ist
wiederverwendbar und zu lang fuer den Dauerkontext; Portabilitaet ueber Werkzeuge hinweg ist
erwuenscht.

**Kein Skill, wenn** es eine Immer-an-Konvention ist (dann Regel oder Kern), es einmalig ist
(dann gar nicht persistieren, `LAW-MEMORY.6`), es reine Werkzeug-Anbindung ist, oder es die
Gesetze dieses Gesetzbuchs dupliziert. Bootstrap, Delegation, Triage und die DoD-Gates sind
immer-an und in Kern und Modulen normiert; als Skill verpackt waeren sie falsch klassifiziert
**und** doppelt normiert — die gefaehrlichste Form prozeduraler Redundanz.

Deshalb liefert dieses Gesetzbuch selbst **keine** Skills aus, sondern nur dieses Gesetz und ein
Muster zum Kopieren: wertvolle Skills sind projektspezifisch, und sie projektweit auszurollen
waere genau das Leakage, das `LAW-MEMORY.2` verbietet.

## 4. Schreib-Risiko

Ein Skill zu erstellen oder zu aendern ist ein **prozeduraler Write** und damit die riskanteste
Gedaechtnis-Operation dieses Systems (Risiko-Ordnung in `modules/memory.md`). Ein fehlerhafter
oder praeparierter Skill ist vergiftetes prozedurales Gedaechtnis: er kann Fehler einfuehren
oder einem Agenten erlauben, die Absicht seiner Auftraggeber zu unterlaufen.

1. **Niemals eigenmaechtig.** Ein Sub-Agent schreibt keinen Skill. Zulaessig nur mit
   Versions-Bump und ausdruecklicher Autorisierung; ein stiller prozeduraler Write ist ein
   Regelverstoss.
2. **Herkunft pruefen** (`LAW-MEMORY.4`). Ein Skill aus fremder Quelle ist `untrusted` oder
   `unverified`: erst Quarantaene und Review, dann Aktivierung — nie blinde Ausfuehrung.
3. **Least Privilege.** `allowed-tools` so eng wie moeglich. Ein Skill erweitert die
   Werkzeugrechte einer Rolle **nicht** ueber `modules/tools.md` hinaus.
4. **Keine Geheimnisse und keine personenbezogenen Daten** (`LAW-MEMORY.5`) — weder in der
   Beschreibungsdatei noch in gebuendelten Ressourcen.

## 5. Gates und Nachweise

Skills haengen an denselben zwei Gedaechtnis-Knoten wie alles uebrige Wissen
(`modules/memory.md#consolidation`):

- **N1** — Entdeckung ueber `name` und `description`; Herkunft und Vertrauen pruefen; nicht
  vertrauenswuerdige Skills nicht automatisch aktivieren.
- **N7** — ergab die Aufgabe eine durable, wiederverwendbare Prozedur, ist sie **Kandidat** in
  `memory.pending_writes[]` mit `layer: procedural`. Persistiert wird nur nach Punkt 1 bis 4.

| Gate | Nachweis | Erfolg |
|------|----------|--------|
| Frontmatter vollstaendig | `name` gleich Ordnername, `description` nennt *was* und *wann* | erfuellt |
| Umfang | Body innerhalb `caps.module_max_lines` (Default siehe config), Rest in Ressourcen | erfuellt |
| kein Geheimnis | `gitleaks detect --no-git --source <skill-verzeichnis>` | Exit `0` |
| Skripte lauffaehig | das jeweils dokumentierte Test- oder Lint-Kommando | Exit `0` |
| Screening bei fremder Herkunft | Review plus `memory.poisoning_checks.injection_scan` | bestanden oder Quarantaene dokumentiert |

Fehlt ein Werkzeug, lautet das Ergebnis „NICHT NACHGEWIESEN" (Exit `2`) und gilt nicht als
Bestehen (`modules/tools.md#verifizierung`). Nachweise liegen unter `proof-artifacts/`.
