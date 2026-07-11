#!/usr/bin/env python3
"""
PostToolUse-Hook (Edit|Write): Deterministischer DV-2.1/dbt-Lint.

Prüft nach jedem Schreiben von models/**/*.sql die wichtigsten Data-Vault-
Konventionen und meldet Verstöße an Claude zurück (Exit 2 + stderr).
Bei design/**/*.mmd wird Drift zwischen ER-Diagramm und Modell-Dateien gemeldet.

Bewusst heuristisch und leise: keine Meldung = alles OK. Nur Befunde, die
fast sicher echte Fehler sind, werden gemeldet; Hinweise sind als solche markiert.
"""
import json
import re
import sys
from pathlib import Path

RESERVED_KEYWORDS = {
    "PLAN", "LEVEL", "KEY", "STATUS", "TYPE", "ORDER", "GROUP", "INDEX",
    "BEFORE", "AFTER", "FUNCTION", "VALUE", "TABLE", "VIEW", "USER", "ROLE",
    "CHECK", "DEFAULT", "PRIMARY", "FOREIGN", "REFERENCES", "RETURN",
}


def lint_model_sql(path: Path, text: str) -> list[str]:
    issues = []
    name = path.stem  # z. B. hub_kunde, sat_kunde__erp
    in_staging = "/staging/" in path.as_posix()
    in_vault = "/raw_vault/" in path.as_posix()

    # --- Pflicht-Metadaten überall ---
    for col in ("dss_load_date", "dss_record_source"):
        if col not in text:
            issues.append(f"Pflicht-Metadatenspalte fehlt: {col}")

    # --- Reserved Keywords als YAML-Listeneinträge (stage()/sat()-Metadata) ---
    escape_block = re.search(r"_escape:.*?(?=\n\S|\n{2})", text, re.S)
    escaped = set(re.findall(r'"([^"]+)"', escape_block.group(0))) if escape_block else set()
    for kw in sorted(RESERVED_KEYWORDS):
        if re.search(rf'^\s*-\s*"?{kw}"?\s*$', text, re.M) and kw not in escaped:
            issues.append(
                f"Reserved Keyword '{kw}' als Spalte gelistet, aber nicht im "
                f"_escape-Block — SQL-Server-Fehler wahrscheinlich (Hinweis)"
            )

    has_config = "config(" in text
    if in_vault and name.startswith(("hub_", "link_", "sat_")):
        # --- Config-Prüfung nur bei inline config(); ohne config() greift die
        #     Folder-Level-Config aus dbt_project.yml (dort incremental) ---
        normalized = text.replace('"', "'")
        if has_config and "materialized='view'" in normalized:
            issues.append(
                "Vault-Objekt als View materialisiert — Raw Vault muss physisch/"
                "inkrementell sein (Historisierung)"
            )
        if has_config and "as_columnstore" not in text:
            issues.append(
                "config() ohne as_columnstore=false (Azure SQL Basic/Serverless) (Hinweis)"
            )
        if "create_hash_index" not in text:
            issues.append(
                "post_hook create_hash_index fehlt — Konvention für hk_*-Join-Performance (Hinweis)"
            )

    if in_vault and name.startswith(("hub_", "link_")):
        if "__" in name:
            issues.append(
                f"Naming: '{name}' enthält '__' — der __source-Suffix gilt nur für "
                f"Satellites, nicht für Hubs/Links"
            )

    if in_vault and name.startswith("sat_"):
        if "src_hashdiff" in text:
            if not re.search(r'alias:\s*"?hashdiff"?', text):
                issues.append(
                    'src_hashdiff ohne alias: "hashdiff" — automate_dv erwartet den '
                    "Alias, sonst bricht die Change Detection"
                )
            if "update_satellite_current_flag" not in text:
                issues.append(
                    "Historisierter Satellite ohne update_satellite_current_flag "
                    "post_hook — dss_is_current/dss_end_date bleiben leer"
                )
        if "__" not in name and "_tl" not in name:
            issues.append(
                f"Naming: '{name}' ohne __source-Suffix (Konvention: sat_<entity>__<quelle>) (Hinweis)"
            )

    return issues


def lint_mermaid(path: Path, text: str, project_dir: Path) -> list[str]:
    """Drift-Check: Objekte im ER-Diagramm vs. Modell-Dateien (beide Richtungen)."""
    issues = []
    diagram_objs = set(re.findall(r"\b((?:hub|sat|link)_[a-z0-9_]+)\b", text.lower()))
    # Diagramm gilt je Konzept: design/raw-vault/<concept>/… ↔ models/raw_vault/<concept>/…
    concept = path.parent.name
    concept_dir = project_dir / "models" / "raw_vault" / concept
    if not concept_dir.is_dir():
        # Reines Design-Stadium (Modelle noch nicht implementiert) — nichts zu prüfen
        return issues
    model_files = {
        p.stem.lower()
        for p in concept_dir.glob("**/*.sql")
        if p.stem.lower().startswith(("hub_", "sat_", "link_"))
    }
    if not model_files:
        return issues
    missing_in_diagram = sorted(model_files - diagram_objs)
    missing_as_model = sorted(diagram_objs - model_files)
    if missing_in_diagram:
        issues.append(
            "Modelle ohne Eintrag im ER-Diagramm: " + ", ".join(missing_in_diagram)
        )
    if missing_as_model:
        issues.append(
            "Im Diagramm, aber keine Modell-Datei (geplant? dann OK): "
            + ", ".join(missing_as_model) + " (Hinweis)"
        )
    return issues


def main() -> None:
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    file_path = (hook_input.get("tool_input") or {}).get("file_path", "")
    if not file_path:
        sys.exit(0)

    path = Path(file_path)
    project_dir = Path(hook_input.get("cwd") or ".")
    posix = path.as_posix()

    if not path.exists():
        sys.exit(0)

    issues: list[str] = []
    if posix.endswith(".sql") and "/models/" in posix:
        issues = lint_model_sql(path, path.read_text(errors="replace"))
    elif posix.endswith(".mmd") and "/design/" in posix:
        issues = lint_mermaid(path, path.read_text(errors="replace"), project_dir)

    if issues:
        print(
            f"DV-Lint für {path.name}:\n" + "\n".join(f"  - {i}" for i in issues),
            file=sys.stderr,
        )
        sys.exit(2)  # stderr wird Claude als Feedback gezeigt (nicht-blockierend)

    sys.exit(0)


if __name__ == "__main__":
    main()
