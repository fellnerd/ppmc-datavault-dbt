#!/usr/bin/env python3
"""
PreToolUse-Hook (Bash): Schutz der Data-Vault-Historie.

`dbt run/build --full-refresh` (auch Kurzform -f) baut inkrementelle Tabellen
neu auf — bei historisierten Hubs/Satellites/Links ist die Historie danach
unwiederbringlich weg. Der Hook erzwingt eine explizite User-Bestätigung
(permissionDecision "ask"), egal in welchem Permission-Mode die Session läuft.
"""
import json
import re
import sys


def main() -> None:
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    command = (hook_input.get("tool_input") or {}).get("command", "")

    is_dbt_build = re.search(r"\bdbt\s+(?:\S+\s+)*?(run|build)\b", command)
    wants_full_refresh = re.search(r"(--full-refresh\b|\s-f\b)", command)

    if is_dbt_build and wants_full_refresh:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask",
                "permissionDecisionReason": (
                    "⚠️ dbt --full-refresh erkannt: baut inkrementelle Vault-Objekte neu "
                    "auf und VERNICHTET deren Historie (dss_load_date-Zeitreihen). "
                    "Nur bestätigen, wenn ausschließlich nicht-historisierte Modelle "
                    "selektiert sind oder der Verlust beabsichtigt ist."
                ),
            }
        }))
        sys.exit(0)

    sys.exit(0)


if __name__ == "__main__":
    main()
