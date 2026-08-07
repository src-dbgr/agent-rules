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

Vor und während `N3c`/`N4` gilt:

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

UI: automatisierte visuelle Regression nur bei sichtbarer Änderung — Pflicht, aber schmal.

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
| Developer (`N4`) | Änderung driftfrei; Selbsttest nur für **neue** Risiken; keine Suite-Müllcommits |
| Tester (`N5a`) | Traceability AK→Test; Konformitäts-Gate; **Test-Review**: Bloat ablehnen; fehlende Vertrags-/Regressionsfälle blockierend |

Nachweis: Suite Exit 0 **und** kurzer Vermerk „warum diese Tests, was bewusst nicht“.
