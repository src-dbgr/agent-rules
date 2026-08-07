# Triage — Klassen, Flags, Gates

> Normativ für `LAW-TRIAGE`. Es gibt **ein** Verfahren und kein Punktesystem: eine geordnete
> Regelliste bestimmt genau eine Klasse, davon unabhängige Flags heben das Prüfniveau.
> Knoten und Kanten stehen in `modules/workflow.md#knoten`, Zahlenwerte in
> `config/policy-defaults.json`, die maschinenlesbaren Tabellen in `manifest.json` (`triage`).

## 1. Verfahren in vier Schritten

1. **Klasse bestimmen** — Regelliste (§2) von oben nach unten lesen; die **erste** zutreffende
   Zeile gewinnt, weitere Zeilen werden nicht mehr geprüft. Ergebnis: `triage.change_class`,
   genau ein Wert.
2. **Flags setzen** — die Tabelle in §3 vollständig durchgehen; jedes Flag ist eine eigene Frage
   über die **Änderung**, nicht über das Thema. Ergebnis: `triage.signals`, keines bis alle neun.
3. **Gates ableiten** — `Gates(Anfrage) = Gates(Klasse) ∪ Gates(Flags)`, siehe §4.
4. **Festschreiben** — `triage.rationale` nennt die Nummer der getroffenen Regelzeile und je Flag
   den beobachteten Anlass; `Gates(Anfrage)` wird als Schlüsselmenge in `dod_gates` angelegt. Erst
   danach darf `N2` verlassen werden.

Es gibt keine Punktzahl, keine addierten Faktoren und keinen Schwellenwert. Wer das Prüfniveau erhöhen
will, setzt ein Flag — er stuft nicht die Klasse hoch (§8).

## 2. Klassen-Regelliste

Geordnet; die erste zutreffende Zeile gewinnt. Die Auslöser-Spalte nennt nur Merkmale, die an
Anfrage oder Repository **beobachtbar** sind.

| Nr | Klasse | Auslöser (beobachtbar, ohne Vorgriff auf das Ergebnis) |
|----|--------|--------------------------------------------------------|
| 1 | `incident` | Betrieb oder Nutzer sind **jetzt** beeinträchtigt; Behebung ist eilig |
| 2 | `revert` | Anfrage benennt eine bestimmte frühere Änderung, die zurückgenommen werden soll |
| 3 | `answer` | Anfrage verlangt Auskunft, Analyse oder Bericht — **keine** Änderung am Repository |
| 4 | `spike` | Ergebnis ist Erkenntnis oder Prototyp und soll ausdrücklich **nicht** im Hauptzweig verbleiben |
| 5 | `chore` | Änderung **ohne beobachtbare Verhaltensänderung** des Produkts (Text, Doku, Format, Werkzeug, Konfiguration, Abhängigkeits-Bump ohne Schnittstellenänderung) |
| 6 | `feature` | **Alles Übrige** (Catch-all, garantiert Totalität) |

**Warum das deterministisch ist.** Drei Eigenschaften zusammen: (a) die Liste ist **geordnet** und
die erste Treffer-Regel gewinnt, also entscheidet Mehrfachtreffer die Reihenfolge und nicht der
Zufall; (b) Zeile 6 ist ein Catch-all, also ist die Liste **total**; (c) kein Auslöser nennt einen
Klassennamen oder einen Pfadnamen, also ist keine Zeile **zirkulär** — man muss das Ergebnis nicht
kennen, um die Regel anzuwenden. (c) ist maschinell geprüft (`scripts/lint-lawbook.sh
--triage-criteria-mention-class`). Deterministisch ist damit das **Verfahren**; dass ein Modell aus
demselben Prompt dieselbe Klasse liest, ist damit **nicht** behauptet — dagegen sichern die
Fixtures aus §9.

## 3. Flags

Neun orthogonale Signale. Jedes Flag trägt **genau ein** Zusatz-Gate und ist unabhängig von der
Klasse: jedes Flag kann jede Klasse treffen. Maßstab ist immer die Änderung, nicht das Thema — eine
Auskunft über den Anmeldepfad trägt kein `sec`, weil sie nichts ändert.

| Flag | Anlass (bezogen auf die Änderung) | Zusatz-Gate |
|------|-----------------------------------|-------------|
| `sec` | Authentifizierung, Autorisierung, Geheimnisse, Angriffsfläche | `N6a` |
| `data` | Schema-, Migrations- oder Datenbestandsänderung | `N6a`, DoD erweitert um Reversibilität |
| `legal` | Lizenz, Datenschutz, regulatorische Pflicht | `N6a`, DoD erweitert um Lizenz- und Datenschutzprüfung |
| `ui` | sichtbare Oberflächenänderung | `N5b` |
| `api` | öffentliche Schnittstelle, Kommandozeile oder Konfiguration | `N5c` |
| `conc` | Nebenläufigkeit, Verteilung, gemeinsamer Zustand | `N3c`, DoD erweitert um Nebenläufigkeitsmodell |
| `arch` | neue Komponente, neue Abhängigkeitsrichtung, Querschnittsbelang | `N3c` |
| `perf` | Latenz-, Durchsatz- oder Ressourcenziel ist der Anlass | `dod:perf_budget` |
| `irrev` | schwer oder nicht rückholbar (Löschung, Abschaltung, Migration) | `dod:rollback_snapshot` |

Mehrere Flags dürfen auf dasselbe Gate zeigen; dessen DoD erweitert sich dann je Flag, es entsteht
aber kein zweites Gate.

## 4. Gate-Matrix {#gate-matrix}

`Gates(Anfrage) = Gates(Klasse) ∪ Gates(Flags)` — **Vereinigung** (High-Water-Mark), keine Summe
und kein Mittelwert. Ein Gate ist entweder ein Knoten aus `modules/workflow.md#knoten` oder ein
DoD-Schlüssel der Form `dod:<name>`.

| Klasse | Gate-Set | Besonderheit |
|--------|----------|--------------|
| answer | `N1` `N2` `N7` | kein `N4`, kein Branch, keine Auslieferung |
| chore | `N1` `N2` `N4` `N5a` `N6b` `N7` | `N5a` ohne Konformitätsprüfung gegen die Architektur |
| revert | `N1` `N2` `N4` `N5a` `N6b` `N7` `dod:revert_diff_only` | wie chore, zusätzlich Diff-Nachweis |
| spike | `N1` `N2` `N3a` `N4` `N7` `dod:spike_disposal` | kein `N5a`, kein `N6b` in den Hauptzweig |
| incident | `N1` `N2` `N4` `N5a` `N6b` `N7` `dod:followup_ref` | `N3b`, `N5c` und `N6a` dürfen `deferred` sein |
| feature | `N1` `N2` `N3b` `N4` `N5a` `N6b` `N7` | Standardweg |

**Zusatzregel `N3a`.** Ist die Anfrage ohne externe Quelle nicht beantwortbar, wird `N3a` ergänzt.
Das ist eine Knoten-Ergänzung, kein Klassenwechsel — auch eine Auskunft darf recherchieren.

**Beispiel für den High-Water-Mark:** `conc` oder `arch` auf einer Änderung der Klasse `chore` erreicht das Gate-Niveau von `feature`, ohne die Klasse zu wechseln.

Die sechs Gate-Sets sind paarweise verschieden; wären zwei gleich, gehörten die Klassen
zusammengelegt (`scripts/lint-lawbook.sh --triage-gate-sets-distinct`).

## 5. DoD je Klasse

Zusätzlich zum DoD jedes betretenen Knotens (`modules/workflow.md`) gilt je Klasse:

#### DoD `incident`
Eile darf Prüfung verschieben, nicht ersetzen: `N3b`, `N5c` und `N6a` dürfen im State als
`deferred` stehen, aber `t_done` ist nur mit gesetztem `followup_ref` erreichbar (Schemasperre).
Ohne Nachweis der Behebung bleibt der Lauf offen.

#### DoD `revert`
Der Diff enthält **nur Rücknahme** — keine neue Logik, keine Aufräumarbeit, keine Umbenennung.
Nachweis: `dod:revert_diff_only` mit Diff-Bericht. Verhaltensgleichheit zum Stand vor der
zurückgenommenen Änderung ist geprüft.

#### DoD `answer`
Kein Arbeitsbranch, kein Commit, keine Auslieferung. Jede Aussage trägt eine Quelle (Datei und
Zeile im Repository oder externe Quelle) oder einen ausdrücklichen Unsicherheitsvermerk.

#### DoD `spike`
Am Ende steht die **Entsorgung** oder die Reklassifikation: entweder ist der Prototyp verworfen
(Branch bleibt als Bericht, kein Merge in den Hauptzweig) oder der Erkenntnisgewinn wird als neue
Anfrage der Klasse `feature` gestellt. Nachweis: `dod:spike_disposal`.

#### DoD `chore`
Nachweis, dass sich das beobachtbare Verhalten **nicht** geändert hat: bestehende Testsuite grün
ohne Testanpassung. Wird eine Testanpassung nötig, war es keine Wartungsarbeit — Klasse neu
bestimmen.

#### DoD `feature`
Jedes Akzeptanzkriterium aus `N3b` hat mindestens einen Test, und die Konformitätsprüfung gegen die
bestehende Architektur an `N5a` ist bestanden.

## 6. Aufwandsbudget

Der Aufwand folgt der Klasse, nicht dem Ehrgeiz. Werte: `config/policy-defaults.json#/effort` —
je Klasse `max_subagents` und `max_tool_calls`, je gesetztem Flag der Zuschlag aus
`effort.flag_bonus`, hart begrenzt durch `budgets.max_total_spawned`. Ein Einzeiler kostet damit
einen Sub-Agenten und keinen dreifachen Bootstrap. Überschreitung ist ein Blocker-Eintrag, keine
stille Fortsetzung (`modules/context.md#budget`).

## 7. Kompatibilitäts-Mapping alt→neu

Nur zum Lesen von Altbeständen (Zustandsdateien, Handover, Commit-Nachrichten aus v1.3.1). Die
alten Namen sind in v2 **kein** gültiges Vokabular; sie dürfen nur hier und in
`docs/migration-v1-to-v2.md` stehen.

| Altwert (v1.3.1) | Klasse | Flags | Anmerkung |
|------------------|--------|-------|-----------|
| `fast`, `FAST_TRACK`, `fast_track` | chore | — | wenn keine Änderung am Repository verlangt war: answer |
| `standard`, `STANDARD_TRACK`, `standard_track` | feature | — | Standardweg, unverändert |
| `deep`, `DEEP_TRACK`, `deep_track` | feature | `arch`, dazu `conc`, `sec` oder `data`, falls genannt | „tief" war ein Flag-Effekt, keine eigene Klasse |
| Punktwert 1–10 oder addierte Risikofaktoren | — | — | Feld entfällt beim Migrieren, kein Ersatz |
| freie Signalwerte | — | auf die neun Flags abgebildet | Unbekanntes wird verworfen und als Blocker vermerkt |

Verfahren und Skript der Umstellung: `docs/migration-v1-to-v2.md`.

## 8. Anti-Overengineering

1. **Klasse nach Auslöser, nicht nach Gefühl.** Die Regelliste ist abschließend; „lieber
   vorsichtshalber die schwerere Klasse" ist kein Grund, sondern eine Flag-Frage.
2. **Grenzfall: Flag setzen, nicht Klasse heben.** Ein Abhängigkeits-Bump wegen einer Schwachstelle
   bleibt Wartungsarbeit mit `sec` — er wird kein Vorhaben mit Anforderungsanalyse.
3. **Kein Gate auf Vorrat.** Ein Flag wird nur gesetzt, wenn sein Anlass beobachtbar ist; die
   Begründung steht in `triage.rationale`.
4. **Rote Prüfstrecke ist kein Vorfall,** solange kein Nutzer und kein Betrieb beeinträchtigt ist.
5. **Thema ist nicht Änderung.** Eine Auskunft über einen sicherheitsrelevanten Bereich trägt kein
   Flag, weil sie nichts ändert.
6. **Umgekehrt gilt kein Rabatt:** Wartungsarbeit an Anmeldung, Bezahlung oder Datenschema trägt
   `sec`, `data` oder `legal` und damit `N6a` — trotz kleiner Diff-Größe.

## 9. Nachweis und Grenze

- Algebra-Prüfung: `scripts/check-triage.sh` leitet für jeden Fixture-Fall
  `Gates(Klasse) ∪ Gates(Flags)` aus `manifest.json` ab und vergleicht mit dem erwarteten Gate-Set;
  zusätzlich prüft es Ordnung, Klassen- und Flag-Abdeckung, Verschiedenheit der Gate-Sets und
  Nicht-Zirkularität. Exit 0 = alles bestanden.
- Fälle: `tests/fixtures/triage-cases.json`; verlangt sind Fixtures mindestens 20
  (`enforcement.triage_fixtures_min`), darunter ein Ordnungsfall, zwei High-Water-Mark-Belege und
  zwei Grenzfälle.
- **Geprüfte Grenze, ausdrücklich:** nachgewiesen ist die Ableitung Klasse + Flags → Gates und die
  Ordnung der Regelliste. **Nicht** nachgewiesen ist, dass ein Modell aus einem gegebenen Prompt
  dieselbe Klasse wählt (Annahme A-12); Fixtures sind kein Ersatz für starke Erst-Klassifikation.
  Deshalb: Main-Thread an `N2` laut `config/model-policy.json#/entry_points` (`grok-4.5-high`),
  plus `LAW-CLARIFY` bei Unsicherheit — nicht Composer am Eingang.
- Drei belegte Grenzfälle als Lesehilfe: eine kaputte Prüfstrecke ist Wartungsarbeit (kein
  Vorfall); ein eiliger Produktionsausfall, der durch Rücknahme behoben wird, ist Regel 1 und nicht
  Regel 2; eine Kontrastkorrektur ist sichtbar und deshalb keine Wartungsarbeit.
