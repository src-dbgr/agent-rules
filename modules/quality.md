# Qualität — Regressionen verhindern, Tests mit Mehrwert

> Normativ für `LAW-QUALITY`. Leitidee: **nicht** „mehr Tests und längere Reviews“,
> sondern Architektur und Verträge so schneiden, dass ganze Fehlerklassen
> **strukturell unmöglich** oder **sofort sichtbar** werden. Tests sind das Netz
> darunter — scharf, nicht aufgebläht.

Bezug (Praxis, keine Zitatpflicht im Lauf): Clean Architecture / Dependency Rule;
Fowler (Refactoring, Test Pyramid, Charakterisierungstests, Branch by Abstraction);
Kleppmann (Datenmodelle, Idempotenz, Konsistenzgrenzen); Enterprise-/FAANG-Testkultur
(Risiko × Wahrscheinlichkeit, nicht Abdeckungsfetisch).

## 1. Regression-Resistenz by Design {#by-design}

Vor und während `N3c`/`N4` gilt — und der Programmentwurf (`dod:program_design`)
hält es fest, bevor gebaut wird:

1. **Abhängigkeitsregel** — innere Schichten kennen keine äußeren Details
   (UI/Framework/DB hängen am Kern, nicht umgekehrt). Neue Rückwärtsabhängigkeit = Drift → `N5a→N3c`.
2. **Schmale, stabile Verträge** — öffentliche APIs/Events/Schemas versionieren;
   Breaking Changes nur mit `irrev` + Approval (`modules/ops.md#approval`).
3. **Eine Schreibautorität je Datum** — parallele Agenten bekommen disjunkte
   `write_paths` (Assignment-Ledger). Kein optimistisches Merge derselben Datei.
4. **Idempotente Grenzen** — Befehle/Handler so, dass Wiederholung denselben
   Zustand ergibt (wichtig für Resume und Retries).
5. **Feature-Flags / Branch by Abstraction** — riskante Umschaltungen hinter
   Schalter oder Adapter; Rollback ohne Hotfix-Hektik.
6. **Charakterisierung vor Blind-Rewrite** — bei Legacy: Verhalten zuerst mit
   wenigen gezielten Tests einfrieren, dann ändern (Fowler).

**SOLID-Kern (ohne Katechismus):** Separation of Concerns und SRP über klare
Modul-/Rollengrenzen; ISP und stabile Verträge über schmale Schnittstellen;
DIP / Dependency Rule über Abhängigkeiten nach innen. **Zirkuläre Abhängigkeiten
sind verboten** (Architect-DoD + Konformitäts-Gate `N5a`). OCP/LSP folgen aus
versionierten Verträgen und verhaltenstreuen Untertypen — kein eigenes Ritual.
Optionale Cycle-Checks im Zielprojekt (z. B. madge, dependency-cruiser), wenn der
Stack das hergibt; kein Pflicht-Scanner im Vendor-Gesetzbuch.

Architektur- und Code-Reviews prüfen **diese** Eigenschaften vor „Style“.

## 2. Was getestet werden muss {#must-test}

Pflicht (je Akzeptanzkriterium mindestens eines, wo sinnvoll):

| Ebene | Zweck | Wann |
|-------|-------|------|
| Vertrag / Schema | kaputte Schnittstellen sofort | öffentliche APIs, Events, Persistenz |
| Domänen-/Unit am Kern | Invarianten der Fachlogik | reine Logik ohne I/O |
| Integration an Grenzen | Adapter, DB, Queue | wo echte Grenzen existieren |
| Charakterisierung | Legacy-Verhalten halten | vor riskantem Umbau |
| Gezielte Regression | genau der Bug/die Klasse, die schon weh tat | nach jedem Fix |
| E2E / visuell | wenige kritische Nutzerpfade | nicht jeder Klick |

## 2a. Oberflächen (GUI) — Playwright und bildbasiertes Review {#ui}

Gilt bei Flag `ui` bzw. sichtbarer Oberflächenänderung (Gate `N5b`). Sichtet derselben
Disziplin wie §2/§3: **schmal und risikotragend**, keine Klick- und Snapshot-Wände.

1. **Produkt-Suite (Playwright oder Äquivalent).** Wenige kritische Nutzerpfade
   automatisiert (Happy Path + relevante Leer-/Fehlerzustände). Sichtbare Änderung
   ohne grünen E2E-/visuellen Lauf → Gate nicht bestanden. Bevorzugt das im Zielprojekt
   etablierte Werkzeug (typisch Playwright); kein Zweit-Framework „nur für Agenten“.
2. **Visuelle Regression.** Nur dort, wo Layout/Look regressionsanfällig ist — schmale
   Snapshots, keine Vollseiten-Wände ohne Aussage (`§3`). Baselines der **Produkt-Suite**
   versioniert das Zielprojekt nach dessen Konvention.
3. **Bildbasiertes Agent-Review (Pflicht bei komplexer UI).** Zusätzlich zur Suite prüft
   Tester/`N5b` mit Browser: Screenshots (Desktop/relevant mobil), Auswertung gegen
   Akzeptanzkriterien und Design-Konsistenz (Zustände, Hierarchie, offensichtliche
   A11y-Brüche). Manuelle Sichtprüfung *ohne* Artefaktpfad und ohne Suite reicht nicht.
4. **Ephemere Verifikationsbilder — nie committen.** Screenshots und Agent-Review-Captures
   liegen nur unter `proof-artifacts/` oder `runtime/tmp/` (gitignored, GC). Sie gehören
   **nicht** ins VCS. Im Handover nur **Pfade**, keine Inline-Bilder.
   Ausnahme: versionierte Baselines der Produkt-Suite im Zielprojekt — das sind
   Suite-Artefakte, keine Review-Captures.

## 3. Was nicht getestet werden darf {#anti-bloat}

**Verboten**, die Suite aufzublähen ohne Mehrwert:

- reine Getter/Setter / Framework-Glue ohne Logik
- Implementation-Details (private Hilfsfunktionen), die sich bei Refactor drehen
- 1:1-Spiegel des Produktionscodes („assert true nach mock alles“)
- Snapshot-Wände ohne Aussage
- doppelte Tests derselben Invariante auf drei Ebenen
- Tests „weil Coverage-Tool rot war“ ohne Risikoargument

Faustregel: Schlägt der Test fehl — **würde ein Nutzer oder ein Vertrag brechen?**
Sonst streichen oder auf die richtige Ebene heben.

## 4. Gates (Rollen)

| Rolle | Pflicht |
|-------|---------|
| Architect (`N3c`) | Entwurf erfüllt §1; Verträge und Abhängigkeitsrichtung benannt |
| Developer (`N4`) | Vertikale Schnitte laut Plan, je Schnitt ein Prüfkommando; Änderung driftfrei; Selbsttest nur für **neue** Risiken; keine Suite-Müllcommits |
| Tester (`N5a`) | Traceability AK→Test; Konformitäts-Gate; **Test-Review**: Bloat ablehnen; fehlende Vertrags-/Regressionsfälle blockierend; bei `ui`: Playwright-/E2E-Disziplin + bildbasiertes Review (§2a) |
| UX/UI (`N5b`) | Visuelle Regression + A11y-Mindestmaß; komplexe UI mit Screenshot-Evaluation; keine Review-Captures committen |

Nachweis: Suite Exit 0 **und** kurzer Vermerk „warum diese Tests, was bewusst nicht“.
Bei `ui`: zusätzlich Exit 0 der visuellen/E2E-Läufe und Artefaktpfade des bildbasierten Reviews.
