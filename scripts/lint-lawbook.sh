#!/usr/bin/env bash
# lint-lawbook.sh — Durchsetzung des Gesetzbuchs v2.0 (ADR-009).
#
# 25 deterministische Pruefungen: die 24 aus ADR-009 plus --fixtures-declared
# (in WP-1 ergaenzt, siehe "Ergaenzung" unten). Alle Pruefungen lesen ihre
# Sollwerte aus den beiden SSoT-Dateien — manifest.json (Struktur) und
# config/policy-defaults.json (Zahlen) — und niemals aus einer Kopie im Skript.
#
# Sprache: Bash-Rahmen + eingebettetes python3. Begruendung: die Haelfte der
# Pruefungen ist Textanalyse mit Zeilennummern (Anker, Verweise, Prosa-Zahlen);
# in reinem Bash waere das entweder falsch oder unlesbar. jq und python3 sind
# beide vorausgesetzt (Annahme A-06); python3 deckt hier zusaetzlich JSON ab.
#
# Exit-Semantik (identisch in allen Pruefskripten, F-033/AK-082/AK-083):
#   0  alle ausgefuehrten Pruefungen PASS
#   1  mindestens ein FAIL
#   2  mindestens ein SKIP ("NICHT NACHGEWIESEN", Werkzeug fehlt) ohne --allow-skip
# SKIP gilt nie als PASS. --allow-skip ist lokal gedacht und wird verweigert,
# wenn $CI gesetzt ist (enforcement.allow_skip_in_ci = false).
# Eine fehlende, im Manifest als required deklarierte DATEI ist FAIL, kein SKIP.
#
# BEKANNTE GRENZEN (bewusst, nicht kaschiert):
#  * --no-prose-numbers prueft nur Zahlen, fuer die in manifest.json#/prose_number_guards
#    ein Muster registriert ist. Eine unregistrierte Zahl in Prosa bleibt
#    unentdeckt. Der Volltext-Ansatz ("jede Zahl") ist false-positive-getrieben
#    nicht betreibbar. Die Ausgabe nennt Zahl der geprueften Treffer.
#  * --ssot erkennt Doppel-Normierung an doppelten Ueberschriften, nicht an
#    semantischer Aehnlichkeit. Paraphrasen entgehen ihr.
#  * --law-count kann nur Abweichungen finden; nennt ein Dokument keine
#    Gesetzeszahl, gibt es nichts zu vergleichen (wird in der Ausgabe gesagt).
#  * --edges/--node-ids sehen nur Zitate in der Form N<x> bzw. N<x> -> N<y>;
#    Prosa-Umschreibungen ("vom Test zurueck zur Implementierung") nicht.
#  * --model-coverage/--migration-table-complete pruefen specs/coverage.md
#    und docs/migration-v1-to-v2.md. Fehlen sie, ist das FAIL, kein SKIP.
#
# Ergaenzung gegenueber ADR-009: --fixtures-declared. Ohne sie kann eine Fixture
# im Baum liegen, die keine Stufe validiert ("stumme Pruefung") — genau der
# Fehlertyp, den WP-1 ausschliessen soll. Zaehler in
# config/policy-defaults.json#/enforcement/lint_checks_total ist deshalb 25.
set -uo pipefail

ROOT="."
ALLOW_SKIP=0
STRICT=0
QUIET=0
SELFTEST=0
SELECTED=()

ALL_CHECKS=(
  budget toc
  manifest-complete role-cards-match-enum runtime-paths-declared
  law-ids law-count node-ids edges unique-section-numbers
  links
  version-consistency phase-enum-sync no-prose-numbers config-provenance-complete
  triage-gate-sets-distinct triage-criteria-mention-class flags-have-gates
  schema-no-parallel-track-fields
  ssot
  delivery-path-exists state-path-per-orchestrator
  model-coverage
  migration-table-complete
  fixtures-declared
)

usage() {
  cat <<'EOF'
Aufruf: scripts/lint-lawbook.sh [--all | --<pruefung> ...] [Optionen]

Pruefungen (25 = 24 aus ADR-009 + 1 Ergaenzung):
  Groesse     --budget                        Zeilen/Bytes je Dateiklasse gegen config; Summe der Normtexte
              --toc                           jede .md ueber dem Schwellwert hat "## Inhalt"
  Struktur    --manifest-complete             jede versionierte Datei im Manifest und umgekehrt
              --role-cards-match-enum         Rollen-Karten == Schema-Enum; 4 Pflichtabschnitte
              --runtime-paths-declared        jeder Pfad unter runtime/ steht in der Layout-Tabelle
  IDs         --law-ids                       jeder LAW-*-Verweis existiert im Kanon
              --law-count                     genannte Gesetzeszahl == tatsaechliche
              --node-ids                      Knoten-IDs aus der Whitelist; Alt-IDs oberhalb N7 verboten
              --edges                         jede zitierte Kante existiert im Kantenmodell
              --unique-section-numbers        keine doppelte Abschnittsnummer je Datei
  Verweise    --links                         jeder Pfad und jeder Anker existiert
  Konsistenz  --version-consistency           eine Version ueber alle Artefakte
              --phase-enum-sync               Phasenraum in Schema, Manifest, Modul identisch
              --no-prose-numbers              registrierte Zahlen == config (Grenze: nur registrierte)
              --config-provenance-complete    jeder Zahlenwert hat _provenance
  Triage      --triage-gate-sets-distinct     die 6 Gate-Sets sind paarweise verschieden
              --triage-criteria-mention-class kein Ausloeser nennt Klasse oder Track
              --flags-have-gates              jedes der 9 Flags hat genau ein Zusatz-Gate
  Schema      --schema-no-parallel-track-fields  kein track/decision/complexity_score
  SSoT        --ssot                          jedes Konzept nur in seiner normativen Datei
  Lieferung   --delivery-path-exists          jede Klasse ausser answer hat Push-Recht
              --state-path-per-orchestrator   State-Pfadmuster und Lock-Regel dokumentiert
  Modell      --model-coverage                jeder Knoten/jede Kante in specs/coverage.md
  Migration   --migration-table-complete      jede v1.3.1-Datei in der Umzugstabelle
  Fixtures    --fixtures-declared             jede Fixture hat einen Erwartungswert (Ergaenzung)

Optionen:
  --all           alle Pruefungen
  --strict        SKIP zaehlt als FAIL
  --allow-skip    Exit 2 -> 0 (lokal; in CI verweigert)
  --root <dir>    Wurzel des zu pruefenden Baums (Default: .)
  --quiet         nur Statuszeilen, keine Fundstellen
  --self-test     je Pruefung: Mutation einspielen und Reaktion nachweisen
  --list          Namen aller Pruefungen, eine je Zeile
  --help          diese Hilfe
Exit: 0 PASS · 1 FAIL · 2 NICHT NACHGEWIESEN
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --all) SELECTED=("${ALL_CHECKS[@]}"); shift ;;
    --strict) STRICT=1; shift ;;
    --allow-skip) ALLOW_SKIP=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --self-test) SELFTEST=1; shift ;;
    --root) ROOT="${2:?--root braucht ein Verzeichnis}"; shift 2 ;;
    --list) printf '%s\n' "${ALL_CHECKS[@]}"; exit 0 ;;
    --help|-h) usage; exit 0 ;;
    --*)
      name="${1#--}"
      found=0
      for c in "${ALL_CHECKS[@]}"; do [ "$c" = "$name" ] && found=1 && break; done
      if [ "$found" = 1 ]; then SELECTED+=("$name"); shift
      else printf 'FAIL: unbekannte Pruefung --%s (siehe --help)\n' "$name" >&2; exit 1; fi ;;
    *) printf 'FAIL: unerwartetes Argument %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [ "$ALLOW_SKIP" = 1 ] && [ -n "${CI:-}" ]; then
  printf 'FAIL: --allow-skip ist in CI verboten (config/policy-defaults.json#/enforcement/allow_skip_in_ci)\n' >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'NICHT NACHGEWIESEN: lint-lawbook (alle Pruefungen) (Werkzeug python3 fehlt)\n'
  printf '\nZusammenfassung: 0 PASS, 0 FAIL, %d NICHT NACHGEWIESEN\n' "${#ALL_CHECKS[@]}"
  [ "$ALLOW_SKIP" = 1 ] && exit 0
  exit 2
fi

read -r -d '' LINT_PY <<'PYEOF'
import json, os, re, subprocess, sys, math, unicodedata

ROOT = sys.argv[1]
CHECKS = sys.argv[2:]
STRICT = os.environ.get("LINT_STRICT") == "1"
QUIET = os.environ.get("LINT_QUIET") == "1"
EMIT = os.environ.get("LINT_EMIT_STATUS") == "1"

def rp(*parts):
    return os.path.join(ROOT, *parts)

def read_text(rel):
    try:
        with open(rp(rel), encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None

def read_json(rel):
    txt = read_text(rel)
    if txt is None:
        return None
    try:
        return json.loads(txt)
    except ValueError as exc:
        return {"__parse_error__": str(exc)}

MAN = read_json("manifest.json")
CFGD = read_json("config/policy-defaults.json")

def glob_re(pattern):
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?"); i += 3
        elif pattern.startswith("**", i):
            out.append(".*"); i += 2
        elif pattern[i] == "*":
            out.append("[^/]*"); i += 1
        elif pattern[i] == "?":
            out.append("[^/]"); i += 1
        else:
            out.append(re.escape(pattern[i])); i += 1
    return re.compile("^" + "".join(out) + "$")

EXCLUDE = [glob_re(g) for g in (MAN or {}).get("manifest_scope", {}).get("exclude_globs", [])]

def excluded(rel):
    return any(rx.match(rel) for rx in EXCLUDE)

_scope_cache = None
def scope_files():
    """Versionierte Dateien des Baums (git, sonst Verzeichnis-Walk) ohne exclude_globs."""
    global _scope_cache
    if _scope_cache is not None:
        return _scope_cache
    files = []
    try:
        out = subprocess.run(["git", "-C", ROOT, "ls-files", "--cached", "--others",
                              "--exclude-standard"], capture_output=True, text=True, timeout=60)
        if out.returncode == 0 and out.stdout.strip():
            files = [ln for ln in out.stdout.splitlines() if ln]
    except (OSError, subprocess.SubprocessError):
        files = []
    if not files:
        for base, dirs, names in os.walk(ROOT):
            dirs[:] = [d for d in dirs if d != ".git"]
            for n in names:
                rel = os.path.relpath(os.path.join(base, n), ROOT).replace(os.sep, "/")
                files.append(rel)
    _scope_cache = sorted(f for f in files if not excluded(f) and os.path.isfile(rp(f)))
    return _scope_cache

def md_files():
    return [f for f in scope_files() if f.endswith(".md")]

def normative_md():
    keep = []
    for f in md_files():
        if f == "AGENTS.md" or f.startswith("modules/") or f.startswith("roles/"):
            keep.append(f)
    return keep

def lines_of(rel):
    txt = read_text(rel)
    return [] if txt is None else txt.splitlines()

def pointer(doc, ptr):
    cur = doc
    for part in ptr.strip("/").split("/"):
        if part == "":
            continue
        part = part.replace("~1", "/").replace("~0", "~")
        if isinstance(cur, list):
            try:
                cur = cur[int(part)]
            except (ValueError, IndexError):
                return None
        elif isinstance(cur, dict):
            if part not in cur:
                return None
            cur = cur[part]
        else:
            return None
    return cur

EXPLICIT_ANCHOR_RX = re.compile(r"\{#([A-Za-z0-9_-]+)\}")

def slug(text):
    text = EXPLICIT_ANCHOR_RX.sub("", text)
    text = re.sub(r"`", "", text).strip()
    text = re.sub(r"^\d+(\.\d+)*[.)]?\s*", "", text)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"\s+", "-", text.strip())
    return text

_head_cache = {}
def headings(rel):
    if rel in _head_cache:
        return _head_cache[rel]
    res = []
    fence = False
    for no, ln in enumerate(lines_of(rel), 1):
        if ln.startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        m = re.match(r"^(#{1,6})\s+(.*?)\s*$", ln)
        if m:
            res.append((no, len(m.group(1)), m.group(2)))
    _head_cache[rel] = res
    return res

def anchors_of(rel):
    found = set()
    fence = False
    for ln in lines_of(rel):
        if ln.startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        for m in EXPLICIT_ANCHOR_RX.finditer(ln):
            found.add(m.group(1).lower())
    for h in headings(rel):
        s = slug(h[2])
        if s:
            found.add(s)
    return found

def code_stripped(rel):
    """Zeilen ohne Codeblock-Inhalt; Inline-Code bleibt (Pfade stehen dort)."""
    out, fence = [], False
    for no, ln in enumerate(lines_of(rel), 1):
        if ln.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        out.append((no, ln))
    return out

# --- Ergebnis-Sammlung -------------------------------------------------------
RESULTS = []

class Check:
    def __init__(self, name):
        self.name = name
        self.findings = []
        self.notes = []
        self.skip_tool = None
        self.detail = ""
    def bad(self, where, msg):
        self.findings.append((where, msg))
    def note(self, msg):
        self.notes.append(msg)
    def skip(self, tool):
        self.skip_tool = tool

def emit(chk):
    if chk.skip_tool:
        status = "SKIP"
        print("NICHT NACHGEWIESEN: %s (Werkzeug %s fehlt)" % (chk.name, chk.skip_tool))
    elif chk.findings:
        status = "FAIL"
        print("FAIL: %s (%d Fundstelle(n))%s" % (chk.name, len(chk.findings),
                                                 (" — " + chk.detail) if chk.detail else ""))
        if not QUIET:
            for where, msg in chk.findings:
                print("    %s: %s" % (where, msg))
    else:
        status = "PASS"
        print("PASS: %s%s" % (chk.name, (" (" + chk.detail + ")") if chk.detail else ""))
    if not QUIET:
        for n in chk.notes:
            print("    Hinweis: %s" % n)
    if EMIT:
        print("#STATUS %s %s %d" % (chk.name, status, len(chk.findings)))
    RESULTS.append((chk.name, status))

def require_ssot(chk):
    """Beide SSoT-Dateien muessen lesbar sein, sonst ist jede Pruefung sinnlos."""
    ok = True
    for rel, doc in (("manifest.json", MAN), ("config/policy-defaults.json", CFGD)):
        if doc is None:
            chk.bad(rel, "Pflichtdatei fehlt")
            ok = False
        elif "__parse_error__" in doc:
            chk.bad(rel, "kein gueltiges JSON: %s" % doc["__parse_error__"])
            ok = False
    return ok

# --- 1 budget ----------------------------------------------------------------
def chk_budget(c):
    caps = CFGD["caps"]
    cap_of_kind = MAN["line_cap_of_kind"]
    bpl = caps["bytes_per_line_proxy"]
    bpt = caps["bytes_per_token_proxy"]
    checked = 0
    for d in MAN["documents"]:
        path = d.get("path")
        kind = d["kind"]
        ml, mb, te = d.get("max_lines"), d.get("max_bytes"), d.get("tokens_est_max")
        if ml is not None and kind in cap_of_kind:
            klass_cap = pointer(CFGD, cap_of_kind[kind])
            if klass_cap is None:
                c.bad("manifest.json", "%s: Klassen-Cap %s fehlt in der Konfiguration" % (d["id"], cap_of_kind[kind]))
            elif ml > klass_cap:
                c.bad("manifest.json", "%s: max_lines %d ueber Klassen-Cap %d (%s)" % (d["id"], ml, klass_cap, cap_of_kind[kind]))
        if te is not None:
            base = mb if mb is not None else (ml * bpl if ml is not None else None)
            if base is not None:
                want = math.ceil(base / bpt)
                if te != want:
                    c.bad("manifest.json", "%s: tokens_est_max %d, abgeleitet %d (%s/%d)" % (d["id"], te, want, "max_bytes" if mb else "max_lines*%d" % bpl, bpt))
        if path and os.path.isfile(rp(path)):
            checked += 1
            data = open(rp(path), "rb").read()
            n_lines = len(data.decode("utf-8", "replace").splitlines())
            if ml is not None and n_lines > ml:
                c.bad("%s:%d" % (path, ml + 1), "%d Zeilen ueber Budget %d" % (n_lines, ml))
            if mb is not None and len(data) > mb:
                c.bad(path, "%d Bytes ueber Budget %d" % (len(data), mb))
    total_cap = caps["normative_total_max_lines"]
    declared = sum(d["max_lines"] for d in MAN["documents"]
                   if d["kind"] in ("core", "module", "role_card") and d.get("max_lines"))
    if declared > total_cap:
        c.bad("manifest.json", "Summe der Normtext-Budgets %d ueber %d" % (declared, total_cap))
    actual = 0
    for d in MAN["documents"]:
        if d["kind"] in ("core", "module", "role_card") and d.get("path") and os.path.isfile(rp(d["path"])):
            actual += len(lines_of(d["path"]))
    if actual > total_cap:
        c.bad("normative Summe", "%d Zeilen ueber %d" % (actual, total_cap))
    c.detail = "%d vorhandene Dateien gemessen, Budget-Summe %d/%d, Ist-Summe %d" % (checked, declared, total_cap, actual)

# --- 2 toc -------------------------------------------------------------------
def chk_toc(c):
    thr = CFGD["caps"]["toc_required_from_lines"]
    n = 0
    for f in md_files():
        ls = lines_of(f)
        if len(ls) > thr:
            n += 1
            if not any(re.match(r"^##\s+Inhalt\s*$", l) for l in ls):
                c.bad("%s:1" % f, "%d Zeilen (> %d) ohne '## Inhalt'" % (len(ls), thr))
    c.detail = "%d Datei(en) ueber %d Zeilen" % (n, thr)

# --- 3 manifest-complete -----------------------------------------------------
def chk_manifest_complete(c):
    concrete = {d["path"]: d for d in MAN["documents"] if d.get("path")}
    globs = [(glob_re(d["path_glob"]), d) for d in MAN["documents"] if d.get("path_glob")]
    removals = {r["path"]: r for r in MAN["manifest_scope"]["expected_removals"]}
    files = scope_files()
    for f in files:
        if f in removals:
            r = removals[f]
            c.bad(f, "Loeschung ausstehend (%s): %s" % (r["owner_wp"], r["reason"]))
            continue
        if f in concrete:
            continue
        if any(rx.match(f) for rx, _ in globs):
            continue
        c.bad(f, "versionierte Datei ohne Manifest-Eintrag")
    for path, d in sorted(concrete.items()):
        if not os.path.isfile(rp(path)):
            if d.get("required"):
                c.bad(path, "Pflichtdatei fehlt (%s, %s)" % (d["id"], d["owner_wp"]))
            else:
                c.note("optionale Datei fehlt: %s (%s)" % (path, d["owner_wp"]))
    for rx, d in globs:
        if d.get("required") and not any(rx.match(f) for f in files):
            c.bad(d["path_glob"], "Pflicht-Glob ohne einzige Datei (%s, %s)" % (d["id"], d["owner_wp"]))
    c.detail = "%d Dateien im Baum, %d Manifest-Eintraege" % (len(files), len(MAN["documents"]))

# --- 4 role-cards-match-enum -------------------------------------------------
def chk_role_cards(c):
    schema = read_json("schemas/agent-state.schema.json")
    if schema is None or "__parse_error__" in schema:
        c.bad("schemas/agent-state.schema.json", "fehlt oder ist kein gueltiges JSON")
        return
    enum = pointer(schema, "/$defs/role/enum") or []
    # orchestrator hat bewusst keine Karte (der Kern regelt ihn), other ist der
    # Erweiterungsplatzhalter — beide sind vom Kartenzwang ausgenommen.
    roles = [r for r in enum if r not in ("other", "orchestrator")]
    cards = {d["path"].split("/")[-1][:-3]: d for d in MAN["documents"] if d["kind"] == "role_card"}
    for r in roles:
        if r not in cards:
            c.bad("manifest.json", "Rolle %s aus dem Schema-Enum hat keine Karte im Manifest" % r)
    for name, d in cards.items():
        if name not in roles:
            c.bad("manifest.json", "Karte %s ohne Eintrag im Schema-Enum" % d["path"])
    need = ["Mandat", "DoD", "Werkzeuge", "Rueckgabeformat"]
    for name, d in sorted(cards.items()):
        path = d["path"]
        if not os.path.isfile(rp(path)):
            c.bad(path, "Rollen-Karte fehlt (%s)" % d["owner_wp"])
            continue
        heads = {slug(h[2]) for h in headings(path)}
        for sect in need:
            alt = {slug(sect), slug(sect.replace("ue", "ü"))}
            if not (alt & heads):
                c.bad(path, "Pflichtabschnitt '## %s' fehlt" % sect)
    c.detail = "%d Rollen im Enum, %d Karten im Manifest" % (len(roles), len(cards))

# --- 5 runtime-paths-declared ------------------------------------------------
LEGACY_OK = ("CHANGELOG.md", "docs/migration-v1-to-v2.md", "scripts/migrate-state.sh")
def chk_runtime_paths(c):
    declared = [e["path"] for e in MAN["runtime_layout"]]
    forbidden = {e["path"]: e["reason"] for e in MAN["forbidden_runtime_paths"]}
    rx = re.compile(r"(?:runtime|proof-artifacts|states)/[A-Za-z0-9_.<>*/-]*")
    targets = [f for f in scope_files() if f.endswith((".md", ".sh", ".yml", ".yaml"))]
    hits = 0
    for f in targets:
        if f in LEGACY_OK:
            continue
        for no, ln in code_stripped(f):
            for m in rx.finditer(ln):
                p = m.group(0).rstrip(".,;:)`\"'")
                hits += 1
                # Nennung der bloszen Wurzel ("Pfade unter runtime/") ist generisch,
                # geprueft werden konkrete Unterpfade. runtime/* und runtime/** auch.
                rest = p.split("/", 1)[-1] if "/" in p else ""
                if p.rstrip("/") in ("runtime", "proof-artifacts", "states") or p.startswith("runtime/-"):
                    continue
                if rest in ("*", "**"):
                    continue
                bad = None
                for fp, reason in forbidden.items():
                    if p == fp.rstrip("/") or p.startswith(fp if fp.endswith("/") else fp + "/") or p == fp:
                        bad = "verbotener Pfad (%s)" % reason
                        break
                if bad is None and not any(p == d.rstrip("/") or p.startswith(d) for d in declared):
                    bad = "nicht in manifest.json#/runtime_layout deklariert"
                if bad:
                    c.bad("%s:%d" % (f, no), "%s — %s" % (p, bad))
    c.detail = "%d Pfadnennungen in %d Dateien, %d deklarierte Layout-Pfade" % (hits, len(targets), len(declared))

# --- 6 law-ids ---------------------------------------------------------------
def chk_law_ids(c):
    known = set()
    for law in MAN["laws"]:
        known.add(law["id"])
        for s in law.get("subrules", []):
            known.add(s if isinstance(s, str) else s.get("id", ""))
    # Wortgrenzen beidseitig: "LAW-IDs" ist ein Gattungsbegriff, kein Verweis.
    rx = re.compile(r"(?<![A-Za-z0-9-])LAW-[A-Z][A-Z0-9]*(?:\.[A-Z0-9_]+)*(?![A-Za-z0-9])")
    hits = 0
    for f in scope_files():
        if not f.endswith((".md", ".sh", ".json", ".yml")):
            continue
        if f in ("manifest.json",):
            continue
        for no, ln in enumerate(lines_of(f), 1):
            for m in rx.finditer(ln):
                hits += 1
                if m.group(0) not in known:
                    c.bad("%s:%d" % (f, no), "unbekannte Gesetzes-ID %s" % m.group(0))
    c.detail = "%d Verweise gegen %d Kanon-IDs" % (hits, len(known))

# --- 7 law-count -------------------------------------------------------------
def chk_law_count(c):
    n = len(MAN["laws"])
    rx = re.compile(r"\b(\d{1,3})\s+Gesetze\b")
    found = 0
    for f in normative_md() + ["README.md"]:
        if not os.path.isfile(rp(f)):
            continue
        for no, ln in enumerate(lines_of(f), 1):
            for m in rx.finditer(ln):
                found += 1
                if int(m.group(1)) != n:
                    c.bad("%s:%d" % (f, no), "nennt %s Gesetze, Kanon hat %d" % (m.group(1), n))
    c.detail = "%d Zahlangabe(n) gegen %d Gesetze" % (found, n)
    if found == 0:
        c.note("keine Zahlangabe gefunden — pruefbar sind nur Abweichungen, nicht das Fehlen")

# --- 8 node-ids --------------------------------------------------------------
FORBIDDEN_NODE_SCOPE = ("AGENTS.md", "modules/", "roles/", "workflows/", "schemas/")
def chk_node_ids(c):
    nodes = {n["id"] for n in MAN["cfg"]["nodes"]}
    terminals = {t["id"] for t in MAN["cfg"]["terminals"]}
    cat = read_json("runtime/architecture/cfg-v2-nodes.json")
    if isinstance(cat, dict) and "__parse_error__" not in cat:
        cat_nodes = {n["id"] for n in cat.get("nodes", [])}
        if cat_nodes and cat_nodes != nodes:
            c.bad("manifest.json#/cfg/nodes", "weicht vom Katalog ab: nur hier %s, nur dort %s"
                  % (sorted(nodes - cat_nodes), sorted(cat_nodes - nodes)))
        cat_edges = {(e["from"], e["to"]) for e in cat.get("edges", [])}
        man_edges = {(e["from"], e["to"]) for e in MAN["cfg"]["edges"]}
        if cat_edges and cat_edges != man_edges:
            c.bad("manifest.json#/cfg/edges", "weicht vom Katalog ab: nur hier %d, nur dort %d"
                  % (len(man_edges - cat_edges), len(cat_edges - man_edges)))
    rx = re.compile(r"(?<![A-Za-z0-9_])N(\d{1,2})([a-z])?(?![A-Za-z0-9_*])")
    hits = 0
    for f in scope_files():
        if not f.endswith((".md", ".json", ".sh")):
            continue
        if f in ("manifest.json",) or f in LEGACY_OK or f.startswith("tests/fixtures/"):
            continue
        strict_scope = f == "AGENTS.md" or any(f.startswith(p) for p in FORBIDDEN_NODE_SCOPE[1:])
        for no, ln in enumerate(lines_of(f), 1):
            for m in rx.finditer(ln):
                tok = m.group(0)
                hits += 1
                num = int(m.group(1))
                if strict_scope and num >= 8:
                    c.bad("%s:%d" % (f, no), "Alt-ID %s ist in v2-Dateien verboten (AK-076)" % tok)
                elif tok not in nodes and tok not in terminals:
                    c.bad("%s:%d" % (f, no), "Knoten %s steht nicht in der Whitelist" % tok)
    c.detail = "%d Knotenzitate gegen %d Knoten + %d Terminals" % (hits, len(nodes), len(terminals))

# --- 9 edges -----------------------------------------------------------------
def chk_edges(c):
    edges = {(e["from"], e["to"]) for e in MAN["cfg"]["edges"]}
    rx = re.compile(r"\b(N\d[a-c]?)\s*(?:->|→|>|=>)\s*(N\d[a-c]?|t_(?:done|blocked|abort))\b")
    hits = 0
    for f in scope_files():
        if not f.endswith(".md") or f in LEGACY_OK:
            continue
        for no, ln in enumerate(lines_of(f), 1):
            for m in rx.finditer(ln):
                hits += 1
                if (m.group(1), m.group(2)) not in edges:
                    c.bad("%s:%d" % (f, no), "Kante %s -> %s existiert nicht im Kantenmodell" % (m.group(1), m.group(2)))
    c.detail = "%d Kantenzitate gegen %d Kanten" % (hits, len(edges))

# --- 10 unique-section-numbers ----------------------------------------------
def chk_unique_sections(c):
    n = 0
    for f in md_files():
        seen = {}
        for no, level, text in headings(f):
            m = re.match(r"^(\d+(?:\.\d+)*)[.)]?\s+\S", text)
            if not m:
                continue
            num = m.group(1)
            n += 1
            if num in seen:
                c.bad("%s:%d" % (f, no), "Abschnittsnummer %s schon in Zeile %d" % (num, seen[num]))
            else:
                seen[num] = no
    c.detail = "%d numerierte Ueberschriften" % n

# --- 11 links ----------------------------------------------------------------
PATH_RX = re.compile(r"(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.(?:md|json|jsonl|sh|yml|yaml|tla|cfg|jar|txt)(?:#[A-Za-z0-9_-]+)?")
MDLINK_RX = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
def chk_links(c):
    refs = 0
    def check_ref(f, no, target):
        nonlocal refs
        if target.startswith(("http://", "https://", "mailto:", "#")):
            return
        target = target.split(" ")[0]
        path, _, anchor = target.partition("#")
        if not path:
            return
        if "<" in path or ">" in path or "*" in path:
            return
        if path.startswith(("runtime/", "proof-artifacts/", "states/")):
            return
        cands = [path]
        if "/" in f:
            cands.append(os.path.normpath(os.path.join(os.path.dirname(f), path)))
        hit = next((p for p in cands if os.path.exists(rp(p))), None)
        refs += 1
        if hit is None:
            c.bad("%s:%d" % (f, no), "Verweis auf nicht existierenden Pfad: %s" % path)
            return
        if anchor and hit.endswith(".md"):
            if anchor.lower() not in anchors_of(hit):
                c.bad("%s:%d" % (f, no), "Anker #%s fehlt in %s" % (anchor, hit))
    for f in md_files():
        for no, ln in code_stripped(f):
            for m in MDLINK_RX.finditer(ln):
                check_ref(f, no, m.group(1))
            for m in re.finditer(r"`([^`]+)`", ln):
                inner = m.group(1).strip()
                if PATH_RX.fullmatch(inner):
                    check_ref(f, no, inner)
    # Manifest-interne Referenzintegritaet
    doc_ids = {d["id"] for d in MAN["documents"]}
    anchor_ids = {a["id"] for a in MAN["anchors"]}
    for a in MAN["anchors"]:
        docp = a["document"]
        if not os.path.isfile(rp(docp)):
            c.bad("manifest.json", "Anker %s zeigt auf fehlende Datei %s" % (a["id"], docp))
        elif a["anchor"] not in anchors_of(docp):
            c.bad("manifest.json", "Anker %s (#%s) fehlt in %s" % (a["id"], a["anchor"], docp))
        refs += 1
    def reading_key_ok(item):
        if item in doc_ids or item in anchor_ids:
            return True
        if item in ("handover", "handover-template") and os.path.isfile(rp("templates/handover.md")):
            return True
        if item.startswith("role-") and os.path.isfile(rp("roles/%s.md" % item[5:])):
            return True
        if item.startswith("module-") and os.path.isfile(rp("modules/%s.md" % item[7:])):
            return True
        if os.path.isfile(rp(item)):
            return True
        return False
    for rl in MAN["reading_lists"]:
        for item in rl["read"]:
            refs += 1
            if not reading_key_ok(item):
                c.bad("manifest.json", "Leseliste %s/%s/%s verweist auf unbekannte ID %s"
                      % (rl["class"], rl["node"], rl["role"], item))
    for concept in MAN["ssot"]:
        tgt = concept["normative_in"]
        p, _, anc = tgt.partition("#")
        refs += 1
        if os.path.isdir(rp(p)) and not anc:
            pass
        elif not os.path.isfile(rp(p)):
            c.bad("manifest.json", "SSoT-Ziel %s fehlt (Konzept: %s)" % (p, concept["concept"]))
        elif anc and anc not in anchors_of(p):
            c.bad("manifest.json", "SSoT-Anker #%s fehlt in %s" % (anc, p))
    c.detail = "%d Verweise geprueft" % refs

# --- 12 version-consistency --------------------------------------------------
def chk_version(c):
    want = MAN["lawbook_version"]
    seen = [("manifest.json#/lawbook_version", want)]
    seen.append(("config/policy-defaults.json#/version", CFGD.get("version")))
    seen.append(("config/policy-defaults.json#/lawbook_version", CFGD.get("lawbook_version")))
    for where, val in seen:
        if val != want:
            c.bad(where, "Version %s, erwartet %s" % (val, want))
    st = MAN["state_schema_version"]
    schema = read_json("schemas/agent-state.schema.json")
    if schema and "__parse_error__" not in schema:
        pat = pointer(schema, "/properties/schema_version/pattern")
        if not pat or not re.match(pat, st):
            c.bad("schemas/agent-state.schema.json", "schema_version-Muster %r passt nicht zu %s" % (pat, st))
    for case in MAN["test_expectations"]["cases"]:
        if case["validator"] != "agent_state_schema":
            continue
        inst = read_json(case["path"])
        if not isinstance(inst, dict) or "__parse_error__" in inst:
            continue
        v = inst.get("schema_version")
        if case["expect"] == "pass" and v != st:
            c.bad(case["path"], "schema_version %s, erwartet %s" % (v, st))
    for rel, rx in (("AGENTS.md", r"^>\s*Version:\s*([0-9]+\.[0-9]+\.[0-9]+)"),
                    ("CHANGELOG.md", r"^##\s*\[?([0-9]+\.[0-9]+\.[0-9]+)")):
        if not os.path.isfile(rp(rel)):
            continue
        for no, ln in enumerate(lines_of(rel), 1):
            m = re.match(rx, ln)
            if m:
                if m.group(1) != want:
                    c.bad("%s:%d" % (rel, no), "nennt Version %s, erwartet %s" % (m.group(1), want))
                break
    c.detail = "Sollversion %s, State-Schema %s" % (want, st)

# --- 13 phase-enum-sync ------------------------------------------------------
def chk_phase_enum(c):
    phases = MAN["phases"]
    schema = read_json("schemas/agent-state.schema.json")
    if schema and "__parse_error__" not in schema:
        enum = pointer(schema, "/properties/phase/enum") or []
        if set(enum) != set(phases) or len(enum) != len(phases):
            c.bad("schemas/agent-state.schema.json", "Phasenraum %s != manifest %s" % (enum, phases))
    for t in MAN["cfg"]["terminals"]:
        if t["phase"] not in phases:
            c.bad("manifest.json", "Terminal %s nennt unbekannte Phase %s" % (t["id"], t["phase"]))
    mod = "modules/workflow.md"
    if os.path.isfile(rp(mod)):
        txt = read_text(mod)
        for p in phases:
            if p not in txt:
                c.bad(mod, "Phase %s wird im Normtext nicht genannt" % p)
    else:
        c.bad(mod, "Normtext fehlt (WP-3) — Phasenraum dort nicht pruefbar")
    c.detail = "%d Phasen, %d Terminals" % (len(phases), len(MAN["cfg"]["terminals"]))

# --- 14 no-prose-numbers -----------------------------------------------------
def chk_prose_numbers(c):
    guards = MAN["prose_number_guards"]
    hits = 0
    for g in guards:
        want = pointer(CFGD, g["pointer"])
        if want is None:
            c.bad("manifest.json", "Waechter zeigt auf unbekannten Pointer %s" % g["pointer"])
            continue
        try:
            rx = re.compile(g["pattern"])
        except re.error as exc:
            c.bad("manifest.json", "Waechter-Muster fuer %s ist kein gueltiger Regex: %s" % (g["pointer"], exc))
            continue
        globs = [glob_re(x) for x in g["files"]]
        for f in scope_files():
            if not any(gx.match(f) for gx in globs):
                continue
            for no, ln in code_stripped(f):
                for m in rx.finditer(ln):
                    hits += 1
                    got = m.group(1).replace(".", "").replace("\u202f", "")
                    if str(want) != got:
                        c.bad("%s:%d" % (f, no), "%s: Text nennt %s, Konfiguration %s" % (g["pointer"], m.group(1), want))
    c.detail = "%d Waechter, %d Treffer geprueft" % (len(guards), hits)
    c.note("Grenze: nur registrierte Waechter; unregistrierte Zahlen in Prosa bleiben unentdeckt")

# --- 15 config-provenance-complete ------------------------------------------
def chk_provenance(c):
    prov = CFGD.get("_provenance", {})
    keys = set(prov.keys())
    leaves = []
    def walk(node, path):
        if isinstance(node, dict):
            for k, v in node.items():
                if path == "" and k in ("_provenance", "$comment", "$schema_ref"):
                    continue
                walk(v, path + "/" + k)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, path + "/" + str(i))
        elif isinstance(node, bool):
            return
        elif isinstance(node, (int, float)):
            leaves.append(path)
    walk(CFGD, "")
    for ptr in leaves:
        parts = ptr.strip("/").split("/")
        covered = any("/" + "/".join(parts[:i]) in keys for i in range(1, len(parts) + 1))
        if not covered:
            c.bad("config/policy-defaults.json", "Zahlenwert %s ohne _provenance-Eintrag" % ptr)
    for k, v in prov.items():
        if pointer(CFGD, k) is None:
            c.bad("config/policy-defaults.json", "_provenance %s zeigt auf keinen Wert" % k)
        if v.get("herkunft") not in ("belegt", "setzung"):
            c.bad("config/policy-defaults.json", "_provenance %s ohne gueltige herkunft" % k)
    c.detail = "%d Zahlenwerte, %d Provenienz-Eintraege" % (len(leaves), len(prov))

# --- 16 triage-gate-sets-distinct -------------------------------------------
def chk_gate_sets(c):
    classes = MAN["triage"]["gate_matrix"]["classes"]
    seen = {}
    for name, gates in classes.items():
        key = tuple(sorted(set(gates)))
        if key in seen:
            c.bad("manifest.json", "Gate-Set von %s ist identisch mit %s" % (name, seen[key]))
        else:
            seen[key] = name
    declared = {cl["id"] for cl in MAN["triage"]["classes"]}
    if set(classes) != declared:
        c.bad("manifest.json", "Gate-Matrix %s != Klassenliste %s" % (sorted(classes), sorted(declared)))
    c.detail = "%d Klassen, %d verschiedene Gate-Sets" % (len(classes), len(seen))

# --- 17 triage-criteria-mention-class ---------------------------------------
def chk_criteria(c):
    bad_words = [cl["id"] for cl in MAN["triage"]["classes"]] + \
                ["fast-track", "standard-track", "deep-track", "fast_track", "standard_track", "deep_track"]
    rows = 0
    fx = read_json("tests/fixtures/triage-cases.json")
    if isinstance(fx, dict) and "class_order" in fx:
        for r in fx["class_order"]:
            rows += 1
            low = r["trigger"].lower()
            for w in bad_words:
                if re.search(r"(^|[^a-z0-9_])" + re.escape(w) + r"([^a-z0-9_]|$)", low):
                    c.bad("tests/fixtures/triage-cases.json", "Ausloeser der Regel %s nennt '%s'" % (r["rule_no"], w))
    else:
        c.bad("tests/fixtures/triage-cases.json", "class_order fehlt — Zirkularitaet nicht pruefbar")
    mod = "modules/triage.md"
    if os.path.isfile(rp(mod)):
        for no, ln in code_stripped(mod):
            if not ln.lstrip().startswith("|"):
                continue
            cells = [x.strip() for x in ln.strip().strip("|").split("|")]
            if len(cells) < 3 or not re.match(r"^\d+$", cells[0]):
                continue
            rows += 1
            trigger = " ".join(cells[2:]).lower()
            for w in bad_words:
                if re.search(r"(^|[^a-z0-9_])" + re.escape(w) + r"([^a-z0-9_]|$)", trigger):
                    c.bad("%s:%d" % (mod, no), "Ausloeser-Spalte nennt '%s' (Zirkularitaet)" % w)
    else:
        c.bad(mod, "Normtext fehlt (WP-3) — Regelliste dort nicht pruefbar")
    c.detail = "%d Ausloeser-Zeilen geprueft" % rows

# --- 18 flags-have-gates -----------------------------------------------------
def chk_flags_gates(c):
    flags = [f["id"] for f in MAN["triage"]["flags"]]
    gates = MAN["triage"]["gate_matrix"]["flags"]
    nodes = {n["id"] for n in MAN["cfg"]["nodes"]}
    for f in flags:
        if f not in gates:
            c.bad("manifest.json", "Flag %s hat kein Zusatz-Gate" % f)
            continue
        g = gates[f]
        if not isinstance(g, str) or not g:
            c.bad("manifest.json", "Flag %s: Gate ist keine einzelne Angabe" % f)
        elif not (g in nodes or g.startswith("dod:")):
            c.bad("manifest.json", "Flag %s: Gate %s ist weder Knoten noch dod-Schluessel" % (f, g))
    for f in gates:
        if f not in flags:
            c.bad("manifest.json", "Gate fuer unbekanntes Flag %s" % f)
    schema = read_json("schemas/agent-state.schema.json")
    if schema and "__parse_error__" not in schema:
        enum = pointer(schema, "/$defs/signal/enum") or \
               pointer(schema, "/properties/triage/properties/signals/items/enum") or []
        if set(enum) != set(flags):
            c.bad("schemas/agent-state.schema.json", "signals-Enum %s != Flag-Liste %s" % (sorted(enum), sorted(flags)))
    c.detail = "%d Flags, %d Gates" % (len(flags), len(gates))

# --- 19 schema-no-parallel-track-fields -------------------------------------
BANNED_FIELDS = ("track", "decision", "complexity_score", "triage_path")
def chk_no_parallel_fields(c):
    for f in sorted(scope_files()):
        if not (f.startswith("schemas/") and f.endswith(".json")):
            continue
        doc = read_json(f)
        if not isinstance(doc, dict) or "__parse_error__" in doc:
            c.bad(f, "kein gueltiges JSON")
            continue
        def walk(node, path):
            if isinstance(node, dict):
                for k, v in node.items():
                    if k in ("properties", "patternProperties") and isinstance(v, dict):
                        for prop in v:
                            if prop in BANNED_FIELDS:
                                c.bad(f, "verbotenes Feld %s unter %s" % (prop, path + "/" + k))
                    walk(v, path + "/" + str(k))
            elif isinstance(node, list):
                for i, v in enumerate(node):
                    walk(v, path + "/" + str(i))
        walk(doc, "")
    for case in MAN["test_expectations"]["cases"]:
        if case["validator"] != "agent_state_schema" or case["expect"] != "pass":
            continue
        inst = read_json(case["path"])
        if not isinstance(inst, dict) or "__parse_error__" in inst:
            continue
        if "track" in inst.get("cfg", {}):
            c.bad(case["path"], "cfg.track existiert noch")
        for k in ("decision", "complexity_score"):
            if k in inst.get("triage", {}):
                c.bad(case["path"], "triage.%s existiert noch" % k)
    c.detail = "verbotene Felder: %s" % ", ".join(BANNED_FIELDS)

# --- 20 ssot -----------------------------------------------------------------
def chk_ssot(c):
    concepts = MAN["ssot"]
    seen_concepts = {}
    heading_owner = {}
    for entry in concepts:
        name = entry["concept"]
        if name in seen_concepts:
            c.bad("manifest.json", "Konzept doppelt gelistet: %s" % name)
        seen_concepts[name] = entry
        tgt, _, anc = entry["normative_in"].partition("#")
        if os.path.isdir(rp(tgt)) and not anc:
            continue
        if not os.path.isfile(rp(tgt)):
            c.bad(tgt, "normative Datei fehlt (Konzept: %s)" % name)
            continue
        if anc:
            if anc not in anchors_of(tgt):
                c.bad(tgt, "Anker #%s fehlt (Konzept: %s)" % (anc, name))
            else:
                heading_owner[anc] = tgt
    allowed = {}
    for entry in concepts:
        tgt, _, anc = entry["normative_in"].partition("#")
        allowed[anc] = [glob_re(g) for g in entry.get("reference_allowed_in", [])] + [glob_re(tgt)]
    for f in normative_md():
        for slug_name in anchors_of(f):
            if slug_name in heading_owner and heading_owner[slug_name] != f:
                c.bad(f, "Ueberschrift #%s ist auch in %s normiert (Doppel-Normierung)" % (slug_name, heading_owner[slug_name]))
    c.detail = "%d Konzepte, %d aufloesbare Anker" % (len(concepts), len(heading_owner))
    c.note("Grenze: erkennt doppelte Ueberschriften, keine Paraphrasen")

# --- 21 delivery-path-exists -------------------------------------------------
def chk_delivery(c):
    d = MAN["delivery"]
    push_roles = set(d["push_roles"])
    schema = read_json("schemas/agent-state.schema.json")
    enum = set(pointer(schema, "/$defs/role/enum") or []) if schema and "__parse_error__" not in schema else set()
    classes = {cl["id"] for cl in MAN["triage"]["classes"]}
    covered = set()
    for entry in d["per_class"]:
        cl = entry["class"]
        covered.add(cl)
        if cl == "answer":
            if entry.get("node") or entry.get("roles"):
                c.bad("manifest.json", "Klasse answer darf keinen Auslieferungsknoten haben")
            continue
        if not entry.get("node"):
            c.bad("manifest.json", "Klasse %s ohne Auslieferungsknoten" % cl)
        roles = set(entry.get("roles", []))
        if not roles:
            c.bad("manifest.json", "Klasse %s ohne Rolle mit Push-Recht" % cl)
        if not roles & push_roles:
            c.bad("manifest.json", "Klasse %s: keine der Rollen %s hat Push-Recht" % (cl, sorted(roles)))
        if enum:
            for r in roles - enum:
                c.bad("manifest.json", "Klasse %s nennt Rolle %s ausserhalb des Enums" % (cl, r))
    for cl in classes - covered:
        c.bad("manifest.json", "Klasse %s fehlt in der Auslieferungstabelle" % cl)
    for r in push_roles - enum if enum else set():
        c.bad("manifest.json", "push_roles nennt %s ausserhalb des Rollen-Enums" % r)
    c.detail = "%d Klassen, Push-Rollen: %s" % (len(covered), ", ".join(sorted(push_roles)))

# --- 22 state-path-per-orchestrator -----------------------------------------
def chk_state_path(c):
    st = MAN["state"]
    if "<orchestrator_id>" not in st["path_pattern"]:
        c.bad("manifest.json", "State-Pfadmuster ohne <orchestrator_id>: %s" % st["path_pattern"])
    if st["lock_pattern"] != st["path_pattern"] + ".lock":
        c.bad("manifest.json", "Lock-Muster %s passt nicht zum Pfadmuster" % st["lock_pattern"])
    if st.get("one_per") != "orchestrator_id":
        c.bad("manifest.json", "one_per ist %r, erwartet orchestrator_id" % st.get("one_per"))
    tgt, _, anc = st["documented_in"].partition("#")
    if not os.path.isfile(rp(tgt)):
        c.bad(tgt, "Fundstelle der State-Regel fehlt (documented_in)")
    elif anc and anc not in anchors_of(tgt):
        c.bad(tgt, "Anker #%s fehlt (documented_in)" % anc)
    for f in normative_md():
        for no, ln in code_stripped(f):
            for bad in st["forbidden_paths"]:
                if bad in ln:
                    c.bad("%s:%d" % (f, no), "verbotener State-Pfad %s im Normtext" % bad)
    layout = [e["path"] for e in MAN["runtime_layout"]]
    if not any(st["path_pattern"].startswith(p) for p in layout):
        c.bad("manifest.json", "State-Pfad liegt ausserhalb des Layouts")
    c.detail = "Muster %s, Lock %s" % (st["path_pattern"], st["lock_pattern"])

# --- 23 model-coverage -------------------------------------------------------
def chk_model_coverage(c):
    rel = "specs/coverage.md"
    if not os.path.isfile(rp(rel)):
        c.bad(rel, "Abdeckungstabelle fehlt (WP-5) — Modellabdeckung nicht nachgewiesen")
        c.detail = "Datei fehlt"
        return
    txt = read_text(rel)
    rows = {}
    for no, ln in code_stripped(rel):
        if not ln.lstrip().startswith("|"):
            continue
        cells = [x.strip() for x in ln.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        rows[cells[0].strip("`")] = (no, cells[-1].lower())
    missing = 0
    for n in MAN["cfg"]["nodes"]:
        key = n["id"]
        if key not in rows:
            c.bad(rel, "Knoten %s fehlt in der Abdeckungstabelle" % key); missing += 1
        elif rows[key][1] not in ("ja", "nein"):
            c.bad("%s:%d" % (rel, rows[key][0]), "Knoten %s ohne ja|nein" % key)
    for e in MAN["cfg"]["edges"]:
        key = "%s -> %s" % (e["from"], e["to"])
        alt = "%s → %s" % (e["from"], e["to"])
        if key not in rows and alt not in rows:
            c.bad(rel, "Kante %s fehlt in der Abdeckungstabelle" % key); missing += 1
    c.detail = "%d Knoten + %d Kanten, %d fehlen" % (len(MAN["cfg"]["nodes"]), len(MAN["cfg"]["edges"]), missing)

# --- 24 migration-table-complete --------------------------------------------
def chk_migration_table(c):
    mig = MAN["migration"]
    rel = mig["documented_in"]
    if not os.path.isfile(rp(rel)):
        c.bad(rel, "Umzugstabelle fehlt (WP-6) — Migrationspfad nicht dokumentiert")
        c.detail = "Datei fehlt"
        return
    txt = read_text(rel)
    for p in mig["legacy_files"]:
        if p not in txt:
            c.bad(rel, "v1.3.1-Datei %s fehlt in der Umzugstabelle" % p)
    for p in mig["stubs"]:
        if p not in txt:
            c.bad(rel, "Stub %s ist nicht dokumentiert" % p)
    for p in mig["deletions"]:
        if p not in txt:
            c.bad(rel, "Loeschung %s ist nicht mit Grund dokumentiert" % p)
    c.detail = "%d Alt-Dateien, %d Stubs, %d Loeschungen" % (
        len(mig["legacy_files"]), len(mig["stubs"]), len(mig["deletions"]))

# --- 25 fixtures-declared (Ergaenzung) --------------------------------------
def chk_fixtures_declared(c):
    te = MAN["test_expectations"]
    declared = {case["path"]: case for case in te["cases"]}
    globs = [glob_re(g) for g in te["fixture_globs"]]
    found = 0
    for f in scope_files():
        if not any(g.match(f) for g in globs):
            continue
        found += 1
        if f not in declared:
            c.bad(f, "Fixture ohne Erwartungswert in manifest.json#/test_expectations (stumme Pruefung)")
    for p, case in sorted(declared.items()):
        if not os.path.isfile(rp(p)):
            c.bad(p, "Erwartungswert %s/%s ohne Datei" % (case["validator"], case["expect"]))
    for validator in {case["validator"] for case in te["cases"]}:
        if validator not in te["validators"] and validator != "none":
            c.bad("manifest.json", "Validator %s ohne Kommando in test_expectations.validators" % validator)
    negatives = sum(1 for case in te["cases"] if case["expect"] == "fail")
    if negatives == 0:
        c.bad("manifest.json", "kein einziger Negativfall — Pruefungen waeren nur stumm bestaetigt")
    c.detail = "%d Fixtures im Baum, %d deklariert, davon %d Negativfaelle" % (found, len(declared), negatives)

REGISTRY = {
    "budget": chk_budget,
    "toc": chk_toc,
    "manifest-complete": chk_manifest_complete,
    "role-cards-match-enum": chk_role_cards,
    "runtime-paths-declared": chk_runtime_paths,
    "law-ids": chk_law_ids,
    "law-count": chk_law_count,
    "node-ids": chk_node_ids,
    "edges": chk_edges,
    "unique-section-numbers": chk_unique_sections,
    "links": chk_links,
    "version-consistency": chk_version,
    "phase-enum-sync": chk_phase_enum,
    "no-prose-numbers": chk_prose_numbers,
    "config-provenance-complete": chk_provenance,
    "triage-gate-sets-distinct": chk_gate_sets,
    "triage-criteria-mention-class": chk_criteria,
    "flags-have-gates": chk_flags_gates,
    "schema-no-parallel-track-fields": chk_no_parallel_fields,
    "ssot": chk_ssot,
    "delivery-path-exists": chk_delivery,
    "state-path-per-orchestrator": chk_state_path,
    "model-coverage": chk_model_coverage,
    "migration-table-complete": chk_migration_table,
    "fixtures-declared": chk_fixtures_declared,
}

def main():
    total = CFGD.get("enforcement", {}).get("lint_checks_total") if isinstance(CFGD, dict) else None
    if total is not None and total != len(REGISTRY):
        print("FAIL: registry (1 Fundstelle(n)) — Selbstzaehlung")
        print("    config/policy-defaults.json: enforcement.lint_checks_total=%s, implementiert=%d"
              % (total, len(REGISTRY)))
        RESULTS.append(("registry", "FAIL"))
    for name in CHECKS:
        c = Check(name)
        if not require_ssot(c):
            emit(c)
            continue
        try:
            REGISTRY[name](c)
        except Exception as exc:  # eine Pruefung darf den Lauf nicht abbrechen
            c.bad("lint-lawbook.sh", "Pruefung brach ab: %s: %s" % (type(exc).__name__, exc))
        emit(c)
    n_pass = sum(1 for _, s in RESULTS if s == "PASS")
    n_fail = sum(1 for _, s in RESULTS if s == "FAIL")
    n_skip = sum(1 for _, s in RESULTS if s == "SKIP")
    print("")
    print("Zusammenfassung: %d PASS, %d FAIL, %d NICHT NACHGEWIESEN (von %d ausgefuehrten Pruefungen)"
          % (n_pass, n_fail, n_skip, len(RESULTS)))
    if n_fail:
        print("Offen: " + ", ".join(n for n, s in RESULTS if s == "FAIL"))
    if n_skip and STRICT:
        return 1
    if n_fail:
        return 1
    if n_skip:
        return 2
    return 0

sys.exit(main())
PYEOF

if [ "${#SELECTED[@]}" -eq 0 ] && [ "$SELFTEST" = 0 ]; then
  usage >&2
  exit 1
fi

run_lint() {
  # $1 = root, Rest = Pruefungen
  local root="$1"; shift
  LINT_STRICT="$STRICT" LINT_QUIET="$QUIET" LINT_EMIT_STATUS="${LINT_EMIT_STATUS:-0}" \
    python3 -c "$LINT_PY" "$root" "$@"
}

if [ "$SELFTEST" = 1 ]; then
  # Sensitivitaetsnachweis: je Pruefung eine Mutation einspielen und belegen, dass
  # die Pruefung darauf mit FAIL reagiert. Ist der Ist-Stand schon FAIL, zaehlt
  # nur ein zusaetzlicher Fund als Nachweis; sonst "offen", nie als PASS.
  command -v python3 >/dev/null 2>&1 || { printf 'NICHT NACHGEWIESEN: self-test (Werkzeug python3 fehlt)\n'; exit 2; }
  TMPBASE="$(mktemp -d)"
  trap 'rm -rf "$TMPBASE"' EXIT
  st_status() { # $1 root, $2 check -> "<PASS|FAIL|SKIP> <fundstellen>"
    LINT_EMIT_STATUS=1 run_lint "$1" "$2" 2>/dev/null | awk -v c="$2" '$1=="#STATUS" && $2==c {print $3, $4}'
  }
  mutate() { # $1 = ziel-root, $2 = check
    python3 - "$1" "$2" <<'MUTEOF'
import json, os, sys
root, check = sys.argv[1], sys.argv[2]
def jload(rel):
    with open(os.path.join(root, rel), encoding="utf-8") as fh: return json.load(fh)
def jdump(rel, doc):
    with open(os.path.join(root, rel), "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=2, ensure_ascii=False)
def write(rel, text):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as fh: fh.write(text)
def append(rel, text):
    with open(os.path.join(root, rel), "a", encoding="utf-8") as fh: fh.write(text)
M, C = "manifest.json", "config/policy-defaults.json"
if check == "budget":
    m = jload(M)
    for d in m["documents"]:
        if d["id"] == "core":
            d["max_lines"] = 1
            d["tokens_est_max"] = 1  # bricht zusaetzlich die Ableitung aus max_bytes
    jdump(M, m)
elif check == "toc":
    write("zz-selftest-toc.md", "# T\n" + "x\n" * 400)
elif check == "manifest-complete":
    write("zz-selftest-unlisted.md", "# nicht im Manifest\n")
elif check == "role-cards-match-enum":
    m = jload(M)
    m["documents"].append({"id": "role-zz-selftest", "path": "roles/zz_selftest.md",
                           "kind": "role_card", "category": "rollenkarte",
                           "purpose": "Selbsttest-Karte ohne Enum-Eintrag",
                           "load_when": "reading_list", "load_trigger": "nie - Selbsttest",
                           "max_lines": 40, "max_bytes": None, "tokens_est_max": 520,
                           "required": True, "owner_wp": "WP-2"})
    jdump(M, m)
elif check == "runtime-paths-declared":
    write("zz-selftest-rt.md", "# X\n\nAusgaben nach `runtime/" + "logs/tool.txt` schreiben.\n")
elif check == "law-ids":
    write("zz-selftest-law.md", "# X\n\nSiehe " + "LAW-" + "DOESNOTEXIST fuer Details.\n")
elif check == "law-count":
    write("zz-selftest-count.md", "# X\n")
    append("AGENTS.md", "\nDie 3 Gesetze gelten fort.\n")
elif check == "node-ids":
    write("modules/zz-selftest.md", "# X\n\nKnoten N" + "9 folgt auf N7.\n")
elif check == "edges":
    write("zz-selftest-edge.md", "# X\n\nRueckkanal N7 -> N1 ist zulaessig.\n")
elif check == "unique-section-numbers":
    write("zz-selftest-sec.md", "# X\n\n## 1. Eins\n\n## 1. Auch eins\n")
elif check == "links":
    write("zz-selftest-link.md", "# X\n\nSiehe `modules/nichtvorhanden.md`.\n")
elif check == "version-consistency":
    c = jload(C); c["version"] = "9.9.9"; jdump(C, c)
elif check == "phase-enum-sync":
    m = jload(M); m["phases"] = [p for p in m["phases"] if p != "aggregating"]; jdump(M, m)
elif check == "no-prose-numbers":
    append("AGENTS.md", "\nEin Modul hat maximal 999 Zeilen.\n")
elif check == "config-provenance-complete":
    c = jload(C); c["caps"]["zz_selftest_cap"] = 7; jdump(C, c)
elif check == "triage-gate-sets-distinct":
    m = jload(M)
    gm = m["triage"]["gate_matrix"]["classes"]; gm["chore"] = list(gm["revert"]); jdump(M, m)
elif check == "triage-criteria-mention-class":
    f = "tests/fixtures/triage-cases.json"
    d = jload(f)
    for r in d["class_order"]:
        if r["rule_no"] == 5: r["trigger"] = "Aenderung, die kein feature ist"
    jdump(f, d)
elif check == "flags-have-gates":
    m = jload(M); del m["triage"]["gate_matrix"]["flags"]["perf"]; jdump(M, m)
elif check == "schema-no-parallel-track-fields":
    s = "schemas/agent-state.schema.json"
    d = jload(s); d["properties"]["cfg"]["properties"]["track"] = {"type": "string"}; jdump(s, d)
elif check == "ssot":
    m = jload(M)
    m["ssot"].append(dict(m["ssot"][0]))  # dasselbe Konzept zweimal normiert
    jdump(M, m)
elif check == "delivery-path-exists":
    m = jload(M)
    for e in m["delivery"]["per_class"]:
        if e["class"] == "feature": e["roles"] = []
    jdump(M, m)
elif check == "state-path-per-orchestrator":
    m = jload(M)
    m["state"]["path_pattern"] = "runtime/state/one.json"
    m["state"]["lock_pattern"] = "runtime/state/one.json.lock"
    jdump(M, m)
elif check == "model-coverage":
    write("specs/coverage.md", "# Abdeckung\n\n| Element | abgedeckt |\n|---|---|\n| N0 | ja |\n")
elif check == "migration-table-complete":
    write("docs/migration-v1-to-v2.md", "# Migration\n\nNur ein Satz, keine Tabelle.\n")
elif check == "fixtures-declared":
    write("tests/fixtures/zz-selftest.json", "{}\n")
else:
    sys.exit("keine Mutation fuer %s definiert" % check)
MUTEOF
  }
  st_fail=0; st_proven=0; st_open=0
  printf 'Selbsttest: je Pruefung eine Mutation, erwartet wird FAIL.\n\n'
  for chk in "${ALL_CHECKS[@]}"; do
    read -r base base_n <<<"$(st_status "$ROOT" "$chk")"
    d="$TMPBASE/$chk"
    mkdir -p "$d"
    tar -C "$ROOT" --exclude=.git --exclude=runtime --exclude=lib --exclude=node_modules -cf - . 2>/dev/null | tar -C "$d" -xf - 2>/dev/null
    if ! mutate "$d" "$chk" >/dev/null 2>&1; then
      printf 'SELFTEST %-32s Ist=%-4s Mutation=--   -> BROKEN (Mutation nicht anwendbar)\n' "$chk" "${base:-?}"
      st_fail=$((st_fail + 1)); continue
    fi
    read -r mut mut_n <<<"$(st_status "$d" "$chk")"
    if [ "$mut" != "FAIL" ]; then
      printf 'SELFTEST %-32s Ist=%-4s(%s) Mutation=%-4s(%s) -> BROKEN (reagiert nicht)\n' \
        "$chk" "${base:-?}" "${base_n:-?}" "${mut:-?}" "${mut_n:-?}"
      st_fail=$((st_fail + 1))
    elif [ "$base" = "PASS" ]; then
      printf 'SELFTEST %-32s Ist=%-4s(%s) Mutation=%-4s(%s) -> belegt\n' \
        "$chk" "$base" "${base_n:-0}" "$mut" "${mut_n:-0}"
      st_proven=$((st_proven + 1))
    elif [ "${mut_n:-0}" -gt "${base_n:-0}" ]; then
      # Ist-Stand ist schon FAIL; die Mutation erzeugt zusaetzliche Fundstellen
      # — damit ist die Reaktion trotzdem belegt.
      printf 'SELFTEST %-32s Ist=%-4s(%s) Mutation=%-4s(%s) -> belegt (Zusatzfund)\n' \
        "$chk" "$base" "${base_n:-0}" "$mut" "${mut_n:-0}"
      st_proven=$((st_proven + 1))
    else
      printf 'SELFTEST %-32s Ist=%-4s(%s) Mutation=%-4s(%s) -> offen (Ist-Stand FAIL, kein Zusatzfund)\n' \
        "$chk" "${base:-?}" "${base_n:-0}" "$mut" "${mut_n:-0}"
      st_open=$((st_open + 1))
    fi
  done
  printf '\nSelbsttest-Zusammenfassung: %d belegt, %d offen, %d BROKEN (von %d)\n' \
    "$st_proven" "$st_open" "$st_fail" "${#ALL_CHECKS[@]}"
  [ "$st_fail" -gt 0 ] && exit 1
  [ "${#SELECTED[@]}" -eq 0 ] && exit 0
fi

run_lint "$ROOT" "${SELECTED[@]}"
rc=$?
if [ "$rc" = 2 ] && [ "$ALLOW_SKIP" = 1 ]; then
  printf 'Hinweis: --allow-skip degradiert Exit 2 auf 0. SKIP bleibt kein PASS.\n'
  exit 0
fi
exit "$rc"
