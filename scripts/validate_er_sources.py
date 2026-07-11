#!/usr/bin/env python
"""
Validiert das ER-Modell "ER_Sauter" gegen die tatsächlich vorhandenen
External Tables in models/staging/sources.yml.

Prüft je ER-Tabelle:
  1. Existiert die External Table (ext_sauter_test_<tabelle>)?
  2. Sind alle im ER-Diagramm dokumentierten Spalten vorhanden?
  3. Welche zusätzlichen Spalten liefert die Quelle (im ER nicht dokumentiert)?

Aufruf:  .venv/bin/python scripts/validate_er_sources.py [--markdown]
"""
import sys
from pathlib import Path

import yaml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOURCES_YML = PROJECT_ROOT / "models" / "staging" / "sources.yml"
EXT_PREFIX = "ext_sauter_test_"

# ER-Modell "ER_Sauter" (Arbeitsstand): Tabelle -> dokumentierte Spalten.
# PK-/Join-Spalten stehen vorne. Quelle: docs/QUELLSYSTEM_SAUTER.md
ER_MODEL = {
    "stamm_firma_werke": ["LABORID", "FIRMENID", "WERKID", "NAME", "KUERZEL", "WERKTYP"],
    "import_lieferscheine": ["LFDNUMMER", "LABORID", "FIRMENID", "WERKID", "IDENTID",
                             "TEILREZEPTID", "LSID", "REZEPTBEZEICHNUNG"],
    "kommunikation_extrezeptbasis": ["LFDNR", "LABORID", "FIRMENID", "WERKID", "REZEPTSORTE",
                                     "EXPOSITIONSKLASSE", "FESTIGKEITSKLASSE", "KONSISTENZ",
                                     "GROESTKORN"],
    "annahme_basis": ["LABORID", "FIRMENID", "WERKID", "REZEPTSORTE", "REZEPTID"],
    "stoffraum_komponenten": ["LABORID", "FIRMENID", "REZEPTID", "KOMPOTYP", "KOMPOID",
                              "DOSIERPOSITION", "MENGE_ANTEIL", "MASSE", "VOLUMEN",
                              "FEUCHTE", "ANRECHNUNGSFAKTOR"],
    "kompo_komponentenverbund": ["LFDNR", "LABORID", "FIRMENID", "KOMPOTYP", "KOMPOID",
                                 "ZIELKOMPOID", "DOSIERPOSITION", "ANTEIL"],
    "kompo_preise": ["LABORID", "FIRMENID", "WERKID", "KOMPOTYP", "KOMPOID", "PREIS"],
    "stamm_lieferantenwerk": ["LABORID", "LIEFERANTENID", "LIEFERANTENWERKID", "FIRMENNAME"],
    "kompo_zuschlag_firma": ["LABORID", "FIRMENID", "ZUSCHLAGID", "ZUSCHLAGARTENID",
                             "LIEFERANTENID", "LIEFERANTENWERKID", "BEZEICHNUNG",
                             "ARTIKELNUMMER", "ARTIKELUNTERNUMMER"],
    "kompo_bindemittel_firma": ["LABORID", "FIRMENID", "BINDEMITTELID", "BINDEMITTELARTENID",
                                "LIEFERANTENID", "LIEFERANTENWERKID", "BEZEICHNUNG",
                                "ARTIKELNUMMER", "ARTIKELUNTERNUMMER"],
    "kompo_zusatzmittel_firma": ["LABORID", "FIRMENID", "ZUSATZMITTELID", "ZUSATZMITTELARTENID",
                                 "LIEFERANTENID", "LIEFERANTENWERKID", "BEZEICHNUNG",
                                 "ARTIKELNUMMER", "ARTIKELUNTERNUMMER"],
    "kompo_wasser_firma": ["LABORID", "FIRMENID", "WASSERID", "WASSERARTENID",
                           "LIEFERANTENID", "LIEFERANTENWERKID", "BEZEICHNUNG",
                           "ARTIKELNUMMER", "ARTIKELUNTERNUMMER"],
    "kompo_fueller_firma": ["LABORID", "FIRMENID", "FUELLERID", "ZUSATZSTOFFARTID",
                            "LIEFERANTENID", "LIEFERANTENWERKID", "BEZEICHNUNG",
                            "ARTIKELNUMMER", "ARTIKELUNTERNUMMER"],
    "stamm_zuschlagarten": ["LABORID", "ZUSCHLAGARTENID", "BEZEICHNUNG"],
    "stamm_bindemittelarten": ["LABORID", "ZEMENTARTENID", "BEZEICHNUNG"],
    "stamm_zusatzmittelarten": ["LABORID", "ZUSATZMITTELARTENID", "BEZEICHNUNG"],
    "stamm_wasserarten": ["LABORID", "WASSERARTENID", "BEZEICHNUNG"],
    "stamm_zusatzstoffarten": ["LABORID", "ZUSATZSTOFFARTENID", "BEZEICHNUNG"],
}


def load_sources():
    data = yaml.safe_load(SOURCES_YML.read_text())
    return {
        t["name"]: [c["name"] for c in t.get("columns", [])]
        for t in data["sources"][0]["tables"]
    }


def validate():
    sources = load_sources()
    results = []
    for er_table, er_cols in ER_MODEL.items():
        ext_name = EXT_PREFIX + er_table
        if ext_name not in sources:
            results.append({"table": er_table, "ext": ext_name, "status": "FEHLT",
                            "missing": er_cols, "extra_count": 0, "extra": []})
            continue
        actual = sources[ext_name]
        actual_upper = {c.upper() for c in actual}
        missing = [c for c in er_cols if c.upper() not in actual_upper]
        extra = [c for c in actual if c.upper() not in {e.upper() for e in er_cols}]
        status = "OK" if not missing else "ABWEICHUNG"
        results.append({"table": er_table, "ext": ext_name, "status": status,
                        "missing": missing, "extra_count": len(extra), "extra": extra})
    return results, sources


def main():
    markdown = "--markdown" in sys.argv
    results, sources = validate()

    if markdown:
        print("| ER-Tabelle | External Table | Status | Fehlende ER-Spalten | Zusätzl. Spalten |")
        print("|---|---|---|---|---|")
        for r in results:
            missing = ", ".join(r["missing"]) or "—"
            print(f"| {r['table'].upper()} | `{r['ext']}` | {r['status']} | {missing} | {r['extra_count']} |")
    else:
        ok = sum(1 for r in results if r["status"] == "OK")
        print(f"ER-Validierung: {ok}/{len(results)} Tabellen OK\n")
        for r in results:
            print(f"[{r['status']:^10}] {r['table'].upper()}  ->  {r['ext']}")
            if r["missing"]:
                print(f"             fehlt in Quelle: {', '.join(r['missing'])}")
            if r["extra_count"]:
                print(f"             {r['extra_count']} zusätzliche Spalten (nicht im ER): "
                      f"{', '.join(r['extra'][:8])}{' …' if r['extra_count'] > 8 else ''}")

    # Verwandte Tabellen, die das ER-Diagramm evtl. ergänzen sollten
    er_ext = {EXT_PREFIX + t for t in ER_MODEL}
    related = [n for n in sources
               if n not in er_ext and any(
                   k in n for k in ("kompo_", "stoffraum_", "annahme_", "rezept"))]
    print(f"\n{len(related)} verwandte Tabellen ausserhalb des ER-Modells "
          f"(Kandidaten für ER-Erweiterung):" if not markdown else
          f"\n**{len(related)} verwandte Tabellen ausserhalb des ER-Modells:**\n")
    for n in sorted(related):
        print(f"  - {n}" if not markdown else f"- `{n}`")


if __name__ == "__main__":
    main()
