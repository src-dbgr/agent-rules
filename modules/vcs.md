# VCS — Branches, Abräumen, Auslieferung

> Normativ für `LAW-VCS` und `LAW-DELIVERY`. Zahlen in `config/policy-defaults.json#/vcs`.
> Durchsetzung: `scripts/branch-hygiene.sh`.

## Branch-Lebenszyklus {#branch-lebenszyklus}

1. Arbeitsbranch folgt `vcs.branch_pattern` (Default: `cursor/` oder `agent/` + kebab-case).
2. Branch wird im Zustand unter `vcs.working_branch` registriert, sobald angelegt.
3. Lebensende-Ziel: `vcs.branch_max_age_hours` (Default siehe config). Überschreitung
   ist Berichtspflicht, kein automatisches Löschen.
4. Höchstens `vcs.max_active_task_branches` aktive Task-Branches je Repo (Report-Gate).

## Vier Löschverbote {#loeschverbote}

Hard fails — kein Override außer dokumentierter Nutzerfreigabe wo ausdrücklich erlaubt:

1. Niemals Default- oder geschützter Branch (`vcs.protected_branches`).
2. Niemals unmerged Branch (kein `-D`, kein `--force`).
3. Niemals Branch mit offenem PR/MR (nicht feststellbar → Verweigerung).
4. Niemals Remote-Referenz ohne Freigabe-Token **und** Bestätigung
   (`vcs.require_confirm_token`, Default `--i-know-what-i-do`).

Zusätzlich: niemals aktueller Branch; niemals im State registrierter Branch
eines laufenden Orchestrators. `vcs.delete_remote_allowed` ist Default `false`.
`vcs.force_push_allowed` ist `false`.

## Abräumen {#abraeumen}

```
./scripts/branch-hygiene.sh --report          # Default, ändert nichts
./scripts/branch-hygiene.sh --apply-local     # nur lokal, merged, Guards aktiv
./scripts/branch-hygiene.sh --remote <name> --i-know-what-i-do --confirm-delete-remote <name>
```

Dry-Run ist Default. Worktrees: `git worktree prune` erst nach Alter
`vcs.worktree_prune_expire_days`. Reflog/Recovery nicht verkürzen
(`vcs.reflog_expire_days_min`).

## Zuständigkeit {#zustaendigkeit}

| Aktion | Agent | Mensch / Plattform |
|--------|-------|--------------------|
| Branch anlegen (Pattern) | Developer | — |
| Report stale / merged | DevOps / Skript | — |
| Lokal merged löschen | Skript mit `--apply-local` | — |
| Remote löschen | **nein** (nur mit Freigabe) | Plattform-Auto-Delete oder Nutzer |
| Force-Push | verboten | nur Nutzer, bewusst |

## Auslieferung {#auslieferung}

Knoten `N6b` (`LAW-DELIVERY`):

1. Commit und Push sind Sache von `developer` bzw. `devops_sre` — **nie** des Orchestrators.
2. PR anlegen/aktualisieren: dieselbe Regel.
3. Plattform-Zwang (Cloud-Runner verlangt Push vom empfangenden Agenten): Eintrag in
   `blockers` mit Severity und Begründung „Plattform-Mandat" — Abweichung auditierbar,
   nicht stillschweigend.
4. Rollback-Pfad dokumentieren, bevor `N6b` als `passed` gilt.

## Nachweis

- Bericht: `scripts/branch-hygiene.sh --report` Exit 0.
- Selbsttest Guards: `scripts/branch-hygiene.sh --self-test-protections` Exit 0.
