# Klärung — Rückfragen an den Auftraggeber

> Normativ für `LAW-CLARIFY`. Ziel: keine falschen Annahmen bei echter Unsicherheit.
> Gegenstück: keine Pseudo-Fragen, die aus Prompt, Repo oder Konvention schon beantwortbar sind.

## Wann Rückfragen Pflicht sind {#wann}

Nach Triage (`N2`), **bevor** teure Gates (`N3*`/`N4`) starten, prüft der Orchestrator
(oder der Business Analyst, wenn gespawnt):

Eine Rückfrage ist **pflicht**, wenn mindestens eines zutrifft:

1. **Blockierende Mehrdeutigkeit** — ohne Antwort sind zwei fachlich verschiedene
   Umsetzungen gleich plausibel und führen zu unterschiedlichem DoD.
2. **Fehlende Entscheidungsgewalt** — Auth, Zahlung, Datenlöschung, Breaking Change,
   irreversible Aktion (`irrev`), ohne dass der Prompt eine Wahl trifft.
3. **Widerspruch** — Prompt widerspricht sich selbst oder dem sichtbaren Repo-Ist-Stand
   in einem Punkt, der das Ergebnis verändert.
4. **Unklarer Erfolg** — es gibt kein beobachtbares „fertig“, das man testen könnte.

Dann: `phase: awaiting_user`, Lauf **pausiert**, keine Implementation, keine Annahmen
zu den offenen Punkten. Wiederaufnahme erst nach Antwort des Auftraggebers.

## Was keine Rückfrage ist {#anti-pseudo}

**Verboten** als Rückfrage (Pseudo-Fragen):

| Anti-Pattern | Stattdessen |
|--------------|-------------|
| Etwas, das im Prompt wörtlich steht | Prompt zitieren und umsetzen |
| Etwas, das das Repo eindeutig zeigt (Stack, Script, Konvention) | Repo lesen, belegen |
| Geschmacksfragen ohne Auswirkung auf DoD | Sensible Default-Annahme **dokumentieren** und weiter |
| Offene Brainstorm-Fragen („Was wünschst du dir noch?“) | Scope aus Prompt; Out-of-scope lassen |
| Fragen, die der Agent mit einem 2-Minuten-Check klären kann | Check ausführen |
| Mehr als nötig — Fragebatterie | Max. `clarification.max_questions_per_pause` (siehe config) |

Faustregel: Wenn du die Antwort aus Prompt + Repo + Gesetzbuch **belegen** kannst,
darfst du **nicht** fragen. Wenn zwei belegbare Antworten kollidieren → fragen.

## Erlaubte Default-Annahmen {#defaults}

Nicht-blockierende Lücken darf der Agent mit einer **dokumentierten Annahme** schließen
(Handover + State `assumptions[]`), wenn:

- die Annahme reversibel ist,
- sie kein `irrev`/`sec`/`legal`-Flag auslöst,
- und sie in einem Satz widerlegbar formuliert ist („Annahme: X; widerlegt wenn Y“).

Blockierende Punkte: **nie** per Annahme durchwinken.

## Format der Rückfrage {#format}

An den Auftraggeber, knappe Liste:

```
Klärungsbedarf (Lauf pausiert):
1. Frage …?
   Warum blockierend: …
   Optionen (wenn sinnvoll): A / B
2. …
```

Keine Essays. Keine versteckten Implementationen „bis du antwortest“.

## Wer fragt

| Situation | Wer |
|-----------|-----|
| Vor dem ersten teuren Gate | Orchestrator (kurz, selbst) |
| Während `N3b` | Business Analyst → Orchestrator → Nutzer |
| Während Review Widerspruch | Tester → Orchestrator → Nutzer |

Sub-Agenten fragen den Nutzer **nicht** direkt an Orchestrator vorbei.
